import SwiftUI
import Speech
import SwiftData

struct Message: Identifiable, Equatable {
    let id = UUID()  // 自动生成唯一 ID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let coach: Coach  // 新增属性，记录消息发送时的教练
    
    // 实现 Equatable 协议
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

// 修改 Coach 枚举定义
enum Coach: String, CaseIterable {
    case logic = "理性"
    case orange = "感性"
    
    var color: Color {
        switch self {
        case .logic: return .blue
        case .orange: return .orange
        }
    }
}

// 修改 ChatScene 枚举定义
enum ChatScene: String, Identifiable {
    case goal = "目标设定"
    case emotion = "情绪记录"
    
    var id: String { rawValue }
    
    // 修改输入提示
    var inputPrompt: (title: String, description: String) {
        switch self {
        case .goal:
            return (
                title: "设定你的目标",
                description: "请输入你的目标（示例：我想在3个月内掌握SwiftUI）"
            )
        case .emotion:
            return (
                title: "分享你的心情",
                description: "分享此刻的心情（示例：今天项目进展顺利，感觉充满动力）"
            )
        }
    }
    
    // 修改推荐教练
    var recommendedCoach: Coach {
        switch self {
        case .goal: return .logic     // 目标场景推荐理性型教练
        case .emotion: return .orange // 情绪场景推荐感性型教练
        }
    }
}

// 在视图顶部添加这个类来管理录音状态
class AudioRecorderManager: ObservableObject {
    @Published var newMessage = ""
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    func startRecording(speechRecognizer: SFSpeechRecognizer) {
        // 确保先停止任何现有的录音
        stopRecording()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            
            let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest = recognitionRequest
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.newMessage = transcription
                        // 发送通知，让其他组件知道文本已更新
                        NotificationCenter.default.post(
                            name: Notification.Name("SpeechRecognitionUpdated"),
                            object: transcription
                        )
                    }
                }
                
                // 如果是最终结果或有错误，结束任务
                if result?.isFinal == true || error != nil {
                    self.stopRecording()
                }
            }
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            recognitionRequest.shouldReportPartialResults = true
            
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("启动录音失败: \(error)")
        }
    }
    
    func stopRecording() {
        // 只有当录音引擎正在运行时才停止
        if audioEngine.isRunning {
            // 添加一个短暂延迟，确保捕获最后的语音片段
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                
                // 结束音频请求
                self.recognitionRequest?.endAudio()
                
                // 延迟发送录音结束通知，给识别器更多时间处理
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // 发送录音结束通知
                    NotificationCenter.default.post(
                        name: Notification.Name("SpeechRecognitionFinished"),
                        object: self.newMessage
                    )
                    
                    // 清理资源
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    
                    // 关闭录音会话
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
            }
        } else {
            // 如果录音引擎没有运行，直接发送通知
            NotificationCenter.default.post(
                name: Notification.Name("SpeechRecognitionFinished"),
                object: newMessage
            )
        }
    }
    
    deinit {
        stopRecording()
    }
}

// 修改 StreamingChatService 类
class StreamingChatService: NSObject, URLSessionDataDelegate, ObservableObject {
    @Published var responseText = ""
    @Published var detectedTasksInfo: TasksResponse? // 只保留多任务响应
    @Published var detectedEmotionInfo: EmotionResponse?
    private var dataTask: URLSessionDataTask?
    private var session: URLSession!
    private var jsonBuffer = ""
    @Published var isCompleted = false
    private var currentScene: ChatScene? // 添加场景属性
    
    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }
    
    func sendMessage(message: String, scene: String, coachType: String, token: String, baseURL: String, completion: @escaping (Error?) -> Void) {
        // 设置当前场景
        self.currentScene = scene == "goal" ? .goal : .emotion
        
        // 重置状态
        responseText = ""
        jsonBuffer = ""
        detectedTasksInfo = nil
        detectedEmotionInfo = nil
        
        // 准备请求数据
        let requestData: [String: Any] = [
            "message": message,
            "scene": scene,
            "coach_type": coachType
        ]
        
        // 创建请求
        guard let url = URL(string: "\(baseURL)/api/v1/chat") else {
            completion(NSError(domain: "InvalidURL", code: 0, userInfo: nil))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        
        // 转换请求数据为JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestData) else {
            completion(NSError(domain: "JSONSerializationError", code: 0, userInfo: nil))
            return
        }
        request.httpBody = jsonData
        
        // 重置响应文本
        responseText = ""
        
        // 创建数据任务
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
    }
    
    func cancelRequest() {
        dataTask?.cancel()
        dataTask = nil
    }
    
    // 修改数据接收方法
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let chunk = String(data: data, encoding: .utf8) {
            jsonBuffer += chunk
            
            if let jsonStartRange = jsonBuffer.range(of: "[[JSON_START]]"),
               let jsonEndRange = jsonBuffer.range(of: "[[JSON_END]]") {
                
                let jsonContent = String(jsonBuffer[jsonStartRange.upperBound..<jsonEndRange.lowerBound])
                jsonBuffer = String(jsonBuffer[jsonEndRange.upperBound...])
                
                if let jsonData = jsonContent.data(using: .utf8) {
                    if currentScene == .goal {
                        do {
                            let tasksInfo = try JSONDecoder().decode(TasksResponse.self, from: jsonData)
                            print("解析到的任务信息: \(tasksInfo)")
                            DispatchQueue.main.async {
                                self.detectedTasksInfo = tasksInfo
                            }
                        } catch {
                            print("任务JSON解析错误: \(error)")
                        }
                    } else if currentScene == .emotion {
                        do {
                            let emotionInfo = try JSONDecoder().decode(EmotionResponse.self, from: jsonData)
                            print("解析到的情绪信息: \(emotionInfo)")
                            DispatchQueue.main.async {
                                self.detectedEmotionInfo = emotionInfo
                            }
                        } catch {
                            print("情绪JSON解析错误: \(error)")
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.responseText += chunk
                self.objectWillChange.send()
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Stream error: \(error.localizedDescription)")
        } else {
            print("Stream completed successfully")
            // 强制更新最后一次响应文本
            DispatchQueue.main.async {
                self.isCompleted = true
            }
        }
    }
    
    // 修改 updateAIMessage 方法
    func updateAIMessage(currentMessages: inout [Message], currentScene: ChatScene) {
        // 只有当消息属于当前场景时才更新
        if self.currentScene == currentScene,
           let index = currentMessages.lastIndex(where: { !$0.isUser }) {
            let finalContent = responseText
            
            currentMessages[index] = Message(
                content: finalContent,
                isUser: false,
                timestamp: currentMessages[index].timestamp,
                coach: currentMessages[index].coach
            )
        }
    }
}

struct ExecutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 计算属性获取当前用户
    private var currentUser: User? {
        users.first
    }
    
    @State private var messages: [ChatScene: [Message]] = [
        .goal: [],
        .emotion: []
    ]
    @StateObject private var audioRecorder = AudioRecorderManager() // 管理语音录音和识别
    @State private var newMessage = "" // 当前输入框中的消息内容
    @State private var scrollProxy: ScrollViewProxy? = nil // 用于控制消息列表的滚动
    @State private var currentCoach: Coach = .logic // 当前选择的教练类型
    @State private var currentScene: ChatScene = .goal // 当前聊天场景（目标/情绪）
    @State private var showingCoachPicker = false // 是否显示教练选择器
    @State private var keyboardHeight: CGFloat = 0 // 键盘高度，用于调整布局
    @FocusState private var isInputActive: Bool // 输入框是否处于焦点状态
    @State private var isRecording = false // 是否正在录音
    @State private var showPermissionAlert = false // 是否显示权限请求弹窗
    @State private var showVoiceOverlay = false // 是否显示语音输入覆盖层
    @State private var temporaryMessage = "" // 临时存储语音识别结果
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-Hans"))! // 语音识别器
    @State private var currentDataTask: URLSessionDataTask? // 当前网络请求任务
    @State private var responseBuffer = "" // 存储流式响应的缓冲区
    @StateObject private var chatService = StreamingChatService() // 聊天服务
    @State private var isStreaming = false // 是否正在流式接收响应
    @State private var showingEmotionDetails = false // 是否显示情绪详情视图
    @State private var lastScrollOffset: CGFloat = 0 // 上次滚动偏移量
    @State private var contentHeight: CGFloat = 0 // 内容高度
    @State private var geometryProxy: GeometryProxy? // 用于获取布局信息
    @State private var shouldAutoScroll = true // 是否应该自动滚动到底部
    @State private var showingTasksConfirm = false // 新增多任务确认页面的状态
    @State private var showingEnergyManagement = false // 添加能量管理页面的状态变量
    
    // 分页状态
    @State private var currentMessages: [Message] = []
    @State private var pageSize = 20
    @State private var currentPage = 0
    @State private var isLoadingMore = false
    @State private var hasMoreMessages = true // 新增是否有更多数据的标志
    @State private var isFirstAppear = true
    
    @StateObject private var reminderService = ReminderService()
    
    init() {
        _currentScene = State(initialValue: .goal)
        _currentCoach = State(initialValue: currentScene.recommendedCoach)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topSection
                middleSection
            }
            .offset(y: -keyboardHeight) // 将整个内容区域上移
            .animation(.easeOut(duration: 0.2), value: keyboardHeight)
            
            bottomSection
        }
        .onTapGesture {
            // 关闭键盘
            isInputActive = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .sheet(isPresented: $showingCoachPicker) {
            CoachPickerView(selectedCoach: $currentCoach)
        }
        .sheet(isPresented: $showingEmotionDetails) {
            if let emotionResponse = chatService.detectedEmotionInfo {
                EmotionDetailView(emotionRecord: emotionResponse.emotionRecord.toEmotionRecord())
            } else {
                VStack {
                    Text("无法加载情绪信息")
                        .font(.headline)
                    Text("请稍后重试或重新生成情绪")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingEnergyManagement) {
            if let user = currentUser {
                EnergyManagementView(energy: .constant(user.energy))
            }
        }
        .sheet(isPresented: $showingTasksConfirm) {
            if let tasksInfo = chatService.detectedTasksInfo {
                TasksConfirmView(
                    reminderService: reminderService,
                    tasks: tasksInfo.tasks
                )
            }
        }
        // 添加键盘监听
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { notification in
                guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                
                // 获取安全区域的底部高度
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                let safeAreaBottom = windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
                
                // 从键盘高度中减去安全区域的高度
                keyboardHeight = keyboardFrame.height - safeAreaBottom
            }
            
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                keyboardHeight = 0
            }
            
            // 添加语音识别更新通知监听
            NotificationCenter.default.addObserver(
                forName: Notification.Name("SpeechRecognitionUpdated"),
                object: nil,
                queue: .main
            ) { notification in
                if let recognizedText = notification.object as? String {
                    let limitedText = String(recognizedText.prefix(100))
                    self.temporaryMessage = limitedText
                    self.audioRecorder.newMessage = limitedText
                }
            }
            
            // 添加语音识别完成通知监听
            NotificationCenter.default.addObserver(
                forName: Notification.Name("SpeechRecognitionFinished"),
                object: nil,
                queue: .main
            ) { notification in
                if let finalText = notification.object as? String, !finalText.isEmpty {
                    // 确保识别结果被设置到输入框
                    DispatchQueue.main.async {
                        self.audioRecorder.newMessage = finalText
                    }
                }
            }
        }
        .alert("需要语音权限", isPresented: $showPermissionAlert) {
            Button("设置") {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsURL)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在系统设置中启用语音识别权限")
        }
        .onReceive(chatService.$responseText) { _ in
            updateAIMessage() // 流式响应更新时，更新AI消息
        }
        .onReceive(chatService.$detectedTasksInfo) { taskInfo in
            if taskInfo != nil {
                showingTasksConfirm = true // 改为显示确认页面
            }
        }
        .onReceive(chatService.$detectedEmotionInfo) { emotionInfo in
            if emotionInfo != nil {
                showingEmotionDetails = true
            }
        }
        .onReceive(chatService.$isCompleted) { completed in
            if completed {
                print("=== 流式响应完成 ===")
                updateAIMessage()
                chatService.isCompleted = false
                isStreaming = false  // 重置流式状态
                
                // 保存最终AI消息
                if let lastAIMessage = currentMessages.last(where: { !$0.isUser }) {
                    let aiChatMessage = ChatMessage(
                        content: lastAIMessage.content,
                        isUser: false,
                        timestamp: lastAIMessage.timestamp,
                        coach: currentCoach,
                        scene: currentScene
                    )
                    modelContext.insert(aiChatMessage)
                    
                    do {
                        try modelContext.save()
                        print("AI消息保存成功")
                    } catch {
                        print("保存AI消息失败: \(error.localizedDescription)")
                    }
                }
                
                // 确保滚动到底部
                if let proxy = scrollProxy {
                    scrollToBottom(proxy: proxy, animated: true)
                }
            }
        }
        .onChange(of: keyboardHeight) { _, newValue in
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardHeight = newValue
            }
        }
        .onChange(of: currentScene) { _, _ in
            // 如果正在流式输出，取消当前请求
            if isStreaming {
                chatService.cancelRequest()
                isStreaming = false
            }
            
            // 重置分页并重新加载
            resetPagination()
        }
    }
    
    private var topSection: some View {
        VStack(spacing: 0) {
            // 新增动态卡片
            DynamicContentCardView(currentScene: $currentScene)
                .padding(.vertical, 6)
            
            // 消息列表区域
            messageList
        }
    }
    
    private var middleSection: some View {
        VStack(spacing: 0) {
            // 场景选择栏
            CapsuleSegmentPicker(
                items: [ChatScene.goal, .emotion],
                itemWidth: nil,
                selection: $currentScene,
                itemTitle: { $0.rawValue },
                color: AppTheme.primaryColor
            )
            .onChange(of: currentScene) { oldValue, newValue in
                withAnimation {
                    currentCoach = newValue.recommendedCoach
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 30)
            
            // 改回多行输入框，按钮放在右侧
            HStack(alignment: .bottom, spacing: 12) {
                // 输入框区域
                ZStack(alignment: .topLeading) {
                    if audioRecorder.newMessage.isEmpty {
                        Text(currentScene.inputPrompt.description)
                            .foregroundColor(Color(.placeholderText))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }
                    
                    TextEditor(text: $audioRecorder.newMessage)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .frame(minHeight: 40, maxHeight: 90)
                        .focused($isInputActive)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .onChange(of: audioRecorder.newMessage) { oldValue, newValue in
                            if newValue.count > 100 {
                                audioRecorder.newMessage = String(newValue.prefix(100))
                            }
                        }
                }
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputActive = true
                }
                .overlay(
                    // 添加字数统计
                    Text("\(audioRecorder.newMessage.count)/100")
                        .font(.caption)
                        .foregroundColor(audioRecorder.newMessage.count >= 100 ? .red : .secondary)
                        .padding(.trailing, 8)
                        .padding(.bottom, 4)
                    , alignment: .bottomTrailing
                )
                
                // 右侧按钮列
                VStack(spacing: 12) {
                    // 语音按钮
                    Button(action: toggleRecording) {
                        Image(systemName: isRecording ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(isRecording ? .red : AppTheme.primaryColor)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray6).opacity(0.7))
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .disabled(isStreaming) // 在流式输出时禁用语音按钮

                    // 发送按钮
                    Button(action: sendMessage) {
                        if isStreaming {
                            // 显示加载动画
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryColor))
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(audioRecorder.newMessage.isEmpty ? Color(.systemGray3) : AppTheme.primaryColor)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .disabled(audioRecorder.newMessage.isEmpty || isStreaming) // 在流式输出或消息为空时禁用发送按钮
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }
    
    private var bottomSection: some View {
        ZStack {
            // 添加键盘偏移和动画
            Color.clear
                .onChange(of: keyboardHeight) { _, newValue in
                    withAnimation(.easeOut(duration: 0.2)) {
                        keyboardHeight = newValue
                    }
                }
            
            // 添加回语音识别覆盖层
            if showVoiceOverlay {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // 点击任意位置结束录音
                        if isRecording {
                            audioRecorder.stopRecording()
                            showVoiceOverlay = false
                            isRecording = false
                        }
                    }
                
                VStack {
                    Spacer()
                    
                    // 语音输入面板
                    VStack(spacing: 20) {
                        WaveformView(isRecording: $isRecording)
                        
                        Text(temporaryMessage.isEmpty ? "准备记录...请开始说话" : temporaryMessage)
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppTheme.primaryColor, Color.blue]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(15)
                            .shadow(radius: 10)
                        
                        Text("点击任意位置结束")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 40)
                    .transition(.move(edge: .bottom))
                    
                    Spacer()
                }
                .animation(.spring(), value: showVoiceOverlay)
            }
        }
    }
    
    private var filteredMessages: [ChatMessage] {
        let sceneFilter = currentScene.rawValue
        
        var descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { message in
                message.scene == sceneFilter
            }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        descriptor.fetchOffset = currentPage * pageSize
        descriptor.fetchLimit = pageSize
        
        do {
            currentPage += 1
            isLoadingMore = false
            return try modelContext.fetch(descriptor).reversed()
        } catch {
            print("分页查询失败: \(error)")
            return []
        }
    }
    
    private func sendMessage() {
        Task {
            do {
                // 获取当前用户
                guard let user = currentUser else {
                    showAlert = true
                    alertMessage = "未找到当前用户"
                    return
                }
                
                // 检查能量值
                if user.energy < 1 {
                    showingEnergyManagement = true
                    return
                }
                
                // 保留原有发送消息逻辑
                let finalMessage = audioRecorder.newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !finalMessage.isEmpty else { return }
                
                // 创建并保存用户消息
                let userChatMessage = ChatMessage(
                    content: finalMessage,
                    isUser: true,
                    timestamp: Date(),
                    coach: currentCoach,
                    scene: currentScene
                )
                modelContext.insert(userChatMessage)
                
                // 更新当前显示的消息
                currentMessages.append(userChatMessage.toMessage())
                
                // 保存更改
                do {
                    try modelContext.save()
                    print("用户消息保存成功")
                } catch {
                    print("保存消息失败: \(error.localizedDescription)")
                }
                
                // 扣除能量值
                user.energy -= 1
                try modelContext.save()
                
                // 滚动到底部
                if let proxy = scrollProxy {
                    scrollToBottom(proxy: proxy, animated: true)
                }
                
                // 清空输入框
                audioRecorder.newMessage = ""
                temporaryMessage = ""
                isInputActive = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                // 开始流式请求
                isStreaming = true
                
                // 获取token
                let token = UserDefaults.standard.string(forKey: "authToken") ?? ""
                
                // 创建临时AI消息时使用空内容
                let tempAIMessage = Message(
                    content: "[正在生成回复...]", // 初始占位内容
                    isUser: false,
                    timestamp: Date(),
                    coach: currentCoach
                )
                currentMessages.append(tempAIMessage)
                
                // 发送请求
                chatService.sendMessage(
                    message: finalMessage,
                    scene: currentScene.rawValue == "目标设定" ? "goal" : "emotion",
                    coachType: currentCoach.rawValue == "理性" ? "logic" : "orange",
                    token: token,
                    baseURL: GlobalConstants.baseURL
                ) { error in
                    if let error = error {
                        print("Error sending message: \(error.localizedDescription)")
                    }
                    self.isStreaming = false
                    
                    // 请求完成后获取最新能量值
                    Task {
                        do {
                            let context = ModelContext(GoalifyAIApp.sharedModelContainer)
                            let newEnergy = try await SyncService(modelContext: context).fetchEnergy()
                            if let user = self.users.first {
                                user.energy = newEnergy
                                try? self.modelContext.save()
                            }
                        } catch {
                            print("同步能量值失败: \(error)")
                        }
                    }
                }
            } catch {
                print("获取能量值失败: \(error)")
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
    
    // 修改语音识别方法
    private func toggleRecording() {
        guard checkAuthorizationStatus() else { return }
        
        if isRecording {
            // 停止录音前显示正在处理的提示
            temporaryMessage = temporaryMessage.isEmpty ? "正在处理..." : temporaryMessage + " (正在处理...)"
            
            // 停止录音
            audioRecorder.stopRecording()
            
            // 延迟关闭覆盖层，给识别器更多时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showVoiceOverlay = false
                isRecording = false
            }
        } else {
            // 隐藏键盘
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            
            // 保存当前输入框内容到临时变量
            temporaryMessage = audioRecorder.newMessage
            
            // 开始录音
            audioRecorder.startRecording(speechRecognizer: speechRecognizer)
            showVoiceOverlay = true
            isRecording = true
        }
    }
    
    private func checkAuthorizationStatus() -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .notDetermined:
            requestSpeechAuthorization()
            return false
        case .denied, .restricted:
            showPermissionAlert = true
            return false
        case .authorized:
            return true
        @unknown default:
            return false
        }
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus != .authorized {
                    self.showPermissionAlert = true
                }
            }
        }
    }
    
    // 修改 updateAIMessage 方法
    private func updateAIMessage() {
        chatService.updateAIMessage(currentMessages: &currentMessages, currentScene: currentScene)
    }
    
    // 修改 messageList 视图
    private var messageList: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    // 添加用于检测滚动的 GeometryReader
                    GeometryReader { scrollProxy in
                        Color.clear.preference(
                            key: ViewOffsetKey.self,
                            value: scrollProxy.frame(in: .named("scrollView")).minY
                        )
                    }
                    .frame(height: 0) // 确保这个 GeometryReader 不占用空间
                    
                    LazyVStack(spacing: 8) {
                        // 添加下拉刷新指示器
                        if isLoadingMore {
                            ProgressView()
                                .padding()
                        }
                        
                        ForEach(currentMessages) { message in
                            MessageBubble(message: message, reminderService: reminderService)
                                .id(message.id)
                        }
                        
                        Color.clear
                            .frame(height: 20)
                            .id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(ViewOffsetKey.self) { offset in
                    // 当滚动到顶部一定距离时加载更多
                    if offset > 0 && !isLoadingMore {
                        loadMoreMessages()
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                    loadInitialMessages()
                }
            }
        }
    }
    
    // 修改 loadMoreMessages 方法
    private func loadMoreMessages() {
        guard !isLoadingMore && hasMoreMessages else { return }
        
        isLoadingMore = true
        print("=== 开始加载更多消息，当前页: \(currentPage) ===")
        
        DispatchQueue.main.async {
            let newMessages = filteredMessages
            hasMoreMessages = newMessages.count >= pageSize
            
            // 将新消息插入到列表顶部（因为新加载的是更早的消息）
            currentMessages.insert(contentsOf: newMessages.map { $0.toMessage() }, at: 0)
            print("=== 加载完成，新消息数: \(newMessages.count) ===")
        }
    }
    
    // 修改 loadInitialMessages 方法
    private func loadInitialMessages() {
        currentPage = 0
        hasMoreMessages = true
        // 直接使用 filteredMessages，它已经处理了顺序
        let messages = filteredMessages.map { $0.toMessage() }
        currentMessages = messages
        
        // 滚动到底部显示最新消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let proxy = scrollProxy {
                scrollToBottom(proxy: proxy, animated: false)
            }
        }
    }
    
    private func resetPagination() {
        currentPage = 0
        currentMessages = []
        isLoadingMore = false
        loadInitialMessages()
    }
    
    // 添加验证函数
    private func isValidTaskInfo(_ info: ReminderInfo) -> Bool {
        // 加强验证逻辑
        guard !info.title.isEmpty else { 
            print("任务标题为空")
            return false 
        }
        
        // 验证日期格式（如果有）
        if let dueDate = info.dueDate {
            guard let _ = ViewHelpers.parseDate(dueDate) else {
                print("截止日期格式无效")
                return false
            }
        }
        
        if info.hasAlarm, let alarmDate = info.alarmDate {
            guard let _ = ViewHelpers.parseDate(alarmDate) else {
                print("提醒时间格式无效")
                return false
            }
        }
        
        // 验证优先级范围
        guard [0, 1, 5, 9].contains(info.priority) else {
            print("优先级无效")
            return false
        }
        
        // 验证重复规则
        let validRules = ["none", "daily", "weekly", "monthly", "yearly"]
        guard validRules.contains(info.recurrenceRule) else {
            print("重复规则无效")
            return false
        }
        
        return true
    }
}

// 修改 MessageBubble 视图
struct MessageBubble: View {
    let message: Message
    let reminderService: ReminderService
    @State private var showingTasksConfirm = false // 改为显示确认页面
    @State private var showingEmotionDetails = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // 消息内容
                let (displayContent, tasksInfo, emotionInfo) = processMessageContent(message.content)
                
                // 使用 TypingIndicator 代替 ThreeDotLoadingView
                if displayContent == "" && !message.isUser {
                    TypingIndicator()
                        .padding(12)
                        .background(message.coach.color.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text(displayContent)
                        .padding(12)
                        .background(message.isUser ? AppTheme.primaryColor : message.coach.color.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // 如果有任务信息，显示任务卡片
                if let tasksInfo = tasksInfo {
                    TasksCardView(tasksInfo: tasksInfo)
                        .onTapGesture {
                            showingTasksConfirm = true // 改为显示确认页面
                        }
                }
                
                // 如果有情绪信息，显示情绪卡片
                if let emotionInfo = emotionInfo {
                    EmotionCardView(emotionInfo: emotionInfo)
                        .onTapGesture {
                            showingEmotionDetails = true
                        }
                }
                
                // 时间戳
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingTasksConfirm) { // 修改为显示确认页面
            let (_, taskInfo, _) = processMessageContent(message.content)
            if let info = taskInfo {
                TasksConfirmView(
                    reminderService: reminderService,
                    tasks: info.tasks
                )
            }
        }
        .sheet(isPresented: $showingEmotionDetails) {
            let (_, _, emotionInfo) = processMessageContent(message.content)
            if let info = emotionInfo {
                EmotionDetailView(emotionRecord: info.emotionRecord.toEmotionRecord())
            }
        }
    }
    
    // 修改 processMessageContent 方法，过滤加载中的消息
    private func processMessageContent(_ content: String) -> (String, TasksResponse?, EmotionResponse?) {
        guard content.contains("[[JSON_START]]"), content.contains("[[JSON_END]]") else {
            return (content, nil, nil)
        }
        
        if let jsonStartRange = content.range(of: "[[JSON_START]]"),
           let jsonEndRange = content.range(of: "[[JSON_END]]") {
            
            let jsonContent = String(content[jsonStartRange.upperBound..<jsonEndRange.lowerBound])
            let displayContent = String(content[..<jsonStartRange.lowerBound])
            let jsonMarkers = "[数据已生成]"
            
            if let jsonData = jsonContent.data(using: .utf8) {
                if let tasksInfo = try? JSONDecoder().decode(TasksResponse.self, from: jsonData) {
                    return (displayContent + jsonMarkers, tasksInfo, nil)
                } else if let emotionInfo = try? JSONDecoder().decode(EmotionResponse.self, from: jsonData) {
                    return (displayContent + jsonMarkers, nil, emotionInfo)
                }
            }
            
            return (displayContent + jsonMarkers, nil, nil)
        }
        
        return (content, nil, nil)
    }
}

// 修改 EmotionCardView
struct EmotionCardView: View {
    let emotionInfo: EmotionResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.pink, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(emotionInfo.emotionRecord.emotionType)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(emotionInfo.emotionRecord.trigger)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Label {
                    Text(emotionInfo.emotionRecord.intensity.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "gauge")
                        .foregroundColor(.blue)
                }
                
                if !emotionInfo.emotionRecord.healthyEmotion.isEmpty {
                    Label {
                        Text(emotionInfo.emotionRecord.healthyEmotion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "arrow.right")
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

// 情绪详情视图
struct EmotionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let emotionRecord: EmotionRecord
    @State private var isSaved = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 情绪概览卡片
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [Color.pink, Color.orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(emotionRecord.emotionType)
                                    .font(.title2.bold())
                                    .foregroundColor(.primary)
                                
                                Text(emotionRecord.intensity.description)
                                    .font(.subheadline)
                                    .foregroundColor(emotionRecord.intensity.color)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // 详细信息卡片
                    VStack(spacing: 16) {
                        emotionDetailCard(
                            title: "触发事件",
                            icon: "bolt.fill",
                            color: .blue,
                            content: emotionRecord.trigger
                        )
                        
                        emotionDetailCard(
                            title: "不合理信念",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            content: emotionRecord.unhealthyBeliefs
                        )
                        
                        emotionDetailCard(
                            title: "健康情绪",
                            icon: "heart.fill",
                            color: .green,
                            content: emotionRecord.healthyEmotion
                        )
                        
                        emotionDetailCard(
                            title: "应对策略",
                            icon: "lightbulb.fill",
                            color: .purple,
                            content: emotionRecord.copingStrategies
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // 添加底部提示文字
                    Text("每次点击保存将记录一次该情绪")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("情绪详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isSaved {
                        Button(action: saveEmotionRecord) {
                            Text("保存")
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.primaryColor)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("关闭")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // 详情卡片视图
    private func emotionDetailCard(title: String, icon: String, color: Color, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    private func saveEmotionRecord() {
        modelContext.insert(emotionRecord)
        do {
            try modelContext.save()
            withAnimation {
                isSaved = true
            }
            dismiss()
        } catch {
            print("保存情绪记录时出错: \(error)")
        }
    }
}

// 添加打字指示器组件
struct TypingIndicator: View {
    @State private var animating = false
    private let animation = Animation.easeInOut(duration: 0.6).repeatForever()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .scaleEffect(animating ? 1 : 0.5)
                    .animation(
                        animation.delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            withAnimation {
                animating = true
            }
        }
        .onDisappear {
            animating = false
        }
    }
}

// 添加流光效果组件
struct FlowingEffect: View {
    let color: Color
    @State private var animating = false
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0),
                            color.opacity(0.2),
                            color.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width * 0.7)
                .offset(x: animating ? width : -width)
                .animation(
                    Animation
                        .linear(duration: 2)
                        .repeatForever(autoreverses: false),
                    value: animating
                )
                .onAppear {
                    animating = true
                }
        }
    }
}

// 教练选择器视图
struct CoachPickerView: View {
    @Binding var selectedCoach: Coach
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(Coach.allCases, id: \.self) { coach in
                Button(action: {
                    selectedCoach = coach
                    dismiss()
                }) {
                    HStack {
                        Text(coach.rawValue)
                        Spacer()
                        if coach == selectedCoach {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("选择教练")
            .navigationBarItems(trailing: Button("取消") { dismiss() })
        }
    }
}

// 添加波形动画视图（在文件底部新增）
struct WaveformView: View {
    @Binding var isRecording: Bool
    @State private var animating = false
    private let animation = Animation.easeInOut(duration: 0.3).repeatForever(autoreverses: true)
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 3)
                    .frame(width: 6, height: CGFloat.random(in: 10...30))
                    .foregroundColor(.white)
                    .scaleEffect(y: animating ? 1.5 : 1, anchor: .center)
                    .animation(
                        animation.delay(Double(i) * 0.1),
                        value: animating
                    )
            }
        }
        .frame(height: 40)
        .onChange(of: isRecording) {
            if isRecording {
                withAnimation {
                    animating = true
                }
            } else {
                withAnimation {
                    animating = false
                }
            }
        }
        .opacity(isRecording ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }
}

// 添加响应模型结构体
struct ChatResponse: Codable {
    let message: String
    let scene: String
    let coach: String
}

// 添加这个结构体来跟踪滚动位置
struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

// 添加这个扩展来捕获内容高度
extension View {
    func captureContentHeight(in binding: Binding<CGFloat>) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ContentHeightKey.self,
                    value: geometry.size.height
                )
            }
        )
        .onPreferenceChange(ContentHeightKey.self) { height in
            binding.wrappedValue = height
        }
    }
}

// 新增 ReminderInfo 结构体
struct ReminderInfo: Codable {
    let title: String
    let notes: String
    let priority: Int
    let dueDate: String?  // 只保留截止时间
    let hasAlarm: Bool
    let alarmDate: String?
    let recurrenceRule: String
    let recurrenceInterval: Int
}

// 添加 TasksCardView 组件
struct TasksCardView: View {
    let tasksInfo: TasksResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                
                Text("AI 生成的任务")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(tasksInfo.tasks.count)个任务")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            // 任务列表预览
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tasksInfo.tasks.prefix(3), id: \.title) { task in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        
                        Text(task.title)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if task.priority > 0 {
                            Image(systemName: priorityIcon(for: task.priority))
                                .font(.system(size: 10))
                                .foregroundColor(priorityColor(for: task.priority))
                        }
                    }
                }
                
                if tasksInfo.tasks.count > 3 {
                    Text("还有 \(tasksInfo.tasks.count - 3) 个任务...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 4)
            
            // 点击查看提示
            HStack {
                Spacer()
                Text("点击查看详情")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    // 辅助方法：获取优先级图标
    private func priorityIcon(for priority: Int) -> String {
        switch priority {
        case 1: return "exclamationmark.3"
        case 5: return "exclamationmark.2"
        case 9: return "exclamationmark"
        default: return "circle"
        }
    }
    
    // 辅助方法：获取优先级颜色
    private func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 1: return .red
        case 5: return .orange
        case 9: return .blue
        default: return .gray
        }
    }
}

#Preview {
    ExecutionView()
} 
