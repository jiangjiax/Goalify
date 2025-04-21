import SwiftUI
import EventKit

struct TasksConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    let reminderService: ReminderService
    let tasks: [ReminderInfo]
    
    @State private var selectedTasks: Set<UUID> = Set()
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var showingResult = false
    @State private var taskIDs: [UUID]
    
    init(reminderService: ReminderService, tasks: [ReminderInfo]) {
        self.reminderService = reminderService
        self.tasks = tasks
        
        // 为每个任务生成一个唯一ID
        let ids = tasks.map { _ in UUID() }
        _taskIDs = State(initialValue: ids)
        // 默认全选
        _selectedTasks = State(initialValue: Set(ids))
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(zip(taskIDs, tasks)), id: \.0) { id, task in
                        TaskRowView(
                            task: task,
                            isSelected: selectedTasks.contains(id),
                            onToggle: {
                                if selectedTasks.contains(id) {
                                    selectedTasks.remove(id)
                                } else {
                                    selectedTasks.insert(id)
                                }
                            }
                        )
                    }
                } header: {
                    HStack {
                        Text("AI 生成的任务")
                        Spacer()
                        Button(selectedTasks.count == tasks.count ? "取消全选" : "全选") {
                            if selectedTasks.count == tasks.count {
                                selectedTasks.removeAll()
                            } else {
                                selectedTasks = Set(taskIDs)
                            }
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("确认任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认添加") {
                        isProcessing = true
                        addSelectedReminders()
                    }
                    .disabled(selectedTasks.isEmpty || isProcessing)
                }
            }
            .overlay(
                Group {
                    if isProcessing {
                        ProcessingView(processedCount: $processedCount, totalCount: selectedTasks.count)
                    }
                }
            )
            .alert("添加完成", isPresented: $showingResult) {
                Button("确定", role: .cancel) {
                    NotificationCenter.default.post(name: Notification.Name("RefreshReminders"), object: nil)
                    dismiss()
                }
            } message: {
                Text("已成功添加 \(processedCount) 个任务")
            }
        }
    }
    
    private func addSelectedReminders() {
        // 使用已有的 taskIDs 而不是重新生成
        let taskMap = Dictionary(uniqueKeysWithValues: zip(taskIDs, tasks))
        
        // 筛选出选中的任务
        let selectedTasksArray = taskMap
            .filter { selectedTasks.contains($0.key) }
            .map { $0.value }
        
        Task {
            processedCount = 0
            for task in selectedTasksArray {
                do {
                    let reminder = EKReminder(eventStore: reminderService.eventStore)
                    
                    // 设置日历
                    if let defaultCalendar = reminderService.eventStore.defaultCalendarForNewReminders() {
                        reminder.calendar = defaultCalendar
                    } else if let firstCalendar = reminderService.eventStore.calendars(for: .reminder).first {
                        reminder.calendar = firstCalendar
                    } else {
                        continue // 跳过无法设置日历的任务
                    }
                    
                    // 设置基本信息
                    reminder.title = task.title
                    reminder.notes = task.notes
                    reminder.priority = task.priority
                    
                    // 设置截止时间
                    if let dueDate = task.dueDate, let date = ViewHelpers.parseDate(dueDate) {
                        reminder.dueDateComponents = Calendar.current.dateComponents(
                            [.year, .month, .day, .hour, .minute],
                            from: date
                        )
                    }
                    
                    // 设置提醒
                    if task.hasAlarm, let alarmDate = task.alarmDate, let date = ViewHelpers.parseDate(alarmDate) {
                        let alarm = EKAlarm(absoluteDate: date)
                        reminder.addAlarm(alarm)
                    }
                    
                    // 设置重复规则
                    if task.recurrenceRule != "none" {
                        if let frequency = ViewHelpers.getRecurrenceFrequency(from: task.recurrenceRule) {
                            let rule = EKRecurrenceRule(
                                recurrenceWith: frequency,
                                interval: task.recurrenceInterval,
                                end: nil
                            )
                            reminder.addRecurrenceRule(rule)
                        }
                    }
                    
                    try await reminderService.updateReminder(reminder)
                    DispatchQueue.main.async {
                        processedCount += 1
                    }
                } catch {
                    print("添加任务失败: \(error)")
                }
            }
            
            // 显示结果
            DispatchQueue.main.async {
                isProcessing = false
                showingResult = true
            }
        }
    }
}

// 任务行视图
struct TaskRowView: View {
    let task: ReminderInfo
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 复选框
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // 任务内容区域
                VStack(alignment: .leading, spacing: 4) {
                    // 标题和优先级
                    HStack {
                        Text(task.title)
                            .font(.headline)
                        
                        Spacer()
                        
                        // 优先级标识
                        if task.priority > 0 {
                            Image(systemName: priorityIcon(for: task.priority))
                                .foregroundColor(priorityColor(for: task.priority))
                        }
                    }
                    
                    // 备注
                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // 时间信息
                    HStack(spacing: 8) {
                        if let dueDate = task.dueDate, let date = ViewHelpers.parseDate(dueDate) {
                            Label {
                                Text(date.formatted(.dateTime.month().day().hour().minute()))
                                    .font(.caption)
                            } icon: {
                                Image(systemName: "calendar")
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        if task.recurrenceRule != "none" {
                            Label {
                                Text(recurrenceText(task.recurrenceRule))
                                    .font(.caption)
                            } icon: {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func priorityIcon(for priority: Int) -> String {
        switch priority {
        case 1: return "exclamationmark.3"
        case 5: return "exclamationmark.2"
        case 9: return "exclamationmark"
        default: return "circle"
        }
    }
    
    private func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 1: return .red
        case 5: return .orange
        case 9: return .blue
        default: return .gray
        }
    }
    
    private func recurrenceText(_ rule: String) -> String {
        switch rule {
        case "daily": return "每天"
        case "weekly": return "每周"
        case "monthly": return "每月"
        case "yearly": return "每年"
        default: return "不重复"
        }
    }
}

// 处理中视图
struct ProcessingView: View {
    @Binding var processedCount: Int
    let totalCount: Int
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("正在添加任务...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(processedCount)/\(totalCount)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(24)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
} 