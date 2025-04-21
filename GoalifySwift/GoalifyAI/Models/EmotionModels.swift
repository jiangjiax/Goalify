import Foundation
import SwiftData

// 情绪记录数据模型
@Model
final class EmotionRecord: Identifiable, Encodable {
    @Attribute(.unique) // 添加唯一性约束
    var id: UUID
    var recordDate: Date = Date() // 提供默认值为当前时间
    var emotionType: String
    var intensity: MoodRecord.Intensity  // 直接使用枚举类型
    var trigger: String
    var unhealthyBeliefs: String
    var healthyEmotion: String
    var copingStrategies: String
    var lastModified: Date = Date() // 提供默认值为当前时间
    
    init(
        emotionType: String,
        intensity: MoodRecord.Intensity,  // 修改参数类型
        trigger: String,
        unhealthyBeliefs: String,
        healthyEmotion: String,
        copingStrategies: String,
        recordDate: Date = Date() // 提供默认值为当前时间
    ) {
        self.id = UUID()
        self.recordDate = recordDate // 使用传入的 recordDate 或默认值
        self.emotionType = emotionType
        self.intensity = intensity
        self.trigger = trigger
        self.unhealthyBeliefs = unhealthyBeliefs
        self.healthyEmotion = healthyEmotion
        self.copingStrategies = copingStrategies
        self.lastModified = Date() // 确保初始化时赋值
    }
    
    // 转换为 MoodRecord 结构体
    func toMoodRecord() -> MoodRecord {
        return MoodRecord(
            recordDate: recordDate, // 修改为 recordDate
            emotionType: emotionType,
            intensity: intensity,  // 直接使用枚举值
            trigger: trigger,
            unhealthyBeliefs: unhealthyBeliefs,
            healthyEmotion: healthyEmotion,
            copingStrategies: copingStrategies
        )
    }
    
    // 实现 Encodable 的编码方法
    enum CodingKeys: String, CodingKey {
        case id, recordDate, emotionType, intensity, trigger, unhealthyBeliefs, healthyEmotion, copingStrategies, lastModified
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(recordDate, forKey: .recordDate) // 修改为 recordDate
        try container.encode(emotionType, forKey: .emotionType)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(trigger, forKey: .trigger)
        try container.encode(unhealthyBeliefs, forKey: .unhealthyBeliefs)
        try container.encode(healthyEmotion, forKey: .healthyEmotion)
        try container.encode(copingStrategies, forKey: .copingStrategies)
        try container.encode(lastModified, forKey: .lastModified)
    }
}

// 情绪响应结构体
struct EmotionResponse: Codable {
    let emotionRecord: EmotionRecordDTO
    
    enum CodingKeys: String, CodingKey {
        case emotionRecord = "emotion_record"
    }
}

// 情绪记录DTO
struct EmotionRecordDTO: Codable {
    let emotionType: String
    let intensity: MoodRecord.Intensity
    let trigger: String
    let unhealthyBeliefs: String
    let healthyEmotion: String
    let copingStrategies: String
    
    // 转换为 EmotionRecord 实体
    func toEmotionRecord() -> EmotionRecord {
        return EmotionRecord(
            emotionType: emotionType,
            intensity: intensity,  // 直接传递枚举值
            trigger: trigger,
            unhealthyBeliefs: unhealthyBeliefs,
            healthyEmotion: healthyEmotion,
            copingStrategies: copingStrategies
        )
    }
} 