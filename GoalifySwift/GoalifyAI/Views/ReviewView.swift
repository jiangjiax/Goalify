import SwiftUI
import Charts
import SwiftData
import Foundation

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension Date {
    func formattedDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}

extension String {
    func toDate() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: self)
    }
}

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPeriod = 0
    @State private var selectedTab = 0
    @State private var animateChart = false
    @State private var showingShareSheet = false
    @State private var selectedDate = Date()
    
    // 添加保存截图的状态
    @State private var statisticsImage: UIImage?
    @State private var moodImage: UIImage?
    
    // 添加加载状态
    @State private var isCapturing = false
    
    // 在 ReviewView 中添加缓存属性
    @State private var cachedTimeAllocation: [(String, Int)]?
    @State private var lastCachePeriod: String?
    @State private var lastCacheDate: Date?
    
    // 添加新的状态变量
    @State private var selectedEmotionRecord: EmotionRecord?
    
    let periods = ["日", "周", "月"]
    let tabs = ["统计", "情绪"]
    
    var body: some View {
        ZStack {
            ReviewTheme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ReviewHeader(
                    selectedTab: $selectedTab,
                    selectedPeriod: $selectedPeriod,
                    animateChart: $animateChart,
                    periods: periods,
                    tabs: tabs
                )
                
                // 内容区域 - 添加id以便于截图
                TabView(selection: $selectedTab) {
                    DataAnalysisView(
                        period: periods[selectedPeriod],
                        date: selectedDate,
                        animate: animateChart,
                        getTimeAllocation: getTimeAllocation
                    )
                    .id("statistics-view")
                    .tag(0)
                    .background(ViewTagger(tag: "statistics-view-tag"))
                    
                    MoodTrackingView(
                        period: periods[selectedPeriod],
                        date: selectedDate,
                        animate: animateChart
                    )
                    .id("mood-view")
                    .tag(1)
                    .background(ViewTagger(tag: "mood-view-tag"))
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // 日期导航条
                DateNavigator(
                    periodType: periods[selectedPeriod],
                    selectedDate: $selectedDate
                )
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5),
                    alignment: .top
                )
            }
            
            // 悬浮分享按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        isCapturing = true
                        captureCurrentView()
                    }) {
                        ZStack {
                                Circle()
                                    .fill(ReviewTheme.mainGradient)
                                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                                .frame(width: 56, height: 56)
                            
                            if isCapturing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.trailing, 30)
                    .padding(.bottom, 70)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let statisticsImage = statisticsImage, let moodImage = moodImage {
                // 计算日期范围
                let (startDate, endDate) = calculateDateRange(for: periods[selectedPeriod], date: selectedDate)
                
                // 获取时间分配数据（仅调用一次）
                let timeRecords = getTimeAllocation(for: periods[selectedPeriod], date: selectedDate)
                
                ShareReportView(
                    statisticsImage: statisticsImage,
                    moodImage: moodImage,
                    period: periodToEnglish(periods[selectedPeriod]),
                    startDate: startDate,
                    endDate: endDate,
                    timeRecords: timeRecords
                )
            }
        }
        .sheet(item: $selectedEmotionRecord) { record in
            ReviewEmotionDetailView(emotionRecord: record)
        }
    }
    
    // 捕获当前视图内容
    private func captureCurrentView() {
        isCapturing = true
        
        // 创建要渲染的视图，并调整布局
        let statisticsView = DataAnalysisView(
            period: periods[selectedPeriod],
            date: selectedDate,
            animate: false,
            getTimeAllocation: getTimeAllocation
        )
        .frame(width: UIScreen.main.bounds.width)
        .padding(.top, -50)
        .modelContainer(GoalifyAIApp.sharedModelContainer)
        
        let moodView = MoodTrackingView(
            period: periods[selectedPeriod],
            date: selectedDate,
            animate: false
        )
        .frame(width: UIScreen.main.bounds.width)
        .padding(.top, -50)
        .modelContainer(GoalifyAIApp.sharedModelContainer)
        
        // 确保UI更新完成后再渲染
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 统计视图渲染
            let statsController = UIHostingController(rootView: statisticsView)
            
            // 关键步骤：添加到窗口
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                
                window.addSubview(statsController.view)
                
                // 让视图自己决定大小
                statsController.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    statsController.view.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width),
                    statsController.view.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: -2000)
                ])
                
                // 让视图布局
                statsController.view.setNeedsLayout()
                statsController.view.layoutIfNeeded()
                
                // 延迟渲染，确保视图完全加载
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 获取视图的实际大小
                    let actualSize = statsController.view.systemLayoutSizeFitting(
                        UIView.layoutFittingExpandedSize
                    )
                    
                    // 渲染统计视图
                    let renderer = UIGraphicsImageRenderer(size: actualSize)
                    statisticsImage = renderer.image { _ in
                        statsController.view.drawHierarchy(in: CGRect(origin: .zero, size: actualSize), afterScreenUpdates: true)
                    }
                    
                    // 移除视图
                    statsController.view.removeFromSuperview()
                    
                    // 开始渲染情绪视图
                    let moodController = UIHostingController(rootView: moodView)
                    window.addSubview(moodController.view)
                    
                    // 让视图自己决定大小
                    moodController.view.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        moodController.view.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width),
                        moodController.view.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: -2000)
                    ])
                    
                    // 让视图布局
                    moodController.view.setNeedsLayout()
                    moodController.view.layoutIfNeeded()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // 获取视图的实际大小
                        let moodActualSize = moodController.view.systemLayoutSizeFitting(
                            UIView.layoutFittingExpandedSize
                        )
                        
                        // 渲染情绪视图
                        let moodRenderer = UIGraphicsImageRenderer(size: moodActualSize)
                        moodImage = moodRenderer.image { _ in
                            moodController.view.drawHierarchy(in: CGRect(origin: .zero, size: moodActualSize), afterScreenUpdates: true)
                        }
                        
                        // 移除视图
                        moodController.view.removeFromSuperview()
                        
                        // 完成截图过程
                        isCapturing = false
                        showingShareSheet = true
                    }
                }
            } else {
                isCapturing = false
            }
        }
    }
    
    // 查找当前视图中的ScrollView
    private func findScrollView() -> UIScrollView? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        // 首先找到标记的视图容器
        let targetTag = selectedTab == 0 ? "statistics-view-tag" : "mood-view-tag"
        var targetView: UIView?
        
        // 递归查找标记的视图
        func findTaggedView(_ view: UIView) -> UIView? {
            if let id = view.accessibilityIdentifier, id == targetTag {
                return view
            }
            
            for subview in view.subviews {
                if let found = findTaggedView(subview) {
                    return found
                }
            }
            
            return nil
        }
        
        // 找到标记的视图
        targetView = findTaggedView(window)
        
        // 如果找到了标记的视图，在其中查找ScrollView
        if let containerView = targetView {
            // 递归查找ScrollView
            func findScrollViewIn(_ view: UIView) -> UIScrollView? {
                // 检查当前视图是否是ScrollView
                if let scrollView = view as? UIScrollView {
                    // 确保不是TabView的PageScrollView
                    if !String(describing: type(of: scrollView)).contains("PageScrollView") {
                        return scrollView
                    }
                }
                
                // 递归检查子视图
                for subview in view.subviews {
                    if let found = findScrollViewIn(subview) {
                        return found
                    }
                }
                
                return nil
            }
            
            return findScrollViewIn(containerView)
        }
        
        return nil
    }
    
    // 修改 getTimeAllocation 方法，移除缓存逻辑，保留日志
    private func getTimeAllocation(for period: String, date: Date) -> [(String, Int)] {
        let calendarService = CalendarService()
        
        // 获取时间范围
        let (startDate, endDate) = calculateDateRange(for: period, date: date)
        
        // 获取用户创建的日历
        let userCalendars = calendarService.eventStore.calendars(for: .event).filter { calendar in
            calendar.type == .local || calendar.type == .calDAV
        }
        
        // 获取事件
        let events = calendarService.eventStore.events(
            matching: calendarService.eventStore.predicateForEvents(
                withStart: startDate,
                end: endDate,
                calendars: userCalendars
            )
        )
        
        // 统计每个事件标题的时间
        var timeAllocation: [String: Int] = [:]
        
        for event in events {
            guard let title = event.title, !title.isEmpty else { continue }
            
            // 计算事件持续时间（秒）
            let duration = Int(event.endDate.timeIntervalSince(event.startDate))
            
            // 累加时间
            timeAllocation[title, default: 0] += duration
        }
        
        // 转换为所需格式并按时长排序
        let result = timeAllocation.map { (title, duration) in
            (title, duration)
        }.sorted { $0.1 > $1.1 }
        
        return result
    }
    
    // 修改 formatDuration 方法，确保正确显示时间
    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    // 计算日期范围，返回标准化的时间范围（0点到0点）
    private func calculateDateRange(for periodType: String, date: Date) -> (Date, Date) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // 设置周一为一周的第一天
        calendar.minimumDaysInFirstWeek = 7  // 确保完整的周
        
        // 获取日期的年、月、日组件
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        // 创建当天0点的日期
        let startOfDay = calendar.date(from: components)!
        
        switch periodType {
        case "日":
            // 日：当天0点到次日0点
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
            
        case "周":
            // 获取本周一的日期
            let weekdayComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            guard let startOfWeek = calendar.date(from: weekdayComponents) else {
                // 如果无法获取周范围，返回当天
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                return (startOfDay, endOfDay)
            }
            
            // 获取下周一的日期
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
            
        case "月":
            // 获取本月的开始（1号0点）
            let startOfMonth = calendar.date(from: 
                DateComponents(year: components.year, month: components.month, day: 1))!
            
            // 下月1号0点
            var nextMonthComponents = DateComponents()
            nextMonthComponents.month = 1
            let endOfMonth = calendar.date(byAdding: nextMonthComponents, to: startOfMonth)!
            
            return (startOfMonth, endOfMonth)
            
        default:
            // 默认返回当天
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        }
    }
    
    // 将中文周期转换为英文
    private func periodToEnglish(_ period: String) -> String {
        switch period {
        case "日": return "day"
        case "周": return "week"
        case "月": return "month"
        default: return "day"
        }
    }
}

// 新的数据分析视图（合并统计和时间）
struct DataAnalysisView: View {
    let period: String
    let date: Date
    let animate: Bool
    let getTimeAllocation: (String, Date) -> [(String, Int)]
    
    var body: some View {
        // 提前获取一次时间分配数据
        let timeAllocation = getTimeAllocation(period, date)
        let totalSeconds = timeAllocation.reduce(0) { $0 + $1.1 }
        
        return ScrollView {
            TimeAllocationDetailView(
                period: period,
                date: date,
                animate: animate,
                totalSeconds: totalSeconds,
                timeAllocation: timeAllocation  // 直接传递数据而不是函数
            )
        }
    }
}

struct EmptyTimeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("暂无专注记录")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("开始专注工作，记录你的时间分配吧！")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// 更新卡片样式（移除阴影）
struct StatCard: View {
    let value: String
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 0)
        )
    }
}

// 头部组件
struct ReviewHeader: View {
    @Binding var selectedTab: Int
    @Binding var selectedPeriod: Int
    @Binding var animateChart: Bool
    
    let periods: [String]
    let tabs: [String]
    
    var body: some View {
        VStack(spacing: 16) {
            // 使用CapsuleSegmentPicker替换原来的PeriodSelector
            CapsuleSegmentPicker(
                items: periods,
                itemWidth: nil,
                selection: Binding(
                    get: { periods[selectedPeriod] },
                    set: { newValue in
                        if let index = periods.firstIndex(of: newValue) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedPeriod = index
                            }
                        }
                    }
                ),
                itemTitle: { $0 },
                color: AppTheme.primaryColor
            )
            .frame(height: 36)
            .padding(.horizontal)
            
            // 更新TabSelector布局
            TabSelector(
                selectedTab: $selectedTab,
                animateChart: $animateChart,
                tabs: tabs
            )
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))

        Divider()
    }
}

// 时间周期选择器
struct PeriodSelector: View {
    @Binding var selectedPeriod: Int
    let periods: [String]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<periods.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPeriod = index
                    }
                }) {
                    Text(periods[index])
                        .font(.system(size: 15, weight: selectedPeriod == index ? .bold : .regular))
                        .frame(maxWidth: .infinity) // 让每个选项占据相等的宽度
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                if selectedPeriod == index {
                                    Capsule()
                                        .fill(ReviewTheme.mainGradient)
                                }
                            }
                        )
                        .foregroundColor(selectedPeriod == index ? .white : .gray)
                }
            }
        }
        .padding(.horizontal, 2) // 减小内边距使选项更宽
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal) // 保持外边距与 TabSelector 一致
    }
}

// 标签选择器
struct TabSelector: View {
    @Binding var selectedTab: Int
    @Binding var animateChart: Bool
    let tabs: [String]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                TabButton(
                    tab: tab,
                    index: index,
                    isSelected: selectedTab == index,
                    onTap: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = index
                            animateChart = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    animateChart = true
                                }
                            }
                        }
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20) // 增加左右padding
    }
}

// 标签按钮
struct TabButton: View {
    let tab: String
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // 图标
                Image(systemName: tabIcon(for: index))
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? AppTheme.primaryColor : Color.gray)
                
                Text(tab)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppTheme.primaryColor : Color.gray)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(.systemGray6) : Color.clear)
            )
        }
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "chart.bar.fill"
        case 1: return "heart.fill"
        default: return "circle.fill"
        }
    }
}

// 情绪状态记录视图
struct MoodTrackingView: View {
    let period: String
    let date: Date
    let animate: Bool
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedEmotionRecord: EmotionRecord?
    
    private var moodData: [(id: UUID, day: String, mood: String, note: String)] {
        // 查询 EmotionRecord 数据
        let descriptor = FetchDescriptor<EmotionRecord>()
        guard let records = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        // 根据选择的时间段过滤数据
        let calendar = Calendar.current
        let filteredRecords: [EmotionRecord]
        
        switch period {
        case "日":
            // 获取所选日期当天的记录
            filteredRecords = records.filter { calendar.isDate($0.recordDate, inSameDayAs: date) }
        case "周":
            // 获取所选日期所在周的记录
            let startOfWeek = calendar.startOfWeek(for: date)
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            filteredRecords = records.filter { $0.recordDate >= startOfWeek && $0.recordDate <= endOfWeek }
        case "月":
            // 获取所选日期所在月的记录
            let components = calendar.dateComponents([.year, .month], from: date)
            let startOfMonth = calendar.date(from: components)!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            filteredRecords = records.filter { $0.recordDate >= startOfMonth && $0.recordDate <= endOfMonth }
        default:
            filteredRecords = []
        }
        
        // 转换为所需的数据格式
        return filteredRecords.map { record in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dayString = dateFormatter.string(from: record.recordDate)
            
            // 根据情绪强度确定情绪类型
            let moodType = getMoodType(for: record.intensity)
            
            // 使用触发因素作为笔记
            return (record.id, dayString, moodType, record.emotionType)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if moodData.isEmpty {
                    // 空状态提示
                    VStack(spacing: 16) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text(period == "日" ? "今天还没有记录情绪哦" : "\(period)度还没有情绪记录")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    // 情绪概览卡片
                    VStack(alignment: .leading, spacing: 16) {
                        Text("情绪概览")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 16) {
                            StatCard(
                                value: getMainMood(),
                                title: "主要情绪",
                                icon: "wind",
                                color: .green
                            )
                            
                            StatCard(
                                value: "\(getPositivePercentage())%",
                                title: "积极情绪",
                                icon: "chart.pie.fill",
                                color: .orange
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // 使用新的情绪分布图组件
                    MoodDistributionChart(moodData: getMoodDistribution())
                    
                    // 情绪记录列表
                    VStack(alignment: .leading, spacing: 16) {
                        Text("情绪记录")
                            .font(.headline)
                        
                        ForEach(moodData, id: \.id) { item in
                            MoodRecordCard(id: item.id, day: item.day, mood: item.mood, note: item.note)
                                .onTapGesture {
                                    print("点击情绪记录 ID: \(item.id)")
                                    if let record = getEmotionRecord(by: item.id) {
                                        print("找到记录: \(record.emotionType)")
                                        selectedEmotionRecord = record
                                    } else {
                                        print("未找到对应记录")
                                    }
                                }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
            .padding()
        }

        .sheet(item: $selectedEmotionRecord) { record in
            ReviewEmotionDetailView(emotionRecord: record)
        }
    }
    
    // 获取主要情绪
    private func getMainMood() -> String {
        let moodCounts = moodData.reduce(into: [String: Int]()) { counts, data in
            counts[data.mood, default: 0] += 1
        }
        return moodCounts.max { $0.value < $1.value }?.key ?? "未知"
    }
    
    // 获取积极情绪百分比
    private func getPositivePercentage() -> Int {
        let positiveCount = moodData.filter { $0.mood == "积极" }.count
        return Int(Double(positiveCount) / Double(moodData.count) * 100)
    }
    
    // 获取情绪分布数据
    private func getMoodDistribution() -> [(String, Double, Color)] {
        let total = moodData.count
        guard total > 0 else { return [] }
        
        let counts = moodData.reduce(into: [String: Int]()) { counts, data in
            counts[data.mood, default: 0] += 1
        }
        
        return counts.map { mood, count in
            let percentage = Double(count) / Double(total)
            switch mood {
            case "积极": return (mood, percentage, Color(red: 0.4, green: 0.8, blue: 0.6))
            case "中性": return (mood, percentage, Color(red: 0.9, green: 0.8, blue: 0.4))
            case "消极": return (mood, percentage, Color(red: 1.0, green: 0.5, blue: 0.5))
            default: return (mood, percentage, .gray)
            }
        }
    }
    
    // 修改 getMoodType 方法以接受 Intensity 枚举
    private func getMoodType(for intensity: MoodRecord.Intensity) -> String {
        switch intensity {
        case .low: return "消极"
        case .medium: return "中性"
        case .high: return "积极"
        }
    }
    
    // 修改获取情绪记录的方法
    private func getEmotionRecord(by id: UUID) -> EmotionRecord? {
        let descriptor = FetchDescriptor<EmotionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("查询情绪记录失败: \(error)")
            return nil
        }
    }
}

// 情绪记录卡片
struct MoodRecordCard: View {
    let id: UUID
    let day: String
    let mood: String
    let note: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 情绪类型
            Text(getEmoji(for: mood))
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
                .background(moodColor(for: mood))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(day)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(note)
                    .font(.body)
            }
            
            Spacer()
        }
        .padding()
        .background(ReviewTheme.backgroundColor)
        .cornerRadius(12)
    }
    
    private func moodColor(for mood: String) -> Color {
        switch mood {
        case "积极": return Color(red: 0.4, green: 0.8, blue: 0.6)
        case "中性": return Color(red: 0.9, green: 0.8, blue: 0.4)
        case "消极": return Color(red: 1.0, green: 0.5, blue: 0.5)
        default: return .gray
        }
    }
    
    private func getEmoji(for mood: String) -> String {
        switch mood {
        case "积极": return "😊"
        case "中性": return "😐"
        case "消极": return "😢"
        default: return "❓"
        }
    }
}

// 用于设置特定角落圆角的扩展
extension View {
    func cornerRadius(radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// 修改颜色生成器
private func generateColor(for taskName: String) -> Color {
    // 使用字符的 ASCII 值来生成数值
    let value = taskName.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    let normalizedValue = Double(value % 1000) / 1000.0
    
    // 使用这个值来生成色相
    let hue = normalizedValue
    let saturation = 0.7 + (Double(value % 15) / 100.0)  // 0.7-0.85
    let brightness = 0.9 + (Double(value % 10) / 100.0)   // 0.9-1.0
    
    return Color(
        hue: hue,
        saturation: saturation,
        brightness: brightness
    )
}

// TimeCategory 结构体（保持在全局范围）
private struct TimeCategory: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let duration: Int
    let percentage: Double
}

// TimeAllocationDetailView 结构体
struct TimeAllocationDetailView: View {
    let period: String
    let date: Date
    let animate: Bool
    let totalSeconds: Int
    let timeAllocation: [(String, Int)]  // 直接接收数据
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if timeCategories.isEmpty {
                EmptyTimeView()
                    .padding(.vertical, 50)
            } else {
                TimeChartView(
                    timeCategories: timeCategories,
                    totalSeconds: totalSeconds,
                    animate: animate
                )
                
                TimeCategoryListView(categories: timeCategories)
            }
        }
        .padding()
    }
    
    // timeCategories 只依赖传入的 timeAllocation
    private var timeCategories: [TimeCategory] {
        guard !timeAllocation.isEmpty else { return [] }
        
        return timeAllocation.map { (name, seconds) in
            let percentage = Double(seconds) / Double(totalSeconds) * 100
            return TimeCategory(
                name: name,
                color: generateColor(for: name),
                duration: seconds,
                percentage: percentage
            )
        }
    }
}

// 添加新的子视图组件
private struct TimeChartView: View {
    let timeCategories: [TimeCategory]
    let totalSeconds: Int // 改为 Int 类型
    let animate: Bool
    
    var body: some View {
        ZStack {
            Chart(timeCategories) { category in
                SectorMark(
                    angle: .value("时间", category.duration),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(category.color)
            }
            .frame(height: 180)
            .chartLegend(.hidden)
            .animation(.easeInOut(duration: 1), value: animate)
            
            TotalTimeLabel(totalSeconds: totalSeconds) // 传递总秒数
        }
    }
}

private struct TotalTimeLabel: View {
    let totalSeconds: Int
    
    var body: some View {
        VStack(spacing: 4) {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            
            if hours > 0 {
                Text("\(hours)小时\(minutes)分钟")
                    .font(.system(size: 28, weight: .medium))
            } else {
                Text("\(minutes)分钟")
                    .font(.system(size: 28, weight: .medium))
            }
        }
    }
}

private struct TimeCategoryListView: View {
    let categories: [TimeCategory]
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(categories) { category in
                CategoryRow(category: category)
            }
        }
    }
}

private struct CategoryRow: View {
    let category: TimeCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(category.name)
                    .font(.system(size: 14))
                
                Spacer()
                
                Text(formatDuration(seconds: category.duration))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f%%", category.percentage))
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 60, alignment: .trailing)
            }
            
            ProgressBar(percentage: category.percentage, color: category.color)
        }
    }
    
    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

private struct ProgressBar: View {
    let percentage: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.2))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geometry.size.width * percentage / 100, height: 4)
            }
        }
        .frame(height: 4)
    }
}

// 添加Calendar扩展，实现startOfWeek方法
extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}

// 创建新的日期导航器组件 - 美化版
struct DateNavigator: View {
    let periodType: String
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    var body: some View {
        HStack(spacing: 0) {
            // 上一个时间段按钮
            Button(action: previousPeriod) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            
            Spacer()
            
            // 中间日期显示
            HStack(spacing: 6) {
                Image(systemName: dateIcon)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.primaryColor)
                
                Text(formattedDate)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
            
            Spacer()
            
            // 下一个时间段按钮
            Button(action: nextPeriod) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal)
    }
    
    // 根据时间段选择图标
    private var dateIcon: String {
        switch periodType {
        case "日": return "calendar.day.timeline.leading"
        case "周": return "calendar.badge.clock"
        case "月": return "calendar"
        default: return "calendar"
        }
    }
    
    // 格式化日期显示
    private var formattedDate: String {
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // 设置周一为一周的第一天
        calendar.minimumDaysInFirstWeek = 7  // 确保完整的周
        
        switch periodType {
        case "日":
            dateFormatter.dateFormat = "yyyy年MM月dd日"
            return dateFormatter.string(from: selectedDate)
        
        case "周":
            // 获取本周一的日期
            let weekdayComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
            guard let startOfWeek = calendar.date(from: weekdayComponents) else {
                return ""
            }
            
            // 获取本周日的日期（周一+6天）
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            
            dateFormatter.dateFormat = "MM月dd日"
            let startString = dateFormatter.string(from: startOfWeek)
            let endString = dateFormatter.string(from: endOfWeek)
            
            return "\(startString) - \(endString)"
        
        case "月":
            dateFormatter.dateFormat = "yyyy年MM月"
            return dateFormatter.string(from: selectedDate)
        
        default:
            return ""
        }
    }
    
    // 切换到上一个时间段
    private func previousPeriod() {
        withAnimation {
            switch periodType {
            case "日":
                selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate)!
            case "周":
                selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate)!
            case "月":
                selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate)!
            default:
                break
            }
        }
    }
    
    // 切换到下一个时间段
    private func nextPeriod() {
        withAnimation {
            switch periodType {
            case "日":
                selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate)!
            case "周":
                selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate)!
            case "月":
                selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate)!
            default:
                break
            }
        }
    }
}

// 1. 首先，添加一个PreferenceKey来传递视图渲染状态
struct ViewRenderCompletedKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

// 2. 创建一个视图修饰符来监听渲染
extension View {
    func onRenderCompleted(perform action: @escaping () -> Void) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ViewRenderCompletedKey.self, value: true)
                    .onPreferenceChange(ViewRenderCompletedKey.self) { value in
                        if value {
                            DispatchQueue.main.async {
                                action()
                            }
                        }
                    }
            }
        )
    }
}

// 预览
#Preview {
    let container = GoalifyAIApp.sharedModelContainer
    let testRecord = EmotionRecord(
        emotionType: "测试情绪",
        intensity: .medium,
        trigger: "测试触发因素",
        unhealthyBeliefs: "测试不合理信念",
        healthyEmotion: "测试健康情绪",
        copingStrategies: "测试应对策略"
    )
    
    return MoodTrackingView(period: "日", date: Date(), animate: false)
        .modelContainer(container)
}

// 视图标记器，用于为SwiftUI视图添加可识别的ID
struct ViewTagger: UIViewRepresentable {
    let tag: String
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.accessibilityIdentifier = tag
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.accessibilityIdentifier = tag
    }
}

extension UIView {
    var calculatedContentSize: CGSize {
        systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .defaultLow
        )
    }
}

// 修改情绪分布图
private struct MoodDistributionChart: View {
    let moodData: [(String, Double, Color)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                // 饼图
                ZStack {
                    ForEach(Array(moodData.enumerated()), id: \.offset) { index, item in
                        let startAngle = moodData[0..<index].reduce(0.0) { $0 + $1.1 } * 360
                        let endAngle = startAngle + item.1 * 360
                        
                        // 使用更现代的渐变效果
                        let gradient = LinearGradient(
                            gradient: Gradient(colors: [item.2.opacity(0.8), item.2]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // 绘制扇形
                        Path { path in
                            path.move(to: CGPoint(x: 75, y: 75))
                            path.addArc(center: CGPoint(x: 75, y: 75),
                                        radius: 75,
                                        startAngle: .degrees(startAngle),
                                        endAngle: .degrees(endAngle),
                                        clockwise: false)
                        }
                        .fill(gradient)
                        .shadow(color: item.2.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
                .frame(width: 150, height: 150)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 6)
                        .shadow(radius: 3)
                )
                
                // 百分比标签
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(moodData, id: \.0) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.2)
                                .frame(width: 12, height: 12)
                                .shadow(color: item.2.opacity(0.3), radius: 3, x: 0, y: 2)
                            
                            Text("\(item.0)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(Int(item.1 * 100))%")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding(.leading, 8)
            }
            .padding()
            .cornerRadius(16)
        }
    }
}

// 在文件底部添加新的只读情绪详情视图
struct ReviewEmotionDetailView: View {
    let emotionRecord: EmotionRecord
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 情绪概览卡片
                    emotionOverviewCard
                    
                    // 详细信息卡片
                    VStack(spacing: 16) {
                        emotionDetailCard(
                            title: "触发事件",
                            icon: "bolt.fill",
                            color: .blue,
                            content: emotionRecord.trigger
                        )
                        
                        emotionDetailCard(
                            title: "不合理信念",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            content: emotionRecord.unhealthyBeliefs
                        )
                        
                        emotionDetailCard(
                            title: "健康情绪",
                            icon: "heart.fill",
                            color: .green,
                            content: emotionRecord.healthyEmotion
                        )
                        
                        emotionDetailCard(
                            title: "应对策略",
                            icon: "lightbulb.fill",
                            color: .purple,
                            content: emotionRecord.copingStrategies
                        )
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("情绪详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // 情绪概览卡片
    private var emotionOverviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.pink, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(emotionRecord.emotionType)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text(emotionRecord.intensity.description)
                        .font(.subheadline)
                        .foregroundColor(emotionRecord.intensity.color)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
    
    // 详情卡片视图
    private func emotionDetailCard(title: String, icon: String, color: Color, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}
