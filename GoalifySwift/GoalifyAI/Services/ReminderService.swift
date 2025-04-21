import EventKit
import SwiftUI

class ReminderService: ObservableObject {
    let eventStore = EKEventStore()
    @MainActor @Published var reminders: [EKReminder] = []
    @MainActor @Published var isAuthorized = false
    
    init() {
        // 初始化时检查现有权限状态
        Task { @MainActor in
            // 先检查现有权限
            let authStatus = EKEventStore.authorizationStatus(for: .reminder)
            
            switch authStatus {
            case .authorized, .fullAccess:
                // 已经有权限，直接设置状态并获取数据
                self.isAuthorized = true
                await self.fetchReminders()
            case .notDetermined:
                // 未决定状态，请求权限
                await requestAccess()
            default:
                // 其他状态（如被拒绝），设置未授权状态
                self.isAuthorized = false
            }
        }
    }
    
    @MainActor
    func requestAccess() async {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            self.isAuthorized = granted
            if granted {
                print("获得权限，开始获取提醒事项...")
                await self.fetchReminders()
            } else {
                print("未获得权限")
            }
        } catch {
            print("提醒事项权限请求失败: \(error)")
            self.isAuthorized = false
        }
    }
    
    @MainActor
    func fetchReminders() async {
        // 获取时间范围
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)
        let threeDaysFromNow = calendar.date(byAdding: .day, value: 2, to: now)!
        // 可以查询两天前的提醒事项
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        
        do {
            // 使用单独的函数获取未完成和已完成的任务
            let uncompletedPredicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: twoDaysAgo,          // 包含没有截止日期的任务
                ending: threeDaysFromNow,          // 截止日期在3天内的任务
                calendars: nil
            )
            
            let completedPredicate = eventStore.predicateForCompletedReminders(
                withCompletionDateStarting: startOfDay,
                ending: endOfDay,
                calendars: nil
            )
            
            // 获取未完成任务
            let uncompleted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
                eventStore.fetchReminders(matching: uncompletedPredicate) { reminders in
                    if let reminders = reminders {
                        continuation.resume(returning: reminders)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ReminderService", code: -1))
                    }
                }
            }
            
            // 获取已完成任务
            let completed = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
                eventStore.fetchReminders(matching: completedPredicate) { reminders in
                    if let reminders = reminders {
                        continuation.resume(returning: reminders)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ReminderService", code: -1))
                    }
                }
            }
            
            // 合并结果
            let allReminders = uncompleted + completed
            
            // 在主线程上更新 UI
            await MainActor.run {
                withAnimation {
                    self.reminders = allReminders
                }
            }
            
        } catch {
            print("获取提醒事项失败: \(error)")
        }
    }
    
    func toggleCompletion(for reminder: EKReminder) {
        Task { @MainActor in
            do {
                reminder.isCompleted = !reminder.isCompleted
                try eventStore.save(reminder, commit: true)
                print("任务状态已更新：\(reminder.title ?? "无标题") - 完成状态：\(reminder.isCompleted)")
                await fetchReminders() // 重新获取最新数据
            } catch {
                print("更新任务状态失败：\(error)")
            }
        }
    }
    
    func updateReminder(_ reminder: EKReminder) async throws {
        // 确保 reminder 是有效的
        guard reminder.hasChanges else { return }
        
        // 添加错误处理和验证
        do {
            try eventStore.save(reminder, commit: true)
            await fetchReminders() // 重新获取最新数据
        } catch {
            print("保存提醒事项失败: \(error)")
            throw error
        }
    }
    
    func deleteReminder(_ reminder: EKReminder) async throws {
        try eventStore.remove(reminder, commit: true)
        await fetchReminders() // 重新获取最新数据
    }
    
    func getReminder(byId id: String) -> EKReminder? {
        let eventStore = EKEventStore()
        return eventStore.calendarItem(withIdentifier: id) as? EKReminder
    }
    
    func checkAndRequestAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            do {
                return try await eventStore.requestAccess(to: .reminder)
            } catch {
                print("请求提醒事项权限失败: \(error)")
                return false
            }
        default:
            return false
        }
    }
} 
