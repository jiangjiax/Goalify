import SwiftUI
import EventKit

struct ViewHelpers {
    // 将秒数转换为时间字符串
    static func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // 解析日期字符串
    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // 使用UTC时区
        print("正在解析日期: \(dateString)")
        return formatter.date(from: dateString)
    }
    
    // 获取任务优先级
    static func getDifficultyValue(from difficulty: String) -> Int {
        switch difficulty {
        case "hard": return 1
        case "medium": return 2
        case "easy": return 3
        case "tiny": return 4
        default: return 1
        }
    }
    
    // 捕获视图高度
    static func captureContentHeight(in binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry in
            Color.clear.preference(
                key: ContentHeightKey.self,
                value: geometry.size.height
            )
        }
        .onPreferenceChange(ContentHeightKey.self) { height in
            binding.wrappedValue = height
        }
    }
    
    // 添加获取重复频率的方法
    static func getRecurrenceFrequency(from rule: String) -> EKRecurrenceFrequency? {
        switch rule {
        case "daily":
            return .daily
        case "weekly":
            return .weekly
        case "monthly":
            return .monthly
        case "yearly":
            return .yearly
        case "none":
            return nil
        default:
            return nil
        }
    }
}

// 保留这个唯一定义
struct ContentHeightKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
} 
