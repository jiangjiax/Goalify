import SwiftUI

enum AppTheme {
    static let primaryColor = Color(red: 0.2, green: 0.7, blue: 0.7) // 蓝绿色
    static let secondaryColor = Color(red: 0.0, green: 0.4, blue: 0.4) // 稍深的蓝绿色
    static let accentColor = Color(red: 1.0, green: 0.84, blue: 0.0) // 金色高光
    static let backgroundColor = Color(.systemBackground)  // 使用系统背景色
    
    // 定义渐变
    static let mainGradient = LinearGradient(
        colors: [primaryColor, secondaryColor],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 定义按钮样式
    static let buttonStyle = ButtonStyle()
    
    // 自定义按钮样式
    struct ButtonStyle: SwiftUI.ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(primaryColor)
                )
                .foregroundColor(.white)
                .overlay(
                    Capsule()
                        .stroke(accentColor, lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(.easeOut, value: configuration.isPressed)
        }
    }
}

extension View {
    func toolbarButtonStyle() -> some View {
        self
            .foregroundColor(AppTheme.primaryColor)
            .font(.headline)
    }
} 