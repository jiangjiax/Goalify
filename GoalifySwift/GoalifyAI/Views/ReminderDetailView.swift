import SwiftUI
import EventKit

struct ReminderDetailView: View {
    let reminder: EKReminder
    let reminderService: ReminderService
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var notes: String
    @State private var dueDate: Date?
    @State private var priority: Int
    @State private var isEditing = false
    @State private var showingDeleteConfirm = false
    @State private var selectedCalendar: EKCalendar
    @State private var hasAlarm: Bool
    @State private var alarmDate: Date
    @State private var alarmRelative: Bool = true
    @State private var alarmOffset: TimeInterval = -3600 // 默认提前1小时
    @State private var repeatFrequency: EKRecurrenceFrequency?
    @State private var repeatInterval: Int = 1
    @StateObject private var calendarService = CalendarService()
    @State private var focusDuration: TimeInterval = 0
    
    // 初始化器用于设置初始状态
    init(reminder: EKReminder, reminderService: ReminderService) {
        self.reminder = reminder
        self.reminderService = reminderService
        
        // 基本信息初始化
        _title = State(initialValue: reminder.title ?? "")
        _notes = State(initialValue: reminder.notes ?? "")
        _dueDate = State(initialValue: reminder.dueDateComponents?.date)
        _priority = State(initialValue: reminder.priority)
        
        // 使用辅助方法初始化日历
        _selectedCalendar = State(initialValue: Self.initializeCalendar(for: reminder, using: reminderService))
        
        // 使用辅助方法初始化提醒设置
        let alarmSettings = Self.initializeAlarmSettings(from: reminder)
        _hasAlarm = State(initialValue: alarmSettings.hasAlarm)
        _alarmDate = State(initialValue: alarmSettings.date)
        _alarmRelative = State(initialValue: alarmSettings.isRelative)
        _alarmOffset = State(initialValue: alarmSettings.offset)
        
        // 使用辅助方法初始化重复规则
        let recurrenceSettings = Self.initializeRecurrenceSettings(from: reminder)
        _repeatFrequency = State(initialValue: recurrenceSettings.frequency)
        _repeatInterval = State(initialValue: recurrenceSettings.interval)
    }
    
    // 辅助方法：初始化日历
    private static func initializeCalendar(for reminder: EKReminder, using service: ReminderService) -> EKCalendar {
        if let calendar = reminder.calendar {
            return calendar
        }
        if let defaultCalendar = service.eventStore.defaultCalendarForNewReminders() {
            return defaultCalendar
        }
        return service.eventStore.calendars(for: .reminder).first!
    }
    
    // 辅助方法：初始化提醒设置
    private static func initializeAlarmSettings(from reminder: EKReminder) -> (hasAlarm: Bool, date: Date, isRelative: Bool, offset: TimeInterval) {
        guard let alarm = reminder.alarms?.first else {
            return (hasAlarm: false, date: Date(), isRelative: true, offset: -3600)
        }
        
        return (
            hasAlarm: true,
            date: alarm.absoluteDate ?? Date(),
            isRelative: alarm.relativeOffset != 0,
            offset: alarm.relativeOffset
        )
    }
    
    // 辅助方法：初始化重复规则
    private static func initializeRecurrenceSettings(from reminder: EKReminder) -> (frequency: EKRecurrenceFrequency?, interval: Int) {
        guard let rule = reminder.recurrenceRules?.first else {
            return (frequency: nil, interval: 1)
        }
        
        return (frequency: rule.frequency, interval: rule.interval)
    }
    
    var body: some View {
        List {
            basicInfoSection
            timeSettingsSection
            repeatSection
            prioritySection
            calendarSection
            if !isEditing {
                deleteSection
            }
        }
        .navigationTitle(isEditing ? "编辑任务" : "任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            deleteAlert
        } message: {
            Text("确定要删除这个任务吗？此操作无法撤销。")
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
    
    // MARK: - 子视图
    
    private var basicInfoSection: some View {
        Section {
            if isEditing {
                TextField("任务标题", text: $title)
                    .font(.body)
                
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
                    .placeholder(when: notes.isEmpty) {
                        Text("添加备注...")
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
            } else {
                Text(title)
                    .font(.body)
                if !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // 添加专注时长显示
            if focusDuration > 0 {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.blue)
                    Text("累计专注时长")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatFocusDuration(seconds: Int(focusDuration)))
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var timeSettingsSection: some View {
        Section("时间设置") {
            dueDatePicker
            alarmSettings
        }
    }
    
    private var dueDatePicker: some View {
        Group {
            if isEditing {
                Toggle(isOn: Binding(
                    get: { dueDate != nil },
                    set: { if !$0 { dueDate = nil } }
                )) {
                    Label("截止时间", systemImage: "calendar")
                }
                
                if dueDate != nil {
                    DatePicker(
                        "截止时间",
                        selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            } else if let dueDate = dueDate {
                Label(relativeDateString(from: dueDate), systemImage: "calendar")
            }
        }
    }
    
    private var alarmSettings: some View {
        Group {
            if isEditing {
                Toggle(isOn: $hasAlarm) {
                    Label("提醒", systemImage: "bell")
                }
                
                if hasAlarm {
                    alarmTypeSelector
                }
            } else if hasAlarm {
                Label(alarmText, systemImage: "bell")
            }
        }
    }
    
    private var alarmTypeSelector: some View {
        Group {
            Picker("提醒方式", selection: $alarmRelative) {
                Text("相对时间").tag(true)
                Text("指定时间").tag(false)
            }
            .pickerStyle(.segmented)
            
            if alarmRelative {
                Picker("提前时间", selection: $alarmOffset) {
                    Text("提前5分钟").tag(TimeInterval(-300))
                    Text("提前15分钟").tag(TimeInterval(-900))
                    Text("提前30分钟").tag(TimeInterval(-1800))
                    Text("提前1小时").tag(TimeInterval(-3600))
                    Text("提前1天").tag(TimeInterval(-86400))
                }
            } else {
                DatePicker(
                    "提醒时间",
                    selection: $alarmDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
        }
    }
    
    private var repeatSection: some View {
        Section("重复") {
            if isEditing {
                Picker("重复", selection: $repeatFrequency) {
                    Text("不重复").tag(Optional<EKRecurrenceFrequency>.none)
                    Text("每天").tag(Optional(EKRecurrenceFrequency.daily))
                    Text("每周").tag(Optional(EKRecurrenceFrequency.weekly))
                    Text("每月").tag(Optional(EKRecurrenceFrequency.monthly))
                    Text("每年").tag(Optional(EKRecurrenceFrequency.yearly))
                }
                
                if repeatFrequency != nil {
                    Stepper("间隔: \(repeatInterval)", value: $repeatInterval, in: 1...99)
                }
            } else if let frequency = repeatFrequency {
                Label(repeatRuleText(frequency: frequency, interval: repeatInterval),
                      systemImage: "arrow.clockwise")
            }
        }
    }
    
    private var prioritySection: some View {
        Section("优先级") {
            if isEditing {
                Picker("优先级", selection: $priority) {
                    Text("无").tag(0)
                    Text("高").tag(1)
                    Text("中").tag(5)
                    Text("低").tag(9)
                }
                .pickerStyle(.segmented)
            } else {
                HStack {
                    Text(priorityText(for: priority))
                    if let config = priorityConfig(for: priority) {
                        Image(systemName: config.icon)
                            .foregroundColor(config.color)
                    }
                }
            }
        }
    }
    
    private var calendarSection: some View {
        Section("列表") {
            if isEditing {
                Picker("选择列表", selection: $selectedCalendar) {
                    ForEach(reminderService.eventStore.calendars(for: .reminder), id: \.calendarIdentifier) { calendar in
                        HStack {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 12, height: 12)
                            Text(calendar.title)
                        }
                        .tag(calendar)
                    }
                }
            } else {
                HStack {
                    Circle()
                        .fill(Color(cgColor: selectedCalendar.cgColor))
                        .frame(width: 12, height: 12)
                    Text(selectedCalendar.title)
                }
            }
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("删除任务", systemImage: "trash")
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(isEditing ? "完成" : "编辑") {
                if isEditing {
                    saveChanges()
                }
                isEditing.toggle()
            }
        }
    }
    
    private var deleteAlert: some View {
        Group {
            Button("删除", role: .destructive) {
                deleteReminder()
            }
            Button("取消", role: .cancel) { }
        }
    }
    
    private var alarmText: String {
        if alarmRelative {
            switch alarmOffset {
            case -300: return "提前5分钟提醒"
            case -900: return "提前15分钟提醒"
            case -1800: return "提前30分钟提醒"
            case -3600: return "提前1小时提醒"
            case -86400: return "提前1天提醒"
            default: return "自定义提醒时间"
            }
        } else {
            return "在 \(alarmDate.formatted(.dateTime.month().day().hour().minute())) 提醒"
        }
    }
    
    private func repeatRuleText(frequency: EKRecurrenceFrequency, interval: Int) -> String {
        let frequencyText: String
        switch frequency {
        case .daily: frequencyText = "天"
        case .weekly: frequencyText = "周"
        case .monthly: frequencyText = "月"
        case .yearly: frequencyText = "年"
        default: frequencyText = ""
        }
        
        return interval == 1 ? "每\(frequencyText)" : "每\(interval)\(frequencyText)"
    }
    
    private func saveChanges() {
        Task {
            do {
                reminder.title = title
                reminder.notes = notes
                reminder.priority = priority
                reminder.calendar = selectedCalendar
                
                // 更新截止时间
                if let dueDate = dueDate {
                    reminder.dueDateComponents = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: dueDate
                    )
                } else {
                    reminder.dueDateComponents = nil
                }
                
                // 更新提醒 - 使用正确的 API
                if let alarms = reminder.alarms {
                    for alarm in alarms {
                        reminder.removeAlarm(alarm)
                    }
                }
                
                if hasAlarm {
                    if alarmRelative {
                        let alarm = EKAlarm(relativeOffset: alarmOffset)
                        reminder.addAlarm(alarm)
                    } else {
                        let alarm = EKAlarm(absoluteDate: alarmDate)
                        reminder.addAlarm(alarm)
                    }
                }
                
                // 更新重复规则
                if let rules = reminder.recurrenceRules {
                    for rule in rules {
                        reminder.removeRecurrenceRule(rule)
                    }
                }
                
                if let frequency = repeatFrequency {
                    let rule = EKRecurrenceRule(
                        recurrenceWith: frequency,
                        interval: repeatInterval,
                        end: nil
                    )
                    reminder.addRecurrenceRule(rule)
                }
                
                try await reminderService.updateReminder(reminder)
                print("任务更新成功")
                isEditing = false
            } catch {
                print("更新任务失败: \(error)")
            }
        }
    }
    
    private func deleteReminder() {
        Task {
            do {
                try await reminderService.deleteReminder(reminder)
                dismiss()
            } catch {
                print("删除任务失败: \(error)")
            }
        }
    }
    
    private func priorityText(for priority: Int) -> String {
        switch priority {
        case 1: return "高优先级"
        case 5: return "中优先级"
        case 9: return "低优先级"
        default: return "无优先级"
        }
    }
    
    private func priorityConfig(for priority: Int) -> (icon: String, color: Color)? {
        switch priority {
        case 1: return ("exclamationmark.3", .red)
        case 5: return ("exclamationmark.2", .orange)
        case 9: return ("exclamationmark", .blue)
        default: return nil
        }
    }
    
    private func relativeDateString(from date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "今天 \(date.formatted(.dateTime.hour().minute()))"
        } else if calendar.isDateInYesterday(date) {
            return "昨天 \(date.formatted(.dateTime.hour().minute()))"
        } else if calendar.isDateInTomorrow(date) {
            return "明天 \(date.formatted(.dateTime.hour().minute()))"
        } else {
            return date.formatted(.dateTime.month().day().hour().minute())
        }
    }
    
    private func formatFocusDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// 添加 TextEditor 占位符支持
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
} 