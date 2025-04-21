import SwiftUI
import EventKit
import AudioToolbox
import BackgroundTasks
import ActivityKit

struct FocusTimerView: View {
    let reminder: EKReminder
    let reminderService: ReminderService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var calendarService = CalendarService()
    @State private var showingCalendarAlert = false
    
    // 使用全局Focus状态管理器
    @StateObject private var focusManager = FocusStateManager.shared
    
    // 本地UI状态
    @State private var showCompletionAlert = false
    @State private var showingCustomDuration = false
    @State private var customMinutes: String = ""
    
    // 预设时间选项（分钟）
    private let timePresets = [15, 25, 45, 60]
    
    // 后台任务标识符
    private let backgroundTaskIdentifier = "com.li.GoalAchieve.focusTimer"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部区域
                VStack(spacing: 20) {
                    // 任务标题
                    Text(reminder.title ?? "专注")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .padding(.horizontal)
                        .padding(.top, 30)
                    
                    // 时间显示
                    Text(focusManager.formattedTime())
                        .font(.system(size: 64, weight: .light, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.vertical, 20)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: focusManager.formattedTime())
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(radius: 20, corners: [.bottomLeft, .bottomRight])
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                // 主内容区域
                ScrollView {
                    VStack(spacing: 30) {
                        // 计时模式选择
                        VStack(spacing: 15) {
                            Text("计时模式")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("计时模式", selection: $focusManager.timeMode) {
                                Text("倒计时").tag(FocusStateManager.TimeMode.countdown)
                                Text("正计时").tag(FocusStateManager.TimeMode.countup)
                            }
                            .pickerStyle(.segmented)
                            .disabled(focusManager.isTimerActive)
                        }
                        .padding(.horizontal)
                        
                        // 时间设置选项
                        if focusManager.timeMode == .countdown && !focusManager.isTimerActive {
                            VStack(spacing: 20) {
                                // 预设时间选择
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                                    ForEach(timePresets, id: \.self) { minutes in
                                        TimePresetButton(minutes: minutes)
                                    }
                                }
                                
                                // 自定义时长按钮
                                Button(action: { showingCustomDuration = true }) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("自定义时长")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 控制按钮
                        HStack(spacing: 30) {
                            // 开始/暂停按钮
                            ControlButton(
                                icon: focusManager.isTimerActive ? "pause.fill" : "play.fill",
                                color: .blue,
                                action: toggleTimer
                            )
                            
                            // 完成按钮
                            if focusManager.isTimerActive || focusManager.timeElapsed > 0 {
                                ControlButton(
                                    icon: "checkmark",
                                    color: .green,
                                    action: { showCompletionAlert = true }
                                )
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .padding(.top, 30)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("专注计时")
            .navigationBarTitleDisplayMode(.inline)
            .alert("专注完成", isPresented: $showCompletionAlert) {
                Button("完成专注并标记任务已完成", role: .none) {
                    handleCompletion()
                }
                Button("仅记录专注时间", role: .none) {
                    handleCancel()
                }
                Button("取消", role: .cancel) { }
            } message: {
                let duration = focusManager.timeElapsed
                let durationText = formatDuration(seconds: duration)
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text("你已专注 \(durationText)")
                        .font(.headline)
                    Text("是否将专注记录添加到日历？")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .sheet(isPresented: $showingCustomDuration) {
                customDurationPicker
            }
            .onAppear {
                // 如果专注状态管理器中没有活动的会话，则初始化一个
                if !focusManager.shouldShowFloatingTimer {
                    // 初始化焦点管理器
                    initializeFocusManagerIfNeeded()
                }
                // 从后台恢复时检查是否应该完成
                focusManager.checkCountdownCompletion()
                // 清除全局的弹窗标志，因为已经在这个视图中处理了
                focusManager.pendingCompletionAlert = false
            }
            .onDisappear {
                // 退出页面但不停止计时器，让悬浮计时器继续显示
            }
        }
        .task {
            if !calendarService.isAuthorized {
                showingCalendarAlert = true
            }
        }
        .alert("需要访问日历", isPresented: $showingCalendarAlert) {
            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("需要日历权限来记录您的专注时间")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CountdownComplete"))) { _ in
            handleCountdownComplete()
        }
    }
    
    // 初始化专注管理器
    private func initializeFocusManagerIfNeeded() {
        // 如果不是从悬浮计时器进入，需要初始化
        if !focusManager.shouldShowFloatingTimer {
            focusManager.currentTitle = reminder.title ?? "专注"
            focusManager.timeMode = .countdown
            focusManager.timeRemaining = 25 * 60
            focusManager.timeElapsed = 0
            focusManager.reminderId = reminder.calendarItemIdentifier
        }
    }
    
    // 自定义时长选择器视图
    private var customDurationPicker: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("输入分钟数", text: $customMinutes)
                        .keyboardType(.numberPad)
                        .font(.body)
                } header: {
                    Text("设置专注时长")
                } footer: {
                    Text("请输入1到240之间的整数")
                }
            }
            .navigationTitle("自定义时长")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingCustomDuration = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        if let minutes = Int(customMinutes), (1...240).contains(minutes) {
                            focusManager.timeRemaining = minutes * 60
                        }
                        showingCustomDuration = false
                    }
                    .disabled(customMinutes.isEmpty || Int(customMinutes) == nil)
                }
            }
        }
    }
    
    // 开始/暂停计时器
    private func toggleTimer() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        
        if focusManager.isTimerActive {
            focusManager.pauseTimer()
        } else {
            if !focusManager.shouldShowFloatingTimer {
                focusManager.startFocusSession(
                    title: reminder.title ?? "专注", 
                    timeMode: focusManager.timeMode, 
                    duration: focusManager.timeRemaining,
                    reminderId: reminder.calendarItemIdentifier
                )
            } else {
                focusManager.resumeTimer()
            }
        }
        generator.impactOccurred()
    }
    
    // 修改完成提醒事项的方法
    private func completeReminder() {
        // 使用 ReminderService 来处理提醒事项的完成状态
        reminderService.toggleCompletion(for: reminder)
    }
    
    // 保存专注时间 - 将专注记录保存到日历
    private func saveFocusTime() {
        guard let (startTime, endTime) = focusManager.getFocusTimeToRecord() else { return }
        
        // 记录专注时间
        saveFocusRecord(startTime: startTime, endTime: endTime)
    }
    
    // 将专注记录保存到日历
    private func saveFocusRecord(startTime: Date, endTime: Date) {
        Task {
            do {
                try await calendarService.saveEvent(
                    title: reminder.title ?? "任务",  // 直接使用任务标题，不添加时长标注
                    startTime: startTime,
                    endTime: endTime
                )
                print("专注记录已保存到日历")
            } catch {
                print("保存专注记录失败: \(error)")
            }
        }
    }
    
    // 格式化持续时间
    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    private func handleCompletion() {
        saveFocusTime()
        completeReminder()
        FocusStateManager.shared.completeFocusSession()
        dismiss()
    }
    
    private func handleCancel() {
        saveFocusTime()
        FocusStateManager.shared.cancelFocusSession()
        dismiss()
    }
    
    private func handleCountdownComplete() {
        // 只保留震动反馈
        AudioServicesPlaySystemSound(1352)
        
        // 显示完成对话框
        showCompletionAlert = true
    }
}

// 时间预设按钮组件
private struct TimePresetButton: View {
    let minutes: Int
    @StateObject private var focusManager = FocusStateManager.shared
    
    var body: some View {
        Button(action: {
            focusManager.timeRemaining = minutes * 60
        }) {
            Text("\(minutes)分钟")
                .font(.subheadline)
                .foregroundColor(focusManager.timeRemaining == minutes * 60 ? .white : .primary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    focusManager.timeRemaining == minutes * 60 ? 
                    AnyView(Capsule().fill(Color.blue)) : 
                    AnyView(Capsule().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                )
        }
    }
}

// 控制按钮组件
private struct ControlButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(color))
                .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }
} 