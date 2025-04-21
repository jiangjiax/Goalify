import Foundation
import SwiftUI
import Combine
import UserNotifications

// 管理全局专注状态的单例类
class FocusStateManager: ObservableObject {
    static let shared = FocusStateManager()
    
    @Published var isTimerActive = false
    @Published var currentTitle: String = ""
    @Published var startTime: Date?
    @Published var timeMode: TimeMode = .countdown
    @Published var timeElapsed: Int = 0
    @Published var timeRemaining: Int = 0
    @Published var reminderId: String?
    @Published var reminderTitle: String = ""
    @Published var isCountdownCompleted = false
    @Published var completedTime: Date?
    @Published var pendingCompletionAlert = false
    
    // 判断是否应该显示悬浮计时器
    var shouldShowFloatingTimer: Bool {
        return isTimerActive
    }
    
    // 计时模式
    enum TimeMode {
        case countdown
        case countup
    }
    
    // 用于存储计时器
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // 开始一个新的专注会话
    func startFocusSession(title: String, timeMode: TimeMode, duration: Int = 25 * 60, reminderId: String?) {
        self.currentTitle = title
        self.reminderTitle = title
        self.timeMode = timeMode
        self.timeRemaining = duration
        self.timeElapsed = 0
        self.startTime = Date()
        self.reminderId = reminderId
        self.isTimerActive = true
        
        // 保存初始时长（新增）
        UserDefaults.standard.set(duration, forKey: "initialTimerDuration")
        
        // 保存初始状态到 UserDefaults
        saveTimerState()
        
        startTimer()
    }
    
    // 继续已有的专注会话
    func resumeTimer() {
        if !isTimerActive {
            isTimerActive = true
            startTimer()
        }
    }
    
    // 暂停专注计时
    func pauseTimer() {
        isTimerActive = false
        timer?.invalidate()
        timer = nil
    }
    
    // 停止专注会话
    func stopFocusSession() {
        isTimerActive = false
        timer?.invalidate()
        timer = nil
        
        // 清除状态
        UserDefaults.standard.removeObject(forKey: "FocusTimerState")
        
        // 清除所有状态
        currentTitle = ""
        startTime = nil
        timeElapsed = 0
        timeRemaining = 0
        reminderId = nil
    }
    
    // 添加取消专注的方法
    func cancelFocusSession() {
        stopFocusSession()
    }
    
    // 添加完成专注的方法
    func completeFocusSession() {
        stopFocusSession()
    }
    
    // 启动计时器逻辑
    private func startTimer() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.updateTimer()
        }
        
        RunLoop.current.add(timer!, forMode: .common)
        
        // 添加后台倒计时完成检查
        if timeMode == .countdown {
            scheduleBackgroundCompletion()
        }
    }
    
    private func updateTimer() {
        // 每次更新时都基于开始时间和当前时间重新计算
        if let startTime = self.startTime {
            let currentTime = Date()
            let totalElapsedSeconds = Int(currentTime.timeIntervalSince(startTime))
            
            self.timeElapsed = totalElapsedSeconds
            
            if timeMode == .countdown {
                // 从初始时长中减去已经过的时间
                let initialDuration = UserDefaults.standard.integer(forKey: "initialTimerDuration")
                self.timeRemaining = max(0, initialDuration - totalElapsedSeconds)
                
                if timeRemaining == 0 && !isCountdownCompleted {
                    handleCountdownComplete()
                }
            }
            
            // 保存最新状态
            saveTimerState()
        }
    }
    
    // 处理倒计时完成
    private func handleCountdownComplete() {
        isCountdownCompleted = true
        completedTime = Date()  // 记录实际完成时间
        pendingCompletionAlert = true
        pauseTimer()
        
        // 发送本地通知
        sendCompletionNotification()
        
        // 发送倒计时完成通知
        NotificationCenter.default.post(
            name: NSNotification.Name("CountdownComplete"),
            object: nil
        )
    }
    
    // 发送本地通知
    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "专注完成"
        content.body = "你已完成专注"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // 安排后台完成检查
    private func scheduleBackgroundCompletion() {
        guard let startTime = startTime else { return }
        
        // 计算完成时间
        let completionDate = startTime.addingTimeInterval(TimeInterval(timeRemaining))
        
        // 保存到 UserDefaults
        UserDefaults.standard.set(completionDate.timeIntervalSince1970, forKey: "countdownCompletionTime")
    }
    
    // 检查是否应该完成（从后台恢复时调用）
    func checkCountdownCompletion() {
        guard timeMode == .countdown,
              !isCountdownCompleted,
              let completionTime = UserDefaults.standard.object(forKey: "countdownCompletionTime") as? TimeInterval else {
            return
        }
        
        let completionDate = Date(timeIntervalSince1970: completionTime)
        if Date() >= completionDate {
            handleCountdownComplete()
        }
    }
    
    // 格式化时间显示
    func formattedTime() -> String {
        let timeToFormat = timeMode == .countdown ? timeRemaining : timeElapsed
        let minutes = timeToFormat / 60
        let seconds = timeToFormat % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // 获取应记录的专注时间
    func getFocusTimeToRecord() -> (startTime: Date, endTime: Date)? {
        guard let startTime = startTime else { return nil }
        
        if timeMode == .countdown {
            if isCountdownCompleted {
                // 如果是倒计时且已完成，使用实际完成时间或计算的完成时间
                let endTime = completedTime ?? startTime.addingTimeInterval(TimeInterval(totalDuration))
                return (startTime, endTime)
            } else {
                // 如果是提前结束，使用实际专注时间
                return (startTime, Date())
            }
        } else {
            // 正计时模式，使用实际时间
            return (startTime, Date())
        }
    }
    
    // 添加总时长属性
    private var totalDuration: Int {
        if timeMode == .countdown {
            return timeElapsed + timeRemaining
        }
        return timeElapsed
    }
    
    // 添加保存状态方法
    private func saveTimerState() {
        let state = [
            "title": currentTitle,
            "timeMode": timeMode == .countdown ? "countdown" : "countup",
            "timeRemaining": timeRemaining,
            "timeElapsed": timeElapsed,
            "startTime": startTime?.timeIntervalSince1970 ?? 0,
            "isActive": isTimerActive,
            "pendingAlert": pendingCompletionAlert,
            "isCompleted": isCountdownCompleted
        ] as [String : Any]
        
        UserDefaults.standard.set(state, forKey: "FocusTimerState")
    }
    
    // 添加恢复状态方法
    func restoreTimerState() {
        guard let state = UserDefaults.standard.dictionary(forKey: "FocusTimerState"),
              let startTimeInterval = state["startTime"] as? TimeInterval,
              startTimeInterval > 0 else {
            return
        }
        
        let startTime = Date(timeIntervalSince1970: startTimeInterval)
        let currentTime = Date()
        let elapsedTime = Int(currentTime.timeIntervalSince(startTime))
        
        // 恢复状态
        currentTitle = state["title"] as? String ?? ""
        timeMode = (state["timeMode"] as? String == "countdown") ? .countdown : .countup
        timeElapsed = elapsedTime
        isCountdownCompleted = state["isCompleted"] as? Bool ?? false
        pendingCompletionAlert = state["pendingAlert"] as? Bool ?? false
        
        if timeMode == .countdown {
            let originalRemaining = state["timeRemaining"] as? Int ?? 0
            timeRemaining = max(0, originalRemaining - elapsedTime)
            if timeRemaining == 0 {
                handleCountdownComplete()
            }
        }
    }
    
    // 改进从后台恢复逻辑
    func resumeFromBackground() {
        // 不需要重启计时器，只需要刷新一次状态
        if let startTime = self.startTime {
            let currentTime = Date()
            let elapsedSeconds = Int(currentTime.timeIntervalSince(startTime))
            
            self.timeElapsed = elapsedSeconds
            
            if timeMode == .countdown {
                let initialDuration = UserDefaults.standard.integer(forKey: "initialTimerDuration")
                self.timeRemaining = max(0, initialDuration - elapsedSeconds)
                
                // 检查是否应该完成
                if timeRemaining == 0 && !isCountdownCompleted {
                    handleCountdownComplete()
                } else if timeRemaining == 0 && isCountdownCompleted {
                    // 如果已经完成但可能还没有显示给用户
                    pendingCompletionAlert = true
                }
            }
            
            // 如果计时器应该是活动的，但实际没有在运行，则重启计时器
            if isTimerActive && timer == nil {
                startTimer()
            }
        }
    }
} 
