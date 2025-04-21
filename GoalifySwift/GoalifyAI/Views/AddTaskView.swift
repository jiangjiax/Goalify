import SwiftUI
import EventKit

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    let reminderService: ReminderService
    
    // 基本信息
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var showingTips = false
    
    // 时间设置
    @State private var hasDeadline = false
    @State private var deadline = Date()
    
    // 提醒设置
    @State private var hasAlarm = false
    @State private var alarmDate = Date()
    @State private var alarmRelative = true
    @State private var alarmOffset: TimeInterval = -3600 // 默认提前1小时
    
    // 重复设置
    @State private var repeatFrequency: EKRecurrenceFrequency?
    @State private var repeatInterval: Int = 1
    
    // 优先级设置
    @State private var priority: Int = 0
    
    // 列表选择
    @State private var selectedCalendar: EKCalendar
    
    init(reminderService: ReminderService, reminderInfo: ReminderInfo) {
        self.reminderService = reminderService
        
        // 获取可用的提醒事项日历
        let calendars = reminderService.eventStore.calendars(for: .reminder)
        
        // 获取默认日历或第一个可用日历
        let defaultCalendar: EKCalendar
        if let systemDefault = reminderService.eventStore.defaultCalendarForNewReminders() {
            defaultCalendar = systemDefault
        } else if let firstCalendar = calendars.first {
            defaultCalendar = firstCalendar
        } else {
            // 如果没有可用的日历，创建一个新的
            let newCalendar = EKCalendar(for: .reminder, eventStore: reminderService.eventStore)
            newCalendar.title = "提醒"
            if let source = reminderService.eventStore.sources.first(where: { $0.sourceType == .local }) {
                newCalendar.source = source
                do {
                    try reminderService.eventStore.saveCalendar(newCalendar, commit: true)
                    defaultCalendar = newCalendar
                } catch {
                    print("创建默认日历失败: \(error)")
                    // 使用临时日历作为后备方案
                    defaultCalendar = EKCalendar(for: .reminder, eventStore: reminderService.eventStore)
                }
            } else {
                defaultCalendar = EKCalendar(for: .reminder, eventStore: reminderService.eventStore)
            }
        }
        
        // 使用默认日历作为初始值
        _selectedCalendar = State(initialValue: defaultCalendar)
        
        // 基本信息初始化
        _title = State(initialValue: reminderInfo.title)
        _notes = State(initialValue: reminderInfo.notes)
        _priority = State(initialValue: reminderInfo.priority)
        
        // 安全地解析截止日期
        if let dueDate = reminderInfo.dueDate,
           let parsedDate = ViewHelpers.parseDate(dueDate) {
            _hasDeadline = State(initialValue: true)
            _deadline = State(initialValue: parsedDate)
        } else {
            _hasDeadline = State(initialValue: false)
            _deadline = State(initialValue: Date())
        }
        
        // 安全地解析提醒时间
        _hasAlarm = State(initialValue: reminderInfo.hasAlarm)
        if let alarmDateString = reminderInfo.alarmDate,
           let parsedAlarmDate = ViewHelpers.parseDate(alarmDateString) {
            _alarmDate = State(initialValue: parsedAlarmDate)
        } else {
            _alarmDate = State(initialValue: Date())
        }
        
        // 重复设置初始化
        _repeatFrequency = State(initialValue: ViewHelpers.getRecurrenceFrequency(from: reminderInfo.recurrenceRule))
        _repeatInterval = State(initialValue: reminderInfo.recurrenceInterval)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 基本信息部分
                Section {
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
                }
                
                // 时间设置部分
                Section("时间设置") {
                    Toggle("设置截止时间", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("截止时间", selection: $deadline)
                    }
                    
                    Toggle(isOn: $hasAlarm) {
                        Label("提醒", systemImage: "bell")
                    }
                    
                    if hasAlarm {
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
                
                // 重复设置
                Section("重复") {
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
                }
                
                // 优先级设置
                Section("优先级") {
                    Picker("优先级", selection: $priority) {
                        Text("无").tag(0)
                        Text("高").tag(1)
                        Text("中").tag(5)
                        Text("低").tag(9)
                    }
                    .pickerStyle(.segmented)
                }
                
                // 列表选择
                Section("列表") {
                    let calendars = reminderService.eventStore.calendars(for: .reminder)
                    if calendars.isEmpty {
                        Text("没有可用的提醒事项列表")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("选择列表", selection: $selectedCalendar) {
                            ForEach(calendars, id: \.calendarIdentifier) { calendar in
                                HStack {
                                    Circle()
                                        .fill(Color(cgColor: calendar.cgColor))
                                        .frame(width: 12, height: 12)
                                    Text(calendar.title)
                                    if calendar == reminderService.eventStore.defaultCalendarForNewReminders() {
                                        Text("(默认)")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                                .tag(calendar)
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        saveReminder()
                    }
                    .disabled(title.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingTips = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingTips) {
            TaskTipsView()
        }
    }
    
    private func saveReminder() {
        Task {
            do {
                let reminder = EKReminder(eventStore: reminderService.eventStore)
                
                // 确保有可用的日历
                let calendar: EKCalendar
                if selectedCalendar.allowsContentModifications {
                    calendar = selectedCalendar
                } else if let defaultCalendar = reminderService.eventStore.defaultCalendarForNewReminders() {
                    calendar = defaultCalendar
                } else if let firstCalendar = reminderService.eventStore.calendars(for: .reminder).first {
                    calendar = firstCalendar
                } else {
                    throw NSError(
                        domain: "ReminderService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "请在系统设置中启用提醒事项功能"]
                    )
                }
                
                reminder.calendar = calendar
                reminder.title = title
                reminder.notes = notes
                reminder.priority = priority
                
                // 设置截止时间
                if hasDeadline {
                    reminder.dueDateComponents = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: deadline
                    )
                }
                
                // 设置提醒
                if hasAlarm {
                    if alarmRelative {
                        let alarm = EKAlarm(relativeOffset: alarmOffset)
                        reminder.addAlarm(alarm)
                    } else {
                        let alarm = EKAlarm(absoluteDate: alarmDate)
                        reminder.addAlarm(alarm)
                    }
                }
                
                // 设置重复规则
                if let frequency = repeatFrequency {
                    let rule = EKRecurrenceRule(
                        recurrenceWith: frequency,
                        interval: repeatInterval,
                        end: nil
                    )
                    reminder.addRecurrenceRule(rule)
                }
                
                try await reminderService.updateReminder(reminder)
                print("任务创建成功")
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("RefreshReminders"), object: nil)
                }
                
                dismiss()
            } catch {
                print("创建任务失败: \(error)")
                // TODO: 显示错误提示
            }
        }
    }
}

// 任务提示视图
struct TaskTipsView: View {
    @Environment(\.dismiss) private var dismiss
    
    let tips = [
        ("72小时原则", "问问自己：这件事我打算在未来三天内开始做吗？如果答案是否，不妨先放到\"以后再说\"。"),
        ("设定难度", "根据任务的复杂程度设置难度，这样我们可以在你状态好的时候推荐较难的任务，状态一般时推荐简单的任务。"),
        ("分而治之", "如果是较大的任务，可以先确定第一步，完成后再规划下一步。不要被任务的整体规模吓到。"),
        ("保持灵活", "开始时间只是个参考，要根据实际状态灵活调整。记住：我们不是机器人。")
    ]
    
    var body: some View {
        NavigationView {
            List(tips, id: \.0) { tip in
                VStack(alignment: .leading, spacing: 8) {
                    Text(tip.0)
                        .font(.headline)
                    Text(tip.1)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("小贴士")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
