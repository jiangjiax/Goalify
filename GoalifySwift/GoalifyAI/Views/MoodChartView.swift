import SwiftUI
import Charts
import SwiftData

struct MoodRecord: Identifiable {
    let id = UUID()
    let recordDate: Date
    let emotionType: String
    let intensity: Intensity
    let trigger: String
    let unhealthyBeliefs: String
    let healthyEmotion: String
    let copingStrategies: String
    
    enum Intensity: Int, Codable, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        
        var description: String {
            switch self {
            case .low: return "消极"
            case .medium: return "中性"
            case .high: return "积极"
            }
        }
        
        var color: Color {
            switch self {
            case .low: return .yellow
            case .medium: return .green
            case .high: return .red
            }
        }

        var icon: String {
            switch self {
            case .low:
                return "cloud"
            case .medium:
                return "cloud.rain"
            case .high:
                return "sun.max"
            }
        }
    }
}

struct MoodChartView: View {
    @Binding var selectedPeriod: Int
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    // 查询最新记录
    @Query(
        filter: #Predicate<EmotionRecord> { _ in true },
        sort: \EmotionRecord.recordDate,
        order: .reverse,
        animation: .default
    ) private var latestRecord: [EmotionRecord]
    
    var body: some View {
        VStack(spacing: 24) {
            if latestRecord.isEmpty {
                // 显示空状态
                EmptyStateView()
            } else {
                // 最新情绪卡片
                if let latest = latestRecord.first {
                    LatestMoodCard(record: latest)
                }
                
                // 时间段选择器
                PeriodPickerView(selectedPeriod: $selectedPeriod)
                    .padding(.horizontal, 18)
                
                // 图表卡片
                ChartCardView(counts: emotionCounts)
            }
        }
        .padding(.vertical)
    }
    
    // 计算属性：情绪统计
    private var emotionCounts: [EmotionCount] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch selectedPeriod {
        case 0: // 今天
            startDate = calendar.startOfDay(for: now)
        case 1: // 本周
            startDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        case 2: // 本月
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        default:
            startDate = .distantPast
        }
        
        // 创建查询描述符
        let descriptor = FetchDescriptor<EmotionRecord>(
            predicate: #Predicate<EmotionRecord> { record in
                record.recordDate >= startDate
            }
        )
        
        do {
            // 执行查询
            let records = try modelContext.fetch(descriptor)
            
            // 按情绪类型分组并计数
            let grouped = Dictionary(grouping: records, by: \.emotionType)
                .map { EmotionCount(emotionType: $0.key, count: $0.value.count) }
                .sorted { $0.count > $1.count }
                .prefix(5) // 只取前5个
            
            return Array(grouped)
        } catch {
            print("Error fetching emotion counts: \(error)")
            return []
        }
    }
}

// MARK: - 子视图

// 空状态视图
private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "face.smiling")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding(20)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )
            
            Text("还没有情绪记录")
                .font(.title2)
                .bold()
            
            Text("记录你的情绪可以帮助你更好地了解自己")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 最新情绪卡片
private struct LatestMoodCard: View {
    let record: EmotionRecord
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(record.intensity.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: record.intensity.icon)
                            .font(.system(size: 24))
                            .foregroundColor(record.intensity.color)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("最新情绪")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(record.emotionType)
                        .font(.title2.bold())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("强度")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(record.intensity.description)
                        .font(.title3)
                        .foregroundColor(record.intensity.color)
                }
            }
            
            Divider()
            
            Text(record.recordDate.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? 
                    Color(.systemGray6) : 
                    Color(.systemBackground))
        )
        .padding(.horizontal, 18)
    }
}

// 时间段选择器
private struct PeriodPickerView: View {
    @Binding var selectedPeriod: Int
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                Button(action: {
                    withAnimation {
                        selectedPeriod = index
                    }
                }) {
                    Text(periodTitle(for: index))
                        .font(.subheadline)
                        .foregroundColor(selectedPeriod == index ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedPeriod == index ? AppTheme.primaryColor : Color(.systemGray6))
                        )
                }
            }
        }
    }
    
    private func periodTitle(for index: Int) -> String {
        switch index {
        case 0: return "今天"
        case 1: return "本周"
        case 2: return "本月"
        default: return ""
        }
    }
}

// 图表卡片视图
private struct ChartCardView: View {
    let counts: [EmotionCount]
    @Environment(\.colorScheme) private var colorScheme
    
    // 定义颜色数组
    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .indigo
    ]
    
    // 计算最大计数值
    private var maxCount: Int {
        counts.map { $0.count }.max() ?? 10
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("情绪分布")
                    .font(.headline)
                Spacer()
            }
            
            Chart {
                ForEach(Array(counts.enumerated()), id: \.element.id) { index, count in
                    BarMark(
                        x: .value("情绪类型", count.emotionType),
                        y: .value("出现次数", count.count)
                    )
                    .foregroundStyle(colors[index % colors.count])
                    .cornerRadius(4)
                }
            }
            // 修改 y 轴范围为动态值
            .chartYScale(domain: 0...max(10, maxCount))
            .frame(height: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? 
                      Color(.systemGray6) : 
                      Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 18)
    }
}

// 情绪统计结果模型
struct EmotionCount: Identifiable {
    let id = UUID()
    let emotionType: String
    let count: Int
}

#Preview {
    MoodChartView(selectedPeriod: .constant(0))
        .modelContainer(GoalifyAIApp.sharedModelContainer)
} 
