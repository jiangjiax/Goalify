import SwiftUI
import SwiftData

// 修改外观模式枚举
enum AppearanceMode: String, CaseIterable {
    case light = "浅色模式"
    case dark = "深色模式"
    case system = "跟随系统"
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "gearshape.2.fill"
        }
    }
}

extension AppearanceMode {
    func apply() {
        DispatchQueue.main.async {
            let windowScenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            
            // 优先使用活跃窗口，没有的话使用第一个窗口
            let targetScene = windowScenes.first { $0.activationState == .foregroundActive } ?? windowScenes.first
            
            guard let window = targetScene?.windows.first else {
                print("No available window found")
                return
            }
            
            switch self {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}

struct SidebarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system
    @Binding var energy: Int
    @State private var showingEnergyView = false
    @State private var showingClearChatAlert = false
    @State private var showingLogoutAlert = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var showingRedeemView = false
    @State private var redeemCode = ""
    @State private var showingRedeemError = false
    @State private var redeemErrorMessage = ""
    @State private var showingRedeemSuccess = false
    @Environment(\.modelContext) private var modelContext
    @State private var isSyncing = false
    @State private var syncError: Error?
    @State private var showingSyncError = false
    @State private var showingSyncSuccess = false
    @State private var hasUnsyncedData = false
    @State private var isCheckingSyncStatus = false
    
    private var currentAppearanceIcon: String {
        let effectiveAppearance: AppearanceMode = {
            if appearanceMode == .system {
                return colorScheme == .dark ? .dark : .light
            }
            return appearanceMode
        }()
        
        return effectiveAppearance.icon
    }
    
    var body: some View {
        NavigationView {
            List {
                // 电量信息部分
                Section {
                    HStack {
                        Label("当前电量值", systemImage: "bolt.fill")
                            .foregroundColor(AppTheme.primaryColor)
                        
                        Spacer()
                        
                        Text("\(energy)")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.orange)
                        
                        Button(action: { showingEnergyView = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(AppTheme.primaryColor)
                        }
                    }
                    
                    Button(action: { showingRedeemView = true }) {
                        Label("兑换能量码", systemImage: "giftcard.fill")
                            .foregroundColor(AppTheme.primaryColor)
                    }
                } header: {
                    Text("能量管理")
                }
                
                // 设置部分
                Section("设置") {
                    Button {
                        syncData()
                    } label: {
                        HStack {
                            Label("同步情绪记录", systemImage: "arrow.triangle.2.circlepath")
                            
                            if isCheckingSyncStatus {
                                ProgressView()
                                    .padding(.leading, 4)
                            } else if hasUnsyncedData {
                                Text("有未同步的情绪记录")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                    .disabled(isCheckingSyncStatus)
                    
                    NavigationLink {
                        AppearanceSettingsView(selectedMode: $appearanceMode)
                    } label: {
                        Label {
                            Text("外观设置")
                        } icon: {
                            Image(systemName: appearanceMode.icon)
                                .foregroundColor(AppTheme.primaryColor)
                        }
                    }
                    
                    Button(action: { showingClearChatAlert = true }) {
                        Label("清除聊天记录", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    
                    Button(action: { showingLogoutAlert = true }) {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                
                // 支持与帮助
                Section("支持") {
                    NavigationLink(destination: HelpView()) {
                        Label("帮助", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        Label("关于", systemImage: "info.circle")
                    }
                }
                
                // 应用版本信息
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("菜单")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("确认退出登录", isPresented: $showingLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) {
                    logout()
                }
            } message: {
                Text("您确定要退出当前账号吗？")
            }
        }
        .sheet(isPresented: $showingEnergyView) {
            EnergyManagementView(energy: $energy)
        }
        .alert("确认清除", isPresented: $showingClearChatAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                deleteChatMessages()
            }
        } message: {
            Text("确定要清除所有聊天记录吗？此操作不可撤销。")
        }
        .onChange(of: appearanceMode) { _, newMode in
            newMode.apply()
            print("外观模式: \(newMode.rawValue)")
        }
        .sheet(isPresented: $showingRedeemView) {
            redeemCodeView
        }
        .alert("兑换成功", isPresented: $showingRedeemSuccess) {
            Button("确定", role: .cancel) { 
                // 添加同步能量值逻辑
                Task {
                    await syncEnergy()
                }
            }
        } message: {
            Text("能量值已成功增加！")
        }
        .alert("兑换失败", isPresented: $showingRedeemError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(redeemErrorMessage)
        }
        .alert("同步失败", isPresented: $showingSyncError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(syncError?.localizedDescription ?? "未知错误")
        }
        .alert("同步成功", isPresented: $showingSyncSuccess) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("数据已成功同步")
        }
        .onAppear {
            // 确保视图出现时应用当前的外观模式
            appearanceMode.apply()
            checkSyncStatus()
        }
    }

    private var redeemCodeView: some View {
        NavigationView {
            Form {
                Section {
                    TextField("请输入兑换码", text: $redeemCode)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button(action: redeemEnergyCode) {
                        HStack {
                            Spacer()
                            Text("兑换")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(redeemCode.isEmpty)
                }
            }
            .navigationTitle("兑换能量码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showingRedeemView = false }
                }
            }
        }
    }
    
    private func redeemEnergyCode() {
        Task {
            do {
                let token = UserDefaults.standard.string(forKey: "authToken") ?? ""
                guard !token.isEmpty else {
                    redeemErrorMessage = "用户未登录"
                    showingRedeemError = true
                    return
                }
                
                let url = URL(string: "\(GlobalConstants.baseURL)/api/v1/redeem")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(token, forHTTPHeaderField: "Authorization")
                
                let requestBody = ["code": redeemCode]
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if httpResponse.statusCode == 200 {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let newEnergy = json["newEnergy"] as? Int {
                        energy = newEnergy
                        showingRedeemSuccess = true
                        showingRedeemView = false
                    }
                } else {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? String {
                        redeemErrorMessage = error
                    } else {
                        redeemErrorMessage = "兑换失败，请稍后重试"
                    }
                    showingRedeemError = true
                }
            } catch {
                redeemErrorMessage = error.localizedDescription
                showingRedeemError = true
            }
        }
    }

    private func logout() {
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "authToken")
        dismiss()
    }

    private func syncEnergy() async {
        do {
            let token = UserDefaults.standard.string(forKey: "authToken") ?? ""
            guard !token.isEmpty else { return }
            
            let url = URL(string: "\(GlobalConstants.baseURL)/api/v1/user/energy")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(token, forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newEnergy = json["energy"] as? Int {
                DispatchQueue.main.async {
                    self.energy = newEnergy
                    // 更新 SwiftData 中的用户能量值
                    if let user = try? modelContext.fetch(FetchDescriptor<User>()).first {
                        user.energy = newEnergy
                        try? modelContext.save()
                    }
                }
            }
        } catch {
            print("同步能量值失败: \(error)")
        }
    }

    // 添加删除聊天记录的方法
    private func deleteChatMessages() {
        // 获取所有聊天记录
        let descriptor = FetchDescriptor<ChatMessage>()
        if let messages = try? modelContext.fetch(descriptor) {
            // 删除所有聊天记录
            for message in messages {
                modelContext.delete(message)
            }
            
            // 保存更改
            try? modelContext.save()
            print("聊天记录已清除")
        }
    }

    private func checkSyncStatus() {
        Task {
            isCheckingSyncStatus = true
            defer { isCheckingSyncStatus = false }
            
            let context = ModelContext(GoalifyAIApp.sharedModelContainer)
            let syncService = SyncService(modelContext: context)
            hasUnsyncedData = await syncService.hasUnsyncedData()
        }
    }

    private func syncData() {
        Task {
            isSyncing = true
            defer { isSyncing = false }
            
            let context = ModelContext(GoalifyAIApp.sharedModelContainer)
            let syncService = SyncService(modelContext: context)
            
            // 获取服务器更新
            await syncService.fetchUpdates()
            
            // 同步本地更改
            await syncService.syncChanges()
            
            // 同步后重新检查状态
            hasUnsyncedData = await syncService.hasUnsyncedData()
            
            syncError = nil
            showingSyncSuccess = true
        }
    }
}

// 帮助视图
struct HelpView: View {
    var body: some View {
        List {
            // 基本功能介绍
            Section("基本功能") {
                HelpItemView(
                    title: "执行页面",
                    description: "这是您的主要工作区域，包含目标设定和情绪记录两大功能。您可以在顶部切换不同的AI类型（理性/感性）来获得不同场景的功能。",
                    icon: "play.circle.fill"
                )
                
                HelpItemView(
                    title: "目标设定",
                    description: "在执行页面选择「目标设定」场景，AI助手会帮助您制定具体、可执行的任务计划。设定的任务会自动同步到提醒事项中，方便追踪和管理。",
                    icon: "target"
                )
                
                HelpItemView(
                    title: "情绪记录",
                    description: "在执行页面选择「情绪记录」场景，可以记录和分析当下的情绪状态。AI助手会帮助您识别情绪触发因素，提供健康的应对策略。",
                    icon: "heart.fill"
                )
                
                HelpItemView(
                    title: "复盘页面",
                    description: "回顾过往的目标设定和情绪变化，帮助您更好地了解自己的成长轨迹。",
                    icon: "clock.arrow.circlepath"
                )
            }
            
            // 添加新的动态卡片说明章节
            Section("动态卡片功能") {
                HelpItemView(
                    title: "动态信息卡片",
                    description: "位于执行页面顶部的动态卡片会根据当前场景显示不同内容。您可以通过上下拖动调整卡片大小，通过左右滑动切换不同的统计维度。",
                    icon: "chart.bar.doc.horizontal"
                )
                
                HelpItemView(
                    title: "目标场景卡片",
                    description: "在目标设定场景下，卡片显示近期任务完成情况、任务分布统计等信息。可以直接点击未完成的任务快速开始专注计时。",
                    icon: "checklist"
                )
                
                HelpItemView(
                    title: "情绪场景卡片",
                    description: "在情绪记录场景下，卡片展示情绪变化趋势、情绪词云等可视化内容，帮助您更直观地了解自己的情绪状态。",
                    icon: "waveform.path.ecg"
                )
            }
            
            // 添加任务管理相关说明
            Section("任务管理") {
                HelpItemView(
                    title: "72小时任务视图",
                    description: "任务列表按照时间自动分组（今天、明天、后天等），帮助您专注于近期要做的事情。可以查看详情、编辑或删除。",
                    icon: "list.bullet.rectangle"
                )
                
                HelpItemView(
                    title: "专注计时",
                    description: "点击任务右侧的计时器图标即可开始专注。专注期间会记录时长，完成后可以查看专注历史记录。支持倒计时和正计时两种模式。",
                    icon: "timer"
                )
                
                HelpItemView(
                    title: "任务优先级",
                    description: "任务支持设置高、中、低三种优先级，系统会用不同颜色标记。建议根据任务的重要性和紧急程度合理设置优先级。",
                    icon: "flag.fill"
                )
                
                HelpItemView(
                    title: "重复任务",
                    description: "支持设置每天、每周、每月等重复规则，适合处理日常习惯养成类的任务。重复任务会在完成后自动创建下一个周期的任务。",
                    icon: "arrow.clockwise"
                )
            }
            
            // 添加情绪记录相关说明
            Section("情绪记录") {
                HelpItemView(
                    title: "情绪强度",
                    description: "记录情绪时可以设置1-10级的情绪强度，帮助您更准确地量化情绪状态。不同强度会用不同颜色直观显示。",
                    icon: "gauge.medium"
                )
                
                HelpItemView(
                    title: "情绪分析",
                    description: "AI助手会分析您的情绪记录，识别情绪触发事件、不合理信念，并给出建设性的应对策略，帮助您建立健康的情绪管理模式。",
                    icon: "brain.head.profile"
                )
                
                HelpItemView(
                    title: "情绪标签",
                    description: "系统提供丰富的情绪标签库，帮助您更准确地描述情绪。您也可以自定义添加个性化的情绪标签。",
                    icon: "tag.fill"
                )
                
                HelpItemView(
                    title: "情绪报告",
                    description: "系统会自动生成每日/每周情绪报告，包含情绪变化趋势、主要情绪类型分布、情绪触发因素分析等内容。",
                    icon: "doc.text.fill"
                )
            }
            
            // 添加数据统计说明
            Section("数据统计") {
                HelpItemView(
                    title: "专注统计",
                    description: "记录每日专注时长，生成数据图，直观展示您的专注习惯。专注数据会与日历同步。",
                    icon: "clock.fill"
                )
                
                HelpItemView(
                    title: "情绪趋势",
                    description: "展示情绪变化趋势，帮助您发现情绪规律，及时调整心理状态。",
                    icon: "chart.xyaxis.line"
                )
            }
            
            // 能量系统说明
            Section("能量系统") {
                HelpItemView(
                    title: "能量值使用",
                    description: "每次与AI助手对话都会消耗1点能量值。能量值用完后需要充能才能继续使用AI助手功能。",
                    icon: "bolt.fill"
                )
                
                HelpItemView(
                    title: "获取能量值",
                    description: "新用户注册即获得20点能量值。后续可以通过完成任务、记录情绪等方式获得能量值奖励。",
                    icon: "plus.circle.fill"
                )
                
                HelpItemView(
                    title: "能量码兑换",
                    description: "您可以通过兑换能量码获得额外能量值。能量码可以通过分享应用、参与活动等方式获得。",
                    icon: "gift.fill"
                )
            }
            
            // 数据同步和隐私
            Section("数据同步与隐私") {
                HelpItemView(
                    title: "数据同步",
                    description: "您的情绪数据会自动同步到云端，确保数据安全且可在多设备间访问。",
                    icon: "arrow.triangle.2.circlepath.circle.fill"
                )
                
                HelpItemView(
                    title: "隐私保护",
                    description: "我们严格保护您的隐私数据。所有个人信息和对话内容都经过加密处理，不会泄露给第三方。",
                    icon: "lock.fill"
                )
            }
            
            // 使用技巧
            Section("使用技巧") {
                HelpItemView(
                    title: "72小时原则",
                    description: "设定任务时，建议遵循72小时原则：如果三天内不打算开始执行的任务，建议暂时不要添加到待办事项中。",
                    icon: "clock.fill"
                )
                
                HelpItemView(
                    title: "情绪觉察",
                    description: "建议每天记录1-2次情绪状态，帮助您更好地了解自己的情绪模式，提高情绪管理能力。",
                    icon: "brain.head.profile"
                )
                
                HelpItemView(
                    title: "定期复盘",
                    description: "每周查看一次复盘报告，了解自己的目标完成情况和情绪变化趋势，及时调整行动策略。",
                    icon: "chart.bar.fill"
                )
            }
        }
        .navigationTitle("帮助中心")
    }
}

// 关于视图
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 应用图标和名称
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 64, weight: .medium))
                        .foregroundColor(AppTheme.primaryColor)
                        .padding(24)
                        .background(
                            Circle()
                                .fill(AppTheme.primaryColor.opacity(0.1))
                        )
                    
                    Text("目标达成")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("v1.0.0")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 32)
                
                // 应用简介
                VStack(alignment: .leading, spacing: 12) {
                    Text("关于应用")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("目标达成是一款基于认知科学和行为心理学的智能目标管理应用。结合前额皮质工作规律，通过AI助手辅助用户建立可持续的目标达成模式。")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .cornerRadius(12)
                
                // 作者信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("关于作者")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // 邮箱
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(AppTheme.primaryColor)
                            
                            Text("jiangjiaxingogogo@gmail.com")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        .onTapGesture {
                            if let url = URL(string: "mailto:jiangjiaxingogogo@gmail.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                        
                        // 小红书
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(AppTheme.primaryColor)
                            
                            Text("小红书：鲤哥独立开发")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        .onTapGesture {
                            // 小红书个人主页URL
                            let xhsProfileURL = URL(string: "xiaohongshu://user/profile/621120b200000000100083d8")!
                            let xhsWebURL = URL(string: "https://www.xiaohongshu.com/user/profile/621120b200000000100083d8")!
                            
                            // 尝试打开小红书App
                            if UIApplication.shared.canOpenURL(xhsProfileURL) {
                                UIApplication.shared.open(xhsProfileURL)
                            } else {
                                // 如果未安装小红书，打开网页版
                                UIApplication.shared.open(xhsWebURL)
                            }
                        }
                        
                        // 小红书号
                        HStack(spacing: 8) {
                            Image(systemName: "number.circle.fill")
                                .foregroundColor(AppTheme.primaryColor)
                            
                            Text("小红书号：4723278528")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .cornerRadius(12)
                
                Spacer()
                
                // 底部版权信息
                VStack(spacing: 8) {
                    Text("© 2025 GoalifyAI Inc.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("保留所有权利")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 帮助项目视图组件
struct HelpItemView: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.primaryColor)
                    .font(.system(size: 16))
                
                Text(title)
                    .font(.headline)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 26)
        }
        .padding(.vertical, 6)
    }
}

// 新增外观设置专用视图
struct AppearanceSettingsView: View {
    @Binding var selectedMode: AppearanceMode
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    
    var body: some View {
        List {
            Section {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Button {
                        selectedMode = mode
                        mode.apply()
                        dismiss()
                    } label: {
                        HStack {
                            Label(mode.rawValue, systemImage: mode.icon)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.primaryColor)
                            }
                        }
                    }
                }
            }
            
            Section {
                Text(selectedMode == .system ? 
                     "当前跟随系统外观（\(systemColorScheme == .dark ? "深色" : "浅色" )模式）" :
                        "当前使用\(selectedMode.rawValue)")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            // 确保视图出现时应用当前的外观模式
            selectedMode.apply()
        }
        .navigationTitle("外观设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SidebarView(energy: .constant(80))
} 