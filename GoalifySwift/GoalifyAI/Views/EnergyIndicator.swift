import SwiftUI

struct EnergyIndicator: View {
    @Binding var energy: Int
    @State private var isAnimating = false
    @State private var showingEnergyManagement = false
    
    // 定义金属质感渐变背景
    private let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.22, green: 0.24, blue: 0.31),   // 深灰蓝色
            Color(red: 0.18, green: 0.20, blue: 0.25),   // 稍深的灰蓝色
            Color(red: 0.22, green: 0.24, blue: 0.31)    // 深灰蓝色
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 定义能量主色 - 明亮的金色
    private let energyColor = Color(red: 1, green: 0.85, blue: 0.3)
    
    // 格式化能量值显示
    private var displayEnergy: String {
        energy >= 1000 ? "999+" : "\(energy)"
    }
    
    var body: some View {
        Button(action: { showingEnergyManagement = true }) {
            HStack(spacing: 8) {
                // 能量图标
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(energyColor)
                    .symbolEffect(.bounce, options: .repeat(2), value: isAnimating)
                
                // 能量值
                Text(displayEnergy)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(energyColor)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundGradient)
                    .overlay(
                        // 添加微妙的光泽效果
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .white.opacity(0.2), location: 0),
                                        .init(color: .clear, location: 0.3),
                                        .init(color: .white.opacity(0.1), location: 1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        // 添加细边框
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            )
            // .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        }
        .sheet(isPresented: $showingEnergyManagement) {
            EnergyManagementView(energy: $energy)
        }
        .onAppear {
            isAnimating.toggle()
        }
    }
}

#Preview {
    VStack {
        EnergyIndicator(energy: .constant(80))
        EnergyIndicator(energy: .constant(999))
        EnergyIndicator(energy: .constant(1000))
        EnergyIndicator(energy: .constant(1234))
    }
    .padding()
    .background(Color.white)
} 
