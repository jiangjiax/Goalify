import SwiftUI

// 复盘界面主题
struct ReviewTheme {
    // 使用应用主题色
    static let mainGradient = AppTheme.mainGradient
    
    // 扁平化颜色
    static let backgroundColor = Color(.systemBackground)
    static let cardBackground = Color(.systemGray6)
    static let secondaryText = Color(.systemGray)
    
    // 统一的圆角值
    static let cornerRadius: CGFloat = 16
    
    // 卡片阴影（如果需要的话）
    static let cardShadow = Color.black.opacity(0.05)
} 