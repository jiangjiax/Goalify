//
//  ContentView.swift
//  GoalifyAI
//
//  Created by jiangjiax on 2025/3/10.
//

import SwiftUI
import SwiftData
import Combine
import EventKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var selectedTab = 0
    @State private var showingSidebar = false
    @State private var syncService: SyncService?
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var syncError: Error?
    @State private var showingEnergyManagement = false
    
    // 添加跳转到专注计时器的状态
    @State private var navigateToFocusTimer = false
    @State private var focusReminderToOpen: EKReminder?
    @State private var reminderService = ReminderService()
    
    // 添加新状态
    @State private var showingTimerCompletionAlert = false
    @StateObject private var focusManager = FocusStateManager.shared
    
    let tabs = ["执行", "复盘"]

    var body: some View {
        Group {
            if isLoggedIn {
                NavigationStack {
                    ZStack {
                        VStack(spacing: 0) {
                            // 顶部控制栏
                            VStack(spacing: 0) {
                                HStack {
                                    // 左侧菜单按钮
                                    Button(action: { showingSidebar.toggle() }) {
                                        Image(systemName: "line.3.horizontal")
                                            .font(.title2)
                                            .foregroundColor(AppTheme.primaryColor)
                                    }
                                    .frame(width: 44)
                                    
                                    Spacer()
                                    
                                    // 中间标签页
                                    HStack(spacing: 0) {
                                        ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    selectedTab = index
                                                }
                                            }) {
                                                Text(tab)
                                                    .font(.system(size: 16, weight: selectedTab == index ? .semibold : .medium))
                                                    .foregroundColor(selectedTab == index ? AppTheme.primaryColor : .gray)
                                                    .frame(width: 80)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        selectedTab == index ? 
                                                        Capsule().fill(AppTheme.primaryColor.opacity(0.15)) : nil
                                                    )
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // 能量指示器
                                    if let user = users.first {
                                        EnergyIndicator(energy: .constant(user.energy))
                                            .sheet(isPresented: $showingEnergyManagement) {
                                                EnergyManagementView(energy: .constant(user.energy))
                                            }
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                            }
                            .background(Color(.systemBackground))
                            
                            Divider()
                            
                            // 内容视图
                            TabView(selection: $selectedTab) {
                                ExecutionView()
                                    .tag(0)
                                ReviewView()
                                    .tag(1)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                        }
                        .edgesIgnoringSafeArea(.bottom)
                        .sheet(isPresented: $showingSidebar) {
                            if let user = users.first {
                                SidebarView(energy: .constant(user.energy))
                            }
                        }
                        
                        // 悬浮计时器视图
                        FloatingFocusTimerView()
                        
                        // 使用背景导航链接
                        .navigationDestination(isPresented: $navigateToFocusTimer) {
                            if let reminder = focusReminderToOpen {
                                FocusTimerView(reminder: reminder, reminderService: reminderService)
                            }
                        }
                    }
                }
                .task {
                    await syncData()
                }
                .onAppear {
                    setupNotifications()
                    checkPendingTimerCompletion()
                    (UserDefaults.standard.string(forKey: "appearanceMode").flatMap { AppearanceMode(rawValue: $0) } ?? .system).apply()
                }
                .onDisappear {
                    NotificationCenter.default.removeObserver(self)
                }
            } else {
                LoginView()
            }
        }
        .alert("同步错误", isPresented: .constant(syncError != nil)) {
            Button("重试") {
                Task {
                    await syncData()
                }
            }
            Button("取消", role: .cancel) {
                syncError = nil
            }
        } message: {
            Text(syncError?.localizedDescription ?? "未知错误")
        }
        // 添加完成弹窗
        .alert("专注完成", isPresented: $showingTimerCompletionAlert) {
            Button("查看详情") {
                if let reminderId = focusManager.reminderId {
                    openFocusTimer(withId: reminderId)
                }
            }
            Button("确定", role: .cancel) {
                focusManager.pendingCompletionAlert = false
            }
        } message: {
            Text("你已完成 \(focusManager.reminderTitle) 的专注时间")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenFocusTimer"),
            object: nil,
            queue: .main
        ) { notification in
            if let reminderId = notification.object as? String {
                openFocusTimer(withId: reminderId)
            }
        }
    }
    
    private func openFocusTimer(withId reminderId: String) {
        Task { @MainActor in
            if let reminder = reminderService.getReminder(byId: reminderId) {
                focusReminderToOpen = reminder
                navigateToFocusTimer = true
            }
        }
    }
    
    private func syncData() async {
        do {
            let context = ModelContext(GoalifyAIApp.sharedModelContainer)
            let syncService = SyncService(modelContext: context)
            
            try await syncService.syncUserData()
            await syncService.fetchUpdates()
            await syncService.syncChanges()
            
            syncError = nil
        } catch {
            syncError = error
            #if DEBUG
            print("同步错误: \(error.localizedDescription)")
            #endif
        }
    }
    
    // 添加检查方法
    private func checkPendingTimerCompletion() {
        if focusManager.pendingCompletionAlert {
            showingTimerCompletionAlert = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(GoalifyAIApp.sharedModelContainer)
}
