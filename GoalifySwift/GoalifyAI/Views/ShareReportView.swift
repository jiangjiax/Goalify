import SwiftUI
import Photos
import SwiftData

struct ShareReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User] // 添加用户查询
    
    @State private var showingSaveSuccess = false
    @State private var savedImageType = ""
    @State private var showingPermissionAlert = false
    @State private var isAnalyzing = false
    @State private var analysisResult = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showingEnergyManagement = false
    
    // 直接接收截图
    let statisticsImage: UIImage?
    let moodImage: UIImage?
    
    // 接收复盘周期信息
    let period: String // "day", "week", "month"
    let startDate: Date
    let endDate: Date
    
    // 添加海报相关状态
    @State private var posterImage: UIImage?
    @State private var showingPoster = false
    
    // 存储时间记录
    private let timeRecords: [(String, Int)]
    
    init(statisticsImage: UIImage?,
         moodImage: UIImage?,
         period: String,
         startDate: Date,
         endDate: Date,
         timeRecords: [(String, Int)]) {
        self.statisticsImage = statisticsImage
        self.moodImage = moodImage
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.timeRecords = timeRecords
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // AI 分析面板
                    analysisPanel()
                        .padding(.horizontal)

                    // 两个图片并排显示 - 修改为顶部对齐
                    HStack(alignment: .top, spacing: 12) {
                        // 统计图片 - 添加蓝色调
                        imageCard(
                            image: statisticsImage,
                            title: "数据统计",
                            accentColor: Color(red: 0.2, green: 0.5, blue: 0.9),
                            bgColor: Color(red: 0.95, green: 0.97, blue: 1.0),
                            buttonAction: { saveImage(statisticsImage, type: "统计数据") }
                        )
                        
                        // 情绪图片 - 改为橙色调
                        imageCard(
                            image: moodImage,
                            title: "情绪追踪",
                            accentColor: Color(red: 0.9, green: 0.5, blue: 0.1),
                            bgColor: Color(red: 1.0, green: 0.96, blue: 0.9),
                            buttonAction: { saveImage(moodImage, type: "情绪数据") }
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("复盘报告")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .alert("保存成功", isPresented: $showingSaveSuccess) {
                Button("确定", role: .cancel) {}
            } message: {
                if savedImageType == "复盘文案" {
                    Text("复盘文案已复制到剪贴板")
                } else {
                    Text("\(savedImageType)报告已保存到相册")
                }
            }
            .alert("需要相册权限", isPresented: $showingPermissionAlert) {
                Button("去设置", role: .cancel) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .destructive) {}
            } message: {
                Text("保存图片需要访问您的相册，请在设置中允许访问")
            }
            .alert("分析失败", isPresented: $showingErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadAnalysisIfExists()
            }
        }
        .sheet(isPresented: $showingEnergyManagement) {
            if let user = users.first {
                EnergyManagementView(energy: .constant(user.energy))
            }
        }
    }
    
    // 修改图片卡片添加颜色参数
    private func imageCard(image: UIImage?, title: String, accentColor: Color, bgColor: Color, buttonAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题和保存按钮 - 使用传入的强调色
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accentColor)
                
                Spacer()
                
                Button(action: buttonAction) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(image != nil ? accentColor : Color.gray.opacity(0.5))
                }
                .disabled(image == nil)
            }
            .padding(.horizontal, 2)
            
            // 图片
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                    .aspectRatio(0.8, contentMode: .fit)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                            
                            Text("等待生成")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? 
                      Color(.systemGray6).opacity(0.8) : 
                      bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: accentColor.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    // 现代扁平化AI分析面板
    private func analysisPanel() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题区域
            HStack(spacing: 10) {
                Circle()
                    .fill(AppTheme.primaryColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.primaryColor)
                    )
                
                Text("AI 复盘分析")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                // Add reset button
                if isAnalyzing && !analysisResult.isEmpty {
                    Button(action: {
                        // Reset analysis
                        analysisResult = ""
                        isAnalyzing = false
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.primaryColor)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
            
            // 描述
            Text("让 AI 助手分析你的数据和情绪记录，提供个性化的见解和建议，帮助你更好地了解自己的工作和生活状态。")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // 分析结果或按钮
            if isLoading {
                HStack {
                    ProgressView()
                    Text("加载中...")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            } else if isAnalyzing {
                VStack(alignment: .leading, spacing: 12) {
                    if analysisResult.isEmpty {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("正在分析中...")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(analysisResult)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
                            )
                            .onTapGesture {
                                UIPasteboard.general.string = analysisResult
                                showingSaveSuccess = true
                                savedImageType = "复盘文案"
                            }
                    }
                }
            } else {
                Button(action: {
                    // 开始分析
                    isAnalyzing = true
                    requestAIAnalysis()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("开始分析")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.primaryColor)
                    )
                    .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    // 修改 saveImage 方法
    private func saveImage(_ image: UIImage?, type: String) {
        guard let image = image else { return }
        
        // 先检查当前权限状态
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            // 已有权限，直接保存
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            savedImageType = type
            showingSaveSuccess = true
            
        case .notDetermined:
            // 请求权限
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        self.savedImageType = type
                        self.showingSaveSuccess = true
                    } else {
                        self.showingPermissionAlert = true
                    }
                }
            }
            
        case .denied, .restricted, .limited:
            // 显示权限提示
            showingPermissionAlert = true
            
        @unknown default:
            break
        }
    }
    
    // 在 ShareReportView 中添加 URLSessionDelegate 实现
    class StreamDelegate: NSObject, URLSessionDataDelegate {
        var onReceive: (Data) -> Void
        var onComplete: (Error?) -> Void
        
        init(onReceive: @escaping (Data) -> Void, onComplete: @escaping (Error?) -> Void) {
            self.onReceive = onReceive
            self.onComplete = onComplete
            super.init()
        }
        
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            onReceive(data) 
        }
        
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            onComplete(error)
        }
    }
    
    // 修改 requestAIAnalysis 方法
    private func requestAIAnalysis() {
        // 添加日志
        print("Debug: requestAIAnalysis called with:")
        print("Time records count: \(timeRecords.count)")
        print("Time records: \(timeRecords)")
        
        // 先检查用户能量值
        guard let user = users.first else {
            errorMessage = "未找到用户信息"
            showingErrorAlert = true
            isAnalyzing = false
            return
        }
        
        // 根据复盘周期计算需要的能量值
        let requiredEnergy: Int
        switch period {
        case "day":
            requiredEnergy = 1
        case "week":
            requiredEnergy = 1
        case "month":
            requiredEnergy = 3
        default:
            requiredEnergy = 1
        }
        
        // 检查能量是否足够
        if user.energy < requiredEnergy {
            showingEnergyManagement = true
            isAnalyzing = false
            return
        }

        // 添加同步服务
        let syncService = SyncService(modelContext: modelContext)
        
        // 先执行情绪同步
        Task {
            do {
                // 获取并同步情绪变更
                let emotions = try await syncService.fetchEmotionChanges()
                if !emotions.isEmpty {
                    try await syncService.syncEmotions(emotions)
                }
                
                // 同步完成后继续执行分析请求
                await MainActor.run {
                    continueWithAnalysis()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "同步情绪数据失败: \(error.localizedDescription)"
                    showingErrorAlert = true
                    isAnalyzing = false
                }
            }
        }
    }
    
    // 将原有的分析逻辑抽取为单独的方法
    private func continueWithAnalysis() {
        guard let url = URL(string: "\(GlobalConstants.baseURL)/api/v1/analysis") else {
            errorMessage = "无效的URL"
            showingErrorAlert = true
            isAnalyzing = false
            return
        }
        
        // 将时间记录转换为接口需要的格式
        let formattedTimeRecords = timeRecords.map { record -> [String: Any] in
            [
                "taskId": record.0,
                "title": record.0,
                "totalTime": record.1,
            ]
        }
        
        // 准备请求参数
        let parameters: [String: Any] = [
            "period": period,
            "startDate": ISO8601DateFormatter().string(from: startDate),
            "endDate": ISO8601DateFormatter().string(from: endDate),
            "timeRecords": formattedTimeRecords
        ]

        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.addValue(token, forHTTPHeaderField: "Authorization")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            errorMessage = "请求参数序列化失败: \(error.localizedDescription)"
            showingErrorAlert = true
            isAnalyzing = false
            return
        }
        
        // 创建流式处理代理
        let delegate = StreamDelegate(
            onReceive: { data in
                // 首先尝试解析是否是错误响应
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let remainingEnergy = json["remainingEnergy"] as? Int {
                    DispatchQueue.main.async {
                        // 更新本地用户能量值
                        if let user = users.first {
                            user.energy = remainingEnergy
                            try? modelContext.save()
                        }
                        // 显示能量管理页面
                        self.showingEnergyManagement = true
                        self.isAnalyzing = false
                    }
                    return
                }
                
                // 正常的流式响应处理
                if let chunk = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.analysisResult += chunk
                    }
                }
            },
            onComplete: { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "请求失败: \(error.localizedDescription)"
                        self.showingErrorAlert = true
                    } else {
                        // 分析完成后，同步最新的能量值
                        Task {
                            do {
                                let context = ModelContext(GoalifyAIApp.sharedModelContainer)
                                let newEnergy = try await SyncService(modelContext: context).fetchEnergy()
                                if let user = self.users.first {
                                    user.energy = newEnergy
                                    try? self.modelContext.save()
                                }
                            } catch {
                                print("同步能量值失败: \(error)")
                            }
                        }
                    }
                }
            }
        )
        
        // 创建会话和任务
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
    }
    
    // 添加加载已有分析的方法
    private func loadAnalysisIfExists() {
        guard let url = URL(string: "\(GlobalConstants.baseURL)/api/v1/review-analyses") else {
            print("无效的URL")
            return
        }
        
        // 添加查询参数
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "startDate", value: ISO8601DateFormatter().string(from: startDate)),
            URLQueryItem(name: "endDate", value: ISO8601DateFormatter().string(from: endDate))
        ]
        
        var request = URLRequest(url: components?.url ?? url)
        request.httpMethod = "GET"
        
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.addValue(token, forHTTPHeaderField: "Authorization")
        }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("加载分析失败: \(error.localizedDescription)")
                    errorMessage = "加载分析失败: \(error.localizedDescription)"
                    showingErrorAlert = true
                    return
                }
                
                guard let data = data else {
                    print("未收到数据")
                    return
                }
                
                // 添加调试日志
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("收到的数据: \(jsonString)")
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let analysisData = json["data"] as? [String: Any],
                       let summary = analysisData["Summary"] as? String {
                        print("成功加载分析结果")
                        analysisResult = summary
                        isAnalyzing = true
                    } else {
                        print("未找到分析结果")
                    }
                } catch {
                    print("解析分析结果失败: \(error.localizedDescription)")
                    errorMessage = "解析分析结果失败: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }.resume()
    }
}

// 添加 UIView 扩展
extension UIView {
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
} 
