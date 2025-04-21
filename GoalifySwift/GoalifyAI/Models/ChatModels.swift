import Foundation
import SwiftData

@Model
final class ChatMessage: CustomStringConvertible {
    var id: UUID
    var content: String
    var isUser: Bool
    var timestamp: Date
    var coachType: String // 存储 Coach 枚举的 rawValue
    var scene: String     // 存储 ChatScene 枚举的 rawValue
    
    init(content: String, isUser: Bool, timestamp: Date, coach: Coach, scene: ChatScene) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.coachType = coach.rawValue
        self.scene = scene.rawValue
    }
    
    // 转换为 Message 结构体
    func toMessage() -> Message {
        Message(
            content: content,
            isUser: isUser,
            timestamp: timestamp,
            coach: Coach(rawValue: coachType) ?? .logic
        )
    }
    
    var description: String {
        """
        ChatMessage:
        - ID: \(id)
        - 内容: \(content.prefix(20))...
        - 用户消息: \(isUser)
        - 时间: \(timestamp.formatted())
        - 教练类型: \(coachType)
        - 场景: \(scene)
        """
    }
}

// 删除 TaskResponse 结构体，只保留 TasksResponse
struct TasksResponse: Codable {
    let tasks: [ReminderInfo]
} 