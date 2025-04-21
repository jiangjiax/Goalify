import EventKit
import SwiftUI

class CalendarService: ObservableObject {
    let eventStore = EKEventStore()
    @Published var isAuthorized = false
    
    init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .authorized, .fullAccess:
            isAuthorized = true
        case .notDetermined:
            requestAccess()
        default:
            isAuthorized = false
        }
    }
    
    func requestAccess() {
        Task { @MainActor in
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                isAuthorized = granted
            } catch {
                print("日历权限请求失败: \(error)")
                isAuthorized = false
            }
        }
    }
    
    func saveEvent(title: String, startTime: Date, endTime: Date) async throws {
        guard isAuthorized else {
            throw NSError(domain: "CalendarService", code: -1, userInfo: [NSLocalizedDescriptionKey: "没有日历访问权限"])
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startTime
        event.endDate = endTime
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        try eventStore.save(event, span: .thisEvent)
    }
    
    func getFocusTimeForTask(title: String) async throws -> TimeInterval {
        guard isAuthorized else {
            throw NSError(domain: "CalendarService", code: -1, userInfo: [NSLocalizedDescriptionKey: "没有日历访问权限"])
        }
        
        let calendar = Calendar.current
        // 获取过去30天的专注记录
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
        let focusEvents = events.filter { event in
            event.title.hasPrefix("\(title)")
        }
        
        // 计算总专注时长
        return focusEvents.reduce(0) { total, event in
            total + event.endDate.timeIntervalSince(event.startDate)
        }
    }
} 