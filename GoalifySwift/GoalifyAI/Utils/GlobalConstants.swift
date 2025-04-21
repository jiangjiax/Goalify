import Foundation

struct GlobalConstants {
    // 后端基础 URL
    static let baseURL = "https://api.goalachieveapp.com"
    // static let baseURL = "https://cde6-39-184-105-61.ngrok-free.app"
    
    // 任务选项
    static let DifficultyOptions: [(Int, String, String)] = [
        (1, "困难", "需要集中精力和时间"),
        (2, "中等", "普通难度"),
        (3, "简单", "可以轻松完成"),
        (4, "微小", "几分钟就能搞定")
    ]
} 