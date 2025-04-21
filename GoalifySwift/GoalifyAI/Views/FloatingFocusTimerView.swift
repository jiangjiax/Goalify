import SwiftUI

struct FloatingFocusTimerView: View {
    @StateObject private var focusManager = FocusStateManager.shared
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var position = CGPoint(
        x: 100,  // 左侧距离
        y: UIScreen.main.bounds.height - 220 // 底部距离
    )
    
    var body: some View {
        ZStack {
            if focusManager.shouldShowFloatingTimer {
                Button(action: {
                    if let reminderId = focusManager.reminderId {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenFocusTimer"),
                            object: reminderId
                        )
                    }
                }) {
                    HStack(spacing: 6) {  // 减小间距
                        // 计时器图标
                        Image(systemName: "timer")
                            .font(.system(size: 12, weight: .medium))  // 减小图标大小
                            .foregroundColor(.white)
                        
                        // 时间显示
                        Text(focusManager.formattedTime())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))  // 减小字体大小
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)  // 减小水平内边距
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppTheme.primaryColor,
                                        AppTheme.primaryColor.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(
                                color: AppTheme.primaryColor.opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                    .opacity(focusManager.isTimerActive ? 1 : 0.8)
                    .scaleEffect(focusManager.isTimerActive ? 1 : 0.98)
                    .animation(
                        focusManager.isTimerActive ?
                            .easeInOut(duration: 1).repeatForever(autoreverses: true) :
                            .default,
                        value: focusManager.isTimerActive
                    )
                }
                .position(x: position.x + dragOffset.width, y: position.y + dragOffset.height)
                .simultaneousGesture(  // 使用 simultaneousGesture 提高响应速度
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            isDragging = false
                            position.x += value.translation.width
                            position.y += value.translation.height
                            dragOffset = .zero
                            
                            // 确保不超出屏幕边界
                            let screenSize = UIScreen.main.bounds.size
                            position.x = min(max(40, position.x), screenSize.width - 40)
                            position.y = min(max(40, position.y), screenSize.height - 40)
                        }
                )
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isDragging)  // 优化动画参数
            }
        }
        .ignoresSafeArea()
    }
}

struct FloatingFocusTimerView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3).ignoresSafeArea()
            FloatingFocusTimerView()
        }
        .onAppear {
            // 预览时模拟激活计时器
            let manager = FocusStateManager.shared
            manager.startFocusSession(
                title: "完成项目报告",
                timeMode: .countdown,
                duration: 25 * 60,
                reminderId: nil
            )
        }
    }
} 