import Foundation
import ActivityKit

public struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var timeRemaining: Int
        public var timeElapsed: Int
        public var isCountdown: Bool
        public var startTime: Date
        public var taskTitle: String
        public var targetDate: Date
        public var totalDuration: TimeInterval
        
        public init(timeRemaining: Int, timeElapsed: Int, isCountdown: Bool, startTime: Date, taskTitle: String, targetDate: Date, totalDuration: TimeInterval) {
            self.timeRemaining = timeRemaining
            self.timeElapsed = timeElapsed
            self.isCountdown = isCountdown
            self.startTime = startTime
            self.taskTitle = taskTitle
            self.targetDate = targetDate
            self.totalDuration = totalDuration
        }
    }
    
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
} 