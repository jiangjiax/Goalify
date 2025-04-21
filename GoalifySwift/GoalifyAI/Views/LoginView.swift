import SwiftUI
import AuthenticationServices
import Network
import SwiftData

// 在文件顶部添加本地化key
private let signInWithApple = LocalizedStringKey("signInWithApple")

struct LoginView: View {
    @State private var isAnimating = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var showElements = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var networkMonitor = NWPathMonitor()
    @State private var isNetworkAvailable = false
    @State private var hasTriggeredNetworkPermission = false
    
    // 橙色调
    private let appNameColor = Color(red: 1.0, green: 0.5, blue: 0.0)
    
    // 定义淡粉色
    private let lightPink = Color(red: 1.0, green: 0.8, blue: 0.8)
    
    @State private var error: Error?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 主题色渐变背景 - 从上到下
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppTheme.primaryColor.opacity(0.2),
                        Color(.systemBackground)
                    ]), 
                    startPoint: .top, 
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // 主内容 - 确保在一个屏幕内完成
                VStack(spacing: 0) {
                    // App名称和Logo作为标题
                    HStack(alignment: .center, spacing: 8) {
                        Text("基于认知科学与人工智能")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.primaryColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(AppTheme.primaryColor.opacity(0.2))
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, geometry.size.height * 0.05)
                    
                    // 主标题区域
                    VStack(spacing: 4) {
                        Text("让目标达成成为")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("自然而然的事")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        AppTheme.primaryColor,
                                        AppTheme.primaryColor.opacity(0.9),
                                        AppTheme.primaryColor.opacity(0.6)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .padding(.bottom, 16)
                    .padding(.top, 16)
                    .opacity(showElements ? 1 : 0)
                    .offset(y: showElements ? 0 : -10)
                    
                    // 副标题
                    Text("了解前额皮质工作原理的AI伙伴\n为您的目标提供科学护航")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                        .minimumScaleFactor(0.8)
                        .opacity(showElements ? 1 : 0)
                    
                    // 功能列表 - 修改后的功能列表
                    VStack(spacing: 12) {
                        FeatureCard(
                            icon: "arrow.triangle.branch",
                            title: "目标拆解",
                            description: "复杂目标智能分解为可执行步骤"
                        )
                        
                        FeatureCard(
                            icon: "waveform.path.ecg",
                            title: "情绪记录",
                            description: "实时追踪情绪波动与目标关联"
                        )
                        
                        FeatureCard(
                            icon: "chart.bar",
                            title: "智能复盘",
                            description: "AI生成多维度的进展分析报告"
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .opacity(showElements ? 1 : 0)
                    
                    Spacer()
                    
                    // 登录按钮 - 仅保留Apple登录
                    VStack(spacing: 12) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleAuthorization(result: result)
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 50)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .opacity(showElements ? 1 : 0)
                        .offset(y: showElements ? 0 : 10)
                        .environment(\.locale, Locale(identifier: "zh-Hans"))
                        .disabled(!isNetworkAvailable) // 禁用登录按钮如果网络不可用
                    }
                    
                    Text("登录即表示同意《用户协议》和《隐私政策》")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .onAppear {
            // 简化动画
            withAnimation(.easeOut(duration: 0.5)) {
                showElements = true
            }
            
            // 设置网络监控
            setupNetworkMonitoring()
            
            // 预先触发网络权限请求
            triggerNetworkPermissionRequest()
        }
        .alert("登录错误", isPresented: .constant(error != nil)) {
            Button("确定", role: .cancel) { 
                error = nil
                // 如果是网络错误，尝试再次触发网络权限
                if !isNetworkAvailable {
                    triggerNetworkPermissionRequest()
                }
            }
        } message: {
            Text(error?.localizedDescription ?? "未知错误")
        }
    }
    
    // 设置网络监控
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isNetworkAvailable = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    // 预先触发网络权限请求
    private func triggerNetworkPermissionRequest() {
        if !hasTriggeredNetworkPermission {
            // 发送一个简单的网络请求以触发系统权限弹窗
            let url = URL(string: "https://www.apple.com")!
            let task = URLSession.shared.dataTask(with: url) { _, _, _ in
                DispatchQueue.main.async {
                    self.hasTriggeredNetworkPermission = true
                }
            }
            task.resume()
        }
    }
    
    private func handleAuthorization(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            guard let credential = authResults.credential as? ASAuthorizationAppleIDCredential else {
                error = NSError(domain: "AppleLogin", code: 400, userInfo: [NSLocalizedDescriptionKey: "无法获取有效凭证"])
                return
            }
            
            // 获取身份令牌
            guard let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                error = NSError(domain: "AppleLogin", code: 400, userInfo: [NSLocalizedDescriptionKey: "无法获取身份令牌"])
                return
            }
            
            // 检查网络状态
            if !isNetworkAvailable {
                error = NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "似乎已断开与互联网的连接"])
                return
            }
            
            // 调用后端登录接口
            Task {
                do {
                    // 添加重试机制
                    var retryCount = 0
                    let maxRetries = 2
                    
                    while retryCount <= maxRetries {
                        do {
                            let success = try await sendAppleTokenToServer(
                                token: tokenString,
                                email: credential.email,
                                userIdentifier: credential.user,
                                fullName: credential.fullName
                            )
                            if success {
                                // 登录成功后直接设置登录状态，数据同步移至 ContentView
                                DispatchQueue.main.async {
                                    self.isLoggedIn = true
                                }
                                return
                            }
                        } catch {
                            if retryCount == maxRetries {
                                self.error = error
                            } else {
                                try await Task.sleep(nanoseconds: 1_000_000_000)
                            }
                        }
                        retryCount += 1
                    }
                } catch {
                    self.error = error
                }
            }
            
        case .failure(let error):
            print("Apple登录失败: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    private func sendAppleTokenToServer(token: String, email: String?, userIdentifier: String, fullName: PersonNameComponents?) async throws -> Bool {
        guard let url = URL(string: "\(GlobalConstants.baseURL)/api/v1/auth/apple") else {
            throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的服务器地址"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 设置超时时间
        request.timeoutInterval = 15
        
        // 构建请求体，包含更多用户信息
        var body: [String: Any] = [
            "identity_token": token,
            "user_identifier": userIdentifier,
            "email": email ?? ""
        ]
        
        // 添加用户名信息（如果有）
        if let givenName = fullName?.givenName {
            body["given_name"] = givenName
        }
        if let familyName = fullName?.familyName {
            body["family_name"] = familyName
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "服务器返回错误"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["token"] as? String {
            // 存储 Token
            UserDefaults.standard.set(token, forKey: "authToken")
            return true
        }
        
        return false
    }
}

// 新增功能卡片组件
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppTheme.primaryColor)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.primaryColor.opacity(0.1))
                )
            
            // 文字内容
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(12)
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
} 