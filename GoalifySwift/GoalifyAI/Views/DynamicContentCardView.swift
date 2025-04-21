import SwiftUI
import SwiftData
import Charts

struct DynamicContentCardView: View {
    @Binding var currentScene: ChatScene
    @State private var height: CGFloat = 260  // 初始高度
    @State private var isDragging = false    // 新增拖动状态
    private let minHeight: CGFloat = 20      // 调整后的最小高度
    private let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.60
    @State private var selectedPeriod = 0  // 新增状态
    
    // 新增专注任务状态
    @State private var focusTask: TodoTask? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            // 渐变背景卡片 - 移除边框
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.primaryColor.opacity(0.20),
                            AppTheme.primaryColor.opacity(0.05),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            
            mainContent
        }
        .padding(.horizontal)
        .frame(height: height)  // 改为固定高度而不是最大高度
        // 修改通知处理逻辑
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StartFocusTimer"))) { notification in
            if let task = notification.object as? TodoTask {
                self.focusTask = task
                withAnimation {
                    self.currentScene = .goal  // 切换到目标设定场景
                }
            }
        }
    }
}

// MARK: - 子组件
private extension DynamicContentCardView {
    var mainContent: some View {
        VStack(spacing: 0) {
            contentSwitchArea
                .frame(maxHeight: .infinity)
            
            dragHandle
        }
    }
    
    var contentSwitchArea: some View {
        GeometryReader { geometry in
            ZStack {
                cardView(for: .goal) {
                   // 添加滚动视图以适应不同高度
                    ScrollView {
                        TodoListView()
                    }
                }
                cardView(for: .emotion) { 
                    // 添加滚动视图以适应不同高度
                    ScrollView {
                        MoodChartView(selectedPeriod: $selectedPeriod)
                    }
                }
            }
            .frame(height: geometry.size.height)
            .clipped()
        }
    }
    
    var dragHandle: some View {
        DragHandle(isDragging: $isDragging)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newHeight = height + value.translation.height
                        // 添加最小高度限制，确保卡片不会太小
                        let adjustedMinHeight = max(minHeight, 100)
                        height = min(max(newHeight, adjustedMinHeight), maxHeight)
                        isDragging = true
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        let finalHeight = height + velocity * 0.2
                        
                        // 添加智能高度调整 - 如果高度太小，自动收起到最小值
                        let adjustedMinHeight = max(minHeight, 100)
                        let targetHeight: CGFloat
                        
                        if finalHeight < adjustedMinHeight + 50 {
                            // 如果接近最小高度，则收起到最小
                            targetHeight = adjustedMinHeight
                        } else if finalHeight > maxHeight - 50 {
                            // 如果接近最大高度，则展开到最大
                            targetHeight = maxHeight
                        } else {
                            // 否则使用计算的高度
                            targetHeight = min(max(finalHeight, adjustedMinHeight), maxHeight)
                        }
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            height = targetHeight
                            isDragging = false
                        }
                        
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            )
            .padding(.bottom, 8)
            .padding(.top, 8)
    }
    
    func cardView<Content: View>(for scene: ChatScene, @ViewBuilder content: () -> Content) -> some View {
        content()
            .sceneTransitionModifier(isActive: currentScene == scene)
    }
}

// MARK: - 动画修饰符
struct SceneTransitionModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .offset(x: isActive ? 0 : (isActive ? -50 : 50))
            .scaleEffect(isActive ? 1 : 0.9)
            .animation(.easeInOut(duration: 0.3), value: isActive)
            .transaction { transaction in
                transaction.animation = .easeInOut(duration: 0.3)
            }
    }
}

// MARK: - 视图扩展
extension View {
    func sceneTransitionModifier(isActive: Bool) -> some View {
        self.modifier(SceneTransitionModifier(isActive: isActive))
    }
}

// 修改 DragHandle 组件
struct DragHandle: View {
    @Binding var isDragging: Bool
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        isDragging ? AppTheme.primaryColor : Color(.systemGray3),
                        isDragging ? AppTheme.primaryColor.opacity(0.8) : Color(.systemGray4)
                    ]), 
                    startPoint: .leading, 
                    endPoint: .trailing
                )
            )
            .frame(width: 40, height: 5)
            .cornerRadius(2.5)
            .overlay(
                RoundedRectangle(cornerRadius: 2.5)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .scaleEffect(isDragging ? 1.1 : 1)
            .animation(.easeInOut(duration: 0.2), value: isDragging)
            .onHover { hovering in
                if hovering {
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
    }
}

// 修改 TodoListRow 中的任务行样式
struct TodoListRow: View {
    let task: TodoTask
    
    var body: some View {
        HStack {
            Text(task.title)
                .foregroundColor(Color(.label)) // 使用系统标签颜色
                .padding(.vertical, 8)
            
            Spacer()
            
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? AppTheme.primaryColor : Color(.secondaryLabel))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground)) // 使用系统背景色
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
        )
    }
}

// 修改子任务样式
struct SubtaskView: View {
    let subtask: TodoTask
    
    var body: some View {
        HStack {
            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(subtask.isCompleted ? AppTheme.primaryColor : Color(.tertiaryLabel))
            
            Text(subtask.title)
                .foregroundColor(Color(.label))
                .font(.subheadline)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .background(Color(.systemBackground)) // 使用系统背景色
        .cornerRadius(8)
    }
}