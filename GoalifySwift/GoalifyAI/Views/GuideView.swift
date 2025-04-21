import SwiftUI

struct GuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var isLastPage = false
    
    var onComplete: () -> Void
    
    // 引导页内容
    private let pages = [
        GuidePageData(
            title: "轻松安排目标",
            description: "基于认知科学，帮助你设定清晰可执行的目标规划",
            imageName: "target"
        ),
        GuidePageData(
            title: "智能任务拆解",
            description: "AI助手帮你将大目标分解为可管理的小任务",
            imageName: "list.bullet"
        ),
        GuidePageData(
            title: "情绪与进度追踪",
            description: "记录情绪变化，发现影响目标达成的关键因素",
            imageName: "chart.line.uptrend.xyaxis"
        ),
        GuidePageData(
            title: "开始你的目标之旅",
            description: "现在就开始，让目标达成成为自然而然的事",
            imageName: "arrow.right.circle"
        )
    ]
    
    var body: some View {
        ZStack {
            // 背景色
            Color(.systemBackground).ignoresSafeArea()
            
            // 主内容
            VStack {
                // 页面指示器和跳过按钮
                HStack {
                    // 页面指示器
                    PageIndicator(currentPage: currentPage, pageCount: pages.count)
                    
                    Spacer()
                    
                    // 跳过按钮
                    Button(isLastPage ? "开始使用" : "跳过") {
                        onComplete()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // 引导页内容 - 修复滑动问题
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        GuidePage(data: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                .transition(.slide)
                // 修改后的onChange监听器
                .onChange(of: currentPage) {
                    isLastPage = currentPage == pages.count - 1
                }
                
                // 底部按钮
                Button(action: {
                    withAnimation(.easeInOut) {
                        if currentPage < pages.count - 1 {
                            currentPage += 1
                        } else {
                            onComplete()
                        }
                    }
                }) {
                    HStack {
                        Text(isLastPage ? "开始使用" : "继续")
                            .fontWeight(.semibold)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.primaryColor)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
}

// 页面指示器组件 - 修复更新问题
struct PageIndicator: View {
    let currentPage: Int
    let pageCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? AppTheme.primaryColor : Color(.systemGray4))
                    .frame(width: 8, height: 8)
                    .scaleEffect(currentPage == index ? 1.2 : 1)
                    .animation(.spring(), value: currentPage)
            }
        }
    }
}

// 单个引导页组件
struct GuidePage: View {
    let data: GuidePageData
    
    var body: some View {
        VStack(spacing: 30) {
            // 图标
            Image(systemName: data.imageName)
                .font(.system(size: 80))
                .foregroundColor(AppTheme.primaryColor)
                .padding(.bottom, 20)
            
            // 标题
            Text(data.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // 描述
            Text(data.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
        .padding(.top, 40)
    }
}

// 引导页数据模型
struct GuidePageData {
    let title: String
    let description: String
    let imageName: String
}