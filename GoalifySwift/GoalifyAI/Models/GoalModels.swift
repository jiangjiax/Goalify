import Foundation
import SwiftData

// 任务模型
@Model
final class TodoTask: Identifiable, Encodable {
    @Attribute(.unique)
    var id: UUID
    var title: String
    var isCompleted: Bool
    var deadline: Date?       // 截止时间
    var plannedDate: Date     // 开始时间 - 改为非可选值
    var difficulty: Int        // 任务难度 1-4 (困难->轻松)
    var notes: String        // 备注
    var lastModified: Date = Date() // 新增字段，记录最后修改时间，提供默认值为当前时间
    
    // 实现 Encodable 的编码方法
    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, deadline, plannedDate, difficulty, notes, lastModified, subtasks, quadrant, repeatType
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(deadline, forKey: .deadline)
        try container.encode(plannedDate, forKey: .plannedDate)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(notes, forKey: .notes)
        try container.encode(lastModified, forKey: .lastModified)
    }
    
    init(
        title: String,
        isCompleted: Bool = false,
        deadline: Date? = nil,
        plannedDate: Date = Date(),
        difficulty: Int = 2,
        notes: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
        self.deadline = deadline
        self.plannedDate = plannedDate
        self.difficulty = difficulty
        self.notes = notes
        self.lastModified = Date() // 初始化时设置为当前时间
    }
}
