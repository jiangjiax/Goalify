import SwiftUI
import Foundation
import SwiftData

@MainActor
class SyncService {
    private let modelContext: ModelContext
    private let lastSyncDateKey = "lastSyncDate"
    private let networkMonitor = NetworkMonitor.shared
    
    // 使用 UserDefaults 替代 @AppStorage
    private var deletedRecords: Data {
        get {
            UserDefaults.standard.data(forKey: "deletedRecords") ?? Data()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "deletedRecords")
        }
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // 同步数据到服务器
    func syncChanges() async {
        // 检查网络连接
        guard networkMonitor.isConnected else {
            print("无网络连接，跳过同步")
            return
        }

        do {
            // 获取需要同步的数据
            let emotions = try await fetchEmotionChanges()
            
            try await syncEmotions(emotions)
        } catch SyncError.clientError(let message) {
            print("客户端错误: \(message)")
        } catch SyncError.serverError(let message) {
            print("服务器错误: \(message)")
        } catch {
            print("同步失败: \(error)")
        }
    }
    
    // 从服务器获取更新
    func fetchUpdates() async {
        // 检查网络连接
        guard networkMonitor.isConnected else {
            print("无网络连接，跳过更新")
            return
        }
        
        // 获取上次同步时间
        let lastSyncDate = UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date ?? Date.distantPast
        
        // 如果上次同步时间在1分钟内，跳过同步
        if Date().timeIntervalSince(lastSyncDate) < 60 {
            print("上次同步时间在1分钟内，跳过更新")
            return
        }
        
        do {
            // 获取用户 Token
            let token = UserDefaults.standard.string(forKey: "authToken") ?? ""
            if token.isEmpty {
                throw SyncError.clientError("未找到用户 Token")
            }
            
            // 创建 HTTP 请求
            guard let url = URL(string: "\(GlobalConstants.baseURL)/api/v1/sync/updates") else {
                throw SyncError.invalidURL("无效的更新URL")
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(token, forHTTPHeaderField: "Authorization")
            
            // 设置查询参数
            let dateFormatter = ISO8601DateFormatter()
            let queryItems = [URLQueryItem(name: "lastSyncDate", value: dateFormatter.string(from: lastSyncDate))]
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            urlComponents?.queryItems = queryItems
            request.url = urlComponents?.url
            
            // 设置超时时间
            request.timeoutInterval = 30
            
            // 发送请求
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 打印原始响应数据
            if let jsonString = String(data: data, encoding: .utf8) {
                print("服务器返回的原始数据: \(jsonString)")
            }
            
            // 检查响应状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SyncError.serverError("无效的服务器响应")
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                // 解析响应数据
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                
                // 自定义日期解析策略
                decoder.dateDecodingStrategy = .custom { decoder -> Date in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // 尝试带毫秒的格式
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                    
                    // 尝试不带毫秒的格式
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                    
                    // 如果都失败则抛出错误
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "无法解析日期字符串：\(dateString)"
                    )
                }
                
                let updates = try decoder.decode(SyncUpdatesResponse.self, from: data)
                
                // 更新本地数据库
                try await updateLocalData(with: updates)
                
                UserDefaults.standard.set(Date(), forKey: lastSyncDateKey)
            case 400...499:
                // 客户端错误
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    print("客户端错误: \(errorResponse.error)")
                    throw SyncError.clientError("客户端错误: \(httpResponse.statusCode), 错误信息: \(errorResponse.error)")
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                    print("客户端错误: \(errorMessage)")
                    throw SyncError.clientError("客户端错误: \(httpResponse.statusCode), 错误信息: \(errorMessage)")
                }
            case 500...599:
                // 服务器错误
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    print("服务器错误: \(errorResponse.error)")
                    throw SyncError.serverError("服务器错误: \(httpResponse.statusCode), 错误信息: \(errorResponse.error)")
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                    print("服务器错误: \(errorMessage)")
                    throw SyncError.serverError("服务器错误: \(httpResponse.statusCode), 错误信息: \(errorMessage)")
                }
            default:
                let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                print("未知错误: \(errorMessage)")
                throw SyncError.unknownError("未知错误: \(httpResponse.statusCode), 错误信息: \(errorMessage)")
            }
        } catch {
            print("获取更新失败: \(error)")
        }
    }

    // 获取需要同步的情绪记录数据
    func fetchEmotionChanges() async throws -> [EmotionRecord] {
        // 获取上次同步时间
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDateEmotions") as? Date ?? Date.distantPast
        
        // 查询 lastModified 大于上次同步时间的情绪记录
        let descriptor = FetchDescriptor<EmotionRecord>(
            predicate: #Predicate { $0.lastModified > lastSyncDate }
        )
        return try modelContext.fetch(descriptor)
    }

    func syncEmotions(_ emotions: [EmotionRecord]) async throws {
        guard !emotions.isEmpty else { return }
        
        // 获取用户 Token
        let token = UserDefaults.standard.string(forKey: "authToken") ?? ""
        if token.isEmpty {
            throw SyncError.clientError("未找到用户 Token")
        }
        
        // 将情绪记录数据转换为 JSON
        let dateFormatter = ISO8601DateFormatter()
        let emotionJSONArray = emotions.map { emotion in
            return [
                "id": emotion.id.uuidString,
                "emotionType": emotion.emotionType,
                "intensity": emotion.intensity.rawValue,
                "trigger": emotion.trigger,
                "unhealthyBeliefs": emotion.unhealthyBeliefs,
                "healthyEmotion": emotion.healthyEmotion,
                "copingStrategies": emotion.copingStrategies,
                "recordDate": dateFormatter.string(from: emotion.recordDate),
                "lastModified": dateFormatter.string(from: emotion.lastModified)
            ] as [String: Any]
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: emotionJSONArray, options: [])
        
        // 创建 HTTP 请求
        guard let url = URL(string: "\(GlobalConstants.baseURL)/api/v1/sync/emotions") else {
            throw SyncError.invalidURL("无效的情绪记录同步URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        // 设置超时时间
        request.timeoutInterval = 30
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 检查响应状态码
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.serverError("无效的服务器响应")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            // 处理成功响应后更新情绪同步时间
            UserDefaults.standard.set(Date(), forKey: "lastSyncDateEmotions")
            if let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("情绪记录同步成功: \(responseJSON)")
            }
        case 400...499:
            // 客户端错误
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                print("客户端错误: \(errorResponse.error)")
                throw SyncError.clientError("客户端错误: \(httpResponse.statusCode), 错误信息: \(errorResponse.error)")
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                print("客户端错误: \(errorMessage)")
                throw SyncError.clientError("客户端错误: \(httpResponse.statusCode), 错误信息: \(errorMessage)")
            }
        case 500...599:
            // 服务器错误
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                print("服务器错误: \(errorResponse.error)")
                throw SyncError.serverError("服务器错误: \(httpResponse.statusCode), 错误信息: \(errorResponse.error)")
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                print("服务器错误: \(errorMessage)")
                throw SyncError.serverError("服务器错误: \(httpResponse.statusCode), 错误信息: \(errorMessage)")
            }
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            print("未知错误: \(errorMessage)")
            throw SyncError.unknownError("未知错误: \(httpResponse.statusCode), 错误信息: \(errorMessage)")
        }
    }

    // 更新本地数据
    private func updateLocalData(with updates: SyncUpdatesResponse) async throws {
        // 更新情绪记录
        for emotion in updates.emotions {
            if let uuid = UUID(uuidString: emotion.id) {
                let descriptor = FetchDescriptor<EmotionRecord>(
                    predicate: #Predicate<EmotionRecord> { $0.id == uuid }
                )
                let existingEmotion = try modelContext.fetch(descriptor).first
                
                if let existingEmotion = existingEmotion {
                    // 如果情绪记录已存在，比较 lastModified 时间戳
                    if emotion.lastModified > existingEmotion.lastModified {
                        // 如果服务器数据更新，则更新本地数据
                        existingEmotion.emotionType = emotion.emotionType
                        existingEmotion.intensity = MoodRecord.Intensity(rawValue: emotion.intensity) ?? .medium
                        existingEmotion.trigger = emotion.trigger
                        existingEmotion.unhealthyBeliefs = emotion.unhealthyBeliefs
                        existingEmotion.healthyEmotion = emotion.healthyEmotion
                        existingEmotion.copingStrategies = emotion.copingStrategies
                        existingEmotion.recordDate = emotion.recordDate
                        existingEmotion.lastModified = emotion.lastModified
                    }
                } else {
                    // 如果情绪记录不存在，则插入新数据
                    let newEmotion = EmotionRecord(
                        emotionType: emotion.emotionType,
                        intensity: MoodRecord.Intensity(rawValue: emotion.intensity) ?? .medium,
                        trigger: emotion.trigger,
                        unhealthyBeliefs: emotion.unhealthyBeliefs,
                        healthyEmotion: emotion.healthyEmotion,
                        copingStrategies: emotion.copingStrategies,
                        recordDate: emotion.recordDate
                    )
                    newEmotion.id = uuid
                    newEmotion.lastModified = emotion.lastModified
                    
                    modelContext.insert(newEmotion)
                }
            }
        }
        
        // 提交更改
        try modelContext.save()
    }

    // 添加获取能量值的方法
    func fetchEnergy() async throws -> Int {
        // 检查网络连接
        guard networkMonitor.isConnected else {
            throw SyncError.clientError("无网络连接")
        }
        
        // 获取用户 Token
        let token = UserDefaults.standard.string(forKey: "authToken") ?? ""
        if token.isEmpty {
            throw SyncError.clientError("未找到用户 Token")
        }
        
        // 创建 HTTP 请求
        guard let url = URL(string: "\(GlobalConstants.baseURL)/api/v1/user/energy") else {
            throw SyncError.invalidURL("无效的URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.serverError("无效的服务器响应")
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SyncError.serverError("服务器返回错误状态码: \(httpResponse.statusCode)")
        }
        
        // 解析响应
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let energy = json?["energy"] as? Int else {
            throw SyncError.serverError("无效的响应格式")
        }
        
        return energy
    }

    // 在 SyncService 类中添加用户同步方法
    func syncUserData() async throws {
        // 检查网络连接
        guard networkMonitor.isConnected else {
            throw SyncError.clientError("无网络连接")
        }
        
        // 获取用户 Token
        let token = UserDefaults.standard.string(forKey: "authToken") ?? ""
        if token.isEmpty {
            throw SyncError.clientError("未找到用户 Token")
        }
        
        // 创建 HTTP 请求
        guard let url = URL(string: "\(GlobalConstants.baseURL)/api/v1/user") else {
            throw SyncError.invalidURL("无效的URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.serverError("无效的服务器响应")
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SyncError.serverError("服务器返回错误状态码: \(httpResponse.statusCode)")
        }
        
        // 解析响应
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let userData = json?["user"] as? [String: Any],
              let energy = userData["energy"] as? Int,
              let username = userData["username"] as? String,
              let email = userData["email"] as? String else {
            throw SyncError.serverError("无效的响应格式")
        }
        
        // 更新 SwiftData 中的用户数据
        let fetchDescriptor = FetchDescriptor<User>()
        if let existingUser = try? modelContext.fetch(fetchDescriptor).first {
            existingUser.energy = energy
            existingUser.username = username
            existingUser.email = email
        } else {
            let newUser = User(username: username, email: email, energy: energy)
            modelContext.insert(newUser)
        }
        
        try modelContext.save()
    }

    // 添加删除记录的方法
    func addDeletedRecord(type: String, id: UUID) {
        var records = getDeletedRecords()
        records.append(DeletedRecord(type: type, id: id))
        saveDeletedRecords(records)
    }

    private func getDeletedRecords() -> [DeletedRecord] {
        if let records = try? JSONDecoder().decode([DeletedRecord].self, from: deletedRecords) {
            return records
        }
        return []
    }

    private func saveDeletedRecords(_ records: [DeletedRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            deletedRecords = data
        }
    }

    private func clearDeletedRecords() {
        UserDefaults.standard.removeObject(forKey: "deletedRecords")
    }

    // 添加批量删除记录的方法
    func addDeletedRecords(_ records: [DeletedRecord]) {
        var currentRecords = getDeletedRecords()
        currentRecords.append(contentsOf: records)
        saveDeletedRecords(currentRecords)
    }

    // 添加删除记录的数据结构
    struct DeletedRecord: Codable {
        let type: String
        let id: UUID
    }

    // 添加检查未同步数据的方法
    func hasUnsyncedData() async -> Bool {
        do {
            // 检查未同步的情绪记录
            let unsyncedEmotions = try await fetchEmotionChanges()
            if !unsyncedEmotions.isEmpty { return true }
            
            return false
        } catch {
            print("检查未同步数据时出错: \(error)")
            return false
        }
    }
}

enum SyncError: Error {
    case invalidURL(String)
    case clientError(String)
    case serverError(String)
    case unknownError(String)
}

// 定义错误响应结构体
struct ErrorResponse: Codable {
    let error: String
}

// 同步更新响应结构体
struct SyncUpdatesResponse: Codable {
    struct EmotionResponse: Codable {
        let id: String
        let emotionType: String
        let intensity: Int
        let trigger: String
        let unhealthyBeliefs: String
        let healthyEmotion: String
        let copingStrategies: String
        let recordDate: Date
        let lastModified: Date
    }

    let emotions: [EmotionResponse]
} 
