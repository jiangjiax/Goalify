import SwiftUI

/// 胶囊形状的分段选择器
struct CapsuleSegmentPicker<T: Hashable>: View {
    let items: [T]
    let itemWidth: CGFloat? // 改为可选类型，允许自动计算宽度
    @Binding var selection: T
    let itemTitle: (T) -> String
    let color: Color
    
    // 添加一个计算属性来处理宽度
    private func calculateItemWidth(_ totalWidth: CGFloat) -> CGFloat {
        if let fixedWidth = itemWidth {
            return fixedWidth
        }
        // 减去padding(2)的宽度后平均分配
        return (totalWidth - 4) / CGFloat(items.count)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景胶囊
                Capsule()
                    .fill(Color(.systemGray6))
                
                // 选中背景
                Capsule()
                    .fill(color)
                    .frame(width: calculateItemWidth(geometry.size.width))
                    .offset(x: getOffset(totalWidth: geometry.size.width))
                    .animation(.spring(response: 0.3), value: selection)
                
                // 按钮组
                HStack(spacing: 0) {
                    ForEach(items, id: \.self) { item in
                        Button(action: { selection = item }) {
                            Text(itemTitle(item))
                                .font(.system(size: 14))
                                .frame(width: calculateItemWidth(geometry.size.width))
                                .padding(.vertical, 6)
                                .foregroundColor(selection == item ? .white : .secondary)
                        }
                    }
                }
            }
            .padding(2)
        }
    }
    
    private func getOffset(totalWidth: CGFloat) -> CGFloat {
        if let index = items.firstIndex(of: selection) {
            return CGFloat(index) * calculateItemWidth(totalWidth)
        }
        return 0
    }
}

// 预览
struct CapsuleSegmentPicker_Previews: PreviewProvider {
    // 创建一个示例枚举
    private enum PreviewTab: String, CaseIterable {
        case first = "选项1"
        case second = "选项2"
        case third = "选项3"
    }
    
    static var previews: some View {
        VStack(spacing: 20) {
            // 示例1: 简单的字符串选择器
            CapsuleSegmentPicker(
                items: ["选项1", "选项2", "选项3"],
                itemWidth: 80,
                selection: .constant("选项1"),
                itemTitle: { $0 },
                color: .blue
            )
            .frame(height: 36)
            
            // 示例2: 枚举选择器
            CapsuleSegmentPicker(
                items: PreviewTab.allCases,
                itemWidth: 70,
                selection: .constant(.first),
                itemTitle: { $0.rawValue },
                color: .orange
            )
            .frame(height: 36)
        }
        .padding()
    }
} 