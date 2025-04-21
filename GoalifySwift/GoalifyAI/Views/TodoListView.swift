import SwiftUI
import EventKit
import AudioToolbox

struct TodoListView: View {
    @StateObject private var reminderService = ReminderService()
    @State private var showingUnauthorizedAlert = false
    @State private var selectedTab = 0 // 0: 72小时要事, 1: 已完成
    @State private var isRefreshing = false // 添加刷新状态
    @State private var isTipExpanded = false // 添加展开状态控制
    @State private var showingAddTask = false // 添加添加任务的标志
    
    // 添加 onAppear 标志
    @State private var hasAppeared = false
    
    // 修改日期分组枚举，添加 CaseIterable 协议
    private enum DateGroup: Int, Comparable, CaseIterable {
        case dayBeforeYesterday = 0
        case yesterday = 1
        case today = 2
        case tomorrow = 3
        case dayAfterTomorrow = 4
        case other = 500
        case noDate = 999
        
        var localizedTitle: String {
            switch self {
            case .dayBeforeYesterday: return NSLocalizedString("前天", comment: "Day before yesterday")
            case .yesterday: return NSLocalizedString("昨天", comment: "Yesterday")
            case .today: return NSLocalizedString("今天", comment: "Today")
            case .tomorrow: return NSLocalizedString("明天", comment: "Tomorrow")
            case .dayAfterTomorrow: return NSLocalizedString("后天", comment: "Day after tomorrow")
            case .noDate: return NSLocalizedString("未设置日期", comment: "No date set")
            case .other: return "" // 将使用具体日期
            }
        }
        
        static func < (lhs: DateGroup, rhs: DateGroup) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // 修改分组函数
    private func groupReminders(_ reminders: [EKReminder]) -> [(String, [EKReminder])] {
        let calendar = Calendar.current
        let now = Date()
        
        // 创建日期分组
        var groups: [DateGroup: [EKReminder]] = [:]
        var otherDateGroups: [Date: [EKReminder]] = [:] // 存储其他具体日期的任务
        
        for reminder in reminders {
            if let dueDate = reminder.dueDateComponents?.date {
                let dateGroup: DateGroup
                
                if calendar.isDateInToday(dueDate) {
                    dateGroup = .today
                } else if calendar.isDateInYesterday(dueDate) {
                    dateGroup = .yesterday
                } else if calendar.isDate(dueDate, equalTo: calendar.date(byAdding: .day, value: -2, to: now)!, toGranularity: .day) {
                    dateGroup = .dayBeforeYesterday
                } else if calendar.isDateInTomorrow(dueDate) {
                    dateGroup = .tomorrow
                } else if calendar.isDate(dueDate, equalTo: calendar.date(byAdding: .day, value: 2, to: now)!, toGranularity: .day) {
                    dateGroup = .dayAfterTomorrow
                } else {
                    // 其他日期存储在单独的字典中
                    otherDateGroups[dueDate, default: []].append(reminder)
                    continue
                }
                
                groups[dateGroup, default: []].append(reminder)
            } else {
                groups[.noDate, default: []].append(reminder)
            }
        }
        
        // 合并结果并排序
        var result: [(String, [EKReminder])] = groups.map { (group, reminders) in
            (group.localizedTitle, reminders)
        }
        
        // 添加其他日期的分组，按日期排序
        let otherGroups = otherDateGroups.sorted { $0.key < $1.key }.map { (date, reminders) in
            (date.formatted(.dateTime.month().day()), reminders)
        }
        
        // 按照枚举的顺序排序特殊分组
        result.sort { (group1, group2) in
            let group1Type = DateGroup.allCases.first { $0.localizedTitle == group1.0 } ?? .other
            let group2Type = DateGroup.allCases.first { $0.localizedTitle == group2.0 } ?? .other
            return group1Type < group2Type
        }
        
        // 将其他日期的分组添加到结果末尾
        result.append(contentsOf: otherGroups)
        
        return result
    }

    // 修改任务列表部分
    private var remindersList: some View {
        ScrollView {
            VStack(spacing: 8) {
                if selectedTab == 0 {
                    // 未完成任务分组显示
                    let uncompleted = reminderService.reminders.filter { !$0.isCompleted }
                    if uncompleted.isEmpty {
                        EmptyStateToDoView(
                            icon: "checkmark.circle",
                            title: "暂无待办事项",
                            subtitle: "添加一些任务到提醒事项中"
                        )
                        .transition(.opacity)
                    } else {
                        ForEach(groupReminders(uncompleted), id: \.0) { group in
                            ReminderGroupView(
                                title: group.0,
                                reminders: group.1,
                                reminderService: reminderService
                            )
                        }
                    }
                } else {
                    // 已完成任务显示（不分组）
                    let completed = reminderService.reminders.filter { 
                        $0.isCompleted && Calendar.current.isDateInToday($0.completionDate ?? Date())
                    }
                    if completed.isEmpty {
                        EmptyStateToDoView(
                            icon: "hands.clap",
                            title: "今日暂无完成事项",
                            subtitle: "完成的任务将显示在这里"
                        )
                    } else {
                        // 直接显示已完成任务列表
                        VStack(spacing: 4) { // 减小任务之间的间距
                            ForEach(completed, id: \.calendarItemIdentifier) { reminder in
                                ModernReminderRowView(
                                    reminder: reminder,
                                    onToggle: {
                                        withAnimation(.spring(response: 0.3)) {
                                            reminderService.toggleCompletion(for: reminder)
                                        }
                                    },
                                    reminderService: reminderService
                                )
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.top, 2)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏和分段控制器
            HStack {
                // 分段控制器 - 使用自定义样式
                HStack(spacing: 0) {
                    // 近期要事清单按钮
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = 0
                        }
                    }) {
                        Text("近期要事清单")
                            .font(.system(size: 13, weight: selectedTab == 0 ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundColor(selectedTab == 0 ? .white : .primary)
                            .background(selectedTab == 0 ? Color.blue : Color.clear)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    // 今日已完成按钮
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = 1
                        }
                    }) {
                        Text("今日已完成")
                            .font(.system(size: 13, weight: selectedTab == 1 ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundColor(selectedTab == 1 ? .white : .primary)
                            .background(selectedTab == 1 ? Color.blue : Color.clear)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(Color(.systemGray6).opacity(0.7))
                .cornerRadius(10)
                
                Spacer()
                
                // 刷新按钮 - 现代化设计
                Button(action: {
                    // 开始刷新动画
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        isRefreshing = true
                    }
                    
                    // 执行刷新
                    Task {
                        await reminderService.fetchReminders()
                        // 停止刷新动画
                        withAnimation {
                            isRefreshing = false
                        }
                    }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6).opacity(0.7))
                        .clipShape(Circle())
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // 替换原来的任务列表
            remindersList
            
            Spacer() // 添加这个让内容靠上对齐
        }
        .task {
            if !reminderService.isAuthorized {
                showingUnauthorizedAlert = true
            }
            await reminderService.fetchReminders()
            // 标记为已加载
            hasAppeared = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshReminders"))) { _ in
            // 只有在视图已经加载后才响应刷新通知
            if hasAppeared {
                Task {
                    // 开始刷新动画
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        isRefreshing = true
                    }
                    
                    await reminderService.fetchReminders()
                    
                    // 停止刷新动画
                    withAnimation {
                        isRefreshing = false
                    }
                }
            }
        }
        .alert("需要访问提醒事项", isPresented: $showingUnauthorizedAlert) {
            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {
                showingUnauthorizedAlert = false
            }
        } message: {
            Text("请在设置中允许访问提醒事项以使用此功能")
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(
                reminderService: reminderService,
                reminderInfo: ReminderInfo(
                    title: "",
                    notes: "",
                    priority: 0,
                    dueDate: nil,
                    hasAlarm: false,
                    alarmDate: nil,
                    recurrenceRule: "none",
                    recurrenceInterval: 1
                )
            )
        }
    }
}

// 现代化的提醒事项行
struct ModernReminderRowView: View {
    let reminder: EKReminder
    let onToggle: () -> Void
    @State private var isPressed = false
    @State private var showingFocusTimer = false
    @State private var showingDetail = false
    @ObservedObject var reminderService: ReminderService
    @StateObject private var calendarService = CalendarService()
    @State private var focusDuration: TimeInterval = 0
    
    // 添加播放完成音效的方法
    private func playCompletionSound() {
        AudioServicesPlaySystemSound(1103) // 1004 是系统的完成提示音 ID
    }
    
    // 修改日期格式化方法
    private func relativeDateString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "今天 \(date.formatted(.dateTime.hour().minute()))"
        } else if calendar.isDateInYesterday(date) {
            return "昨天 \(date.formatted(.dateTime.hour().minute()))"
        } else if calendar.isDate(date, equalTo: calendar.date(byAdding: .day, value: -2, to: now)!, toGranularity: .day) {
            return "前天 \(date.formatted(.dateTime.hour().minute()))"
        } else if calendar.isDateInTomorrow(date) {
            return "明天 \(date.formatted(.dateTime.hour().minute()))"
        } else if calendar.isDate(date, equalTo: calendar.date(byAdding: .day, value: 2, to: now)!, toGranularity: .day) {
            return "后天 \(date.formatted(.dateTime.hour().minute()))"
        } else {
            return date.formatted(.dateTime.month().day().hour().minute())
        }
    }
    
    // 优先级显示配置
    private func priorityConfig(for priority: Int) -> (icon: String, color: Color)? {
        switch priority {
        case 1: // 高优先级
            return ("exclamationmark.3", .red)
        case 5: // 中优先级
            return ("exclamationmark.2", .orange)
        case 9: // 低优先级
            return ("exclamationmark", .blue)
        default:
            return nil
        }
    }
    
    // 获取重复规则图标
    private func recurrenceIcon(for reminder: EKReminder) -> (icon: String, text: String)? {
        guard let recurrenceRules = reminder.recurrenceRules, let rule = recurrenceRules.first else {
            return nil
        }
        
        switch rule.frequency {
        case .daily:
            return ("arrow.clockwise", "每天")
        case .weekly:
            return ("arrow.clockwise", "每周")
        case .monthly:
            return ("arrow.clockwise", "每月")
        case .yearly:
            return ("arrow.clockwise", "每年")
        default:
            return nil
        }
    }
    
    private var taskInfoSection: some View {
        HStack(spacing: 8) {
            if let dueDate = reminder.dueDateComponents?.date {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(relativeDateString(from: dueDate))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            // 显示列表信息
            if let calendar = reminder.calendar {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(calendar.title)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    var body: some View {
        // 移除外层的 padding，让卡片占据全宽
        HStack(spacing: 12) {
            // 复选框按钮
            Button(action: {
                if !reminder.isCompleted {
                    playCompletionSound()
                }
                onToggle()
            }) {
                ZStack {
                    Circle()
                        .stroke(reminder.isCompleted ? Color.green : Color.gray.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    
                    if reminder.isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // 任务内容区域
            VStack(alignment: .leading, spacing: 4) {
                // 第一行：标题和图标
                HStack(spacing: 4) {
                    // 显示优先级标识
                    if let config = priorityConfig(for: reminder.priority) {
                        Image(systemName: config.icon)
                            .font(.system(size: 10))
                            .foregroundColor(config.color)
                    }

                    Text(reminder.title ?? "无标题任务")
                        .font(.system(size: 16))
                        .strikethrough(reminder.isCompleted)
                        .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                    
                    // 显示重复规则图标
                    if let recurrence = recurrenceIcon(for: reminder) {
                        Image(systemName: recurrence.icon)
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                            .help(recurrence.text)
                    }
                }
                
                // 第二行：日期和列表信息
                taskInfoSection
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingDetail = true
            }
            
            Spacer() // 确保内容区域占据所有可用空间
            
            // 专注按钮
            Button(action: {
                showingFocusTimer = true
            }) {
                Image(systemName: "timer")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16) // 只保留一个水平内边距
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16) // 改为更小的外边距，让卡片更宽
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                ReminderDetailView(
                    reminder: reminder,
                    reminderService: reminderService
                )
            }
        }
        .sheet(isPresented: $showingFocusTimer) {
            FocusTimerView(
                reminder: reminder,
                reminderService: reminderService
            )
        }
        .task {
            // 获取专注时长
            if let title = reminder.title {
                do {
                    focusDuration = try await calendarService.getFocusTimeForTask(title: title)
                } catch {
                    print("获取专注时长失败: \(error)")
                }
            }
        }
    }
}

// 修改分组视图组件样式
struct ReminderGroupView: View {
    let title: String
    let reminders: [EKReminder]
    @ObservedObject var reminderService: ReminderService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) { // 减小内部间距
            // 分组标题
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                // 添加任务数量指示
                Text("\(reminders.count)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            
            // 分组内的提醒事项
            VStack(spacing: 4) { // 减小任务之间的间距
                ForEach(reminders, id: \.calendarItemIdentifier) { reminder in
                    ModernReminderRowView(
                        reminder: reminder,
                        onToggle: {
                            withAnimation(.spring(response: 0.3)) {
                                reminderService.toggleCompletion(for: reminder)
                            }
                        },
                        reminderService: reminderService
                    )
                }
            }
        }
        .padding(.vertical, 4) // 减小分组的外边距
    }
}

// 将 EmptyStateView 改为独立的结构体
struct EmptyStateToDoView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.4))
                    .padding(.bottom, 4)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 30)
            Spacer()
        }
    }
}

#Preview {
    TodoListView()
} 
