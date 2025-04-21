//
//  GoalifyAIApp.swift
//  GoalifyAI
//
//  Created by jiangjiax on 2025/3/10.
//

import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct GoalifyAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatMessage.self,
            EmotionRecord.self,
            User.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system
    @Environment(\.colorScheme) private var systemScheme
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    var effectiveColorScheme: ColorScheme? {
        switch appearanceMode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(Self.sharedModelContainer)
                .preferredColorScheme(effectiveColorScheme)
        }
    }
}

// 添加 AppDelegate 来处理后台任务注册
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 注册后台任务
        registerBackgroundTasks()
        return true
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.li.GoalAchieve.focusTimer",
            using: nil
        ) { task in
            self.handleBackgroundTask(task)
        }
    }
    
    private func handleBackgroundTask(_ task: BGTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // 使用改进的从后台恢复方法
        FocusStateManager.shared.resumeFromBackground()
        
        task.setTaskCompleted(success: true)
        
        // 安排下一次后台任务
        scheduleBackgroundTask()
    }
    
    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.li.GoalAchieve.focusTimer")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // 1分钟后
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
}
