import SwiftUI

struct EnergyManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var energy: Int
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 能量值状态卡片
                    EnergyStatusCard(energy: $energy)
                    
                    // 获取方式说明
                    EnergyUsageGuideView()
                }
                .padding()
            }
            .navigationTitle("能量管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("了解") { dismiss() }
                }
            }
        }
    }
}

// 能量状态卡片
struct EnergyStatusCard: View {
    @Binding var energy: Int
    
    var body: some View {
        VStack(spacing: 16) {
            // 能量值显示
            VStack(spacing: 8) {
                Text("当前能量")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 1, green: 0.85, blue: 0.3))
                    
                    Text("\(energy)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppTheme.primaryColor)
                }
            }
            
            // 能量状态解释
            Text(energyStatusDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var energyStatusDescription: String {
        if energy <= 5 {
            return "能量不足，请充能以继续与AI助手交流"
        } else if energy <= 20 {
            return "能量尚可，建议及时充能"
        } else {
            return "能量充足，可以尽情使用AI助手"
        }
    }
}

// 能量使用指南视图
struct EnergyUsageGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("能量使用指南")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                EnergyUsageRow(icon: "person.crop.circle.badge.plus", title: "新用户", description: "首次使用赠送20能量值")
                EnergyUsageRow(icon: "message", title: "AI对话", description: "每次对话消耗1能量值")
                EnergyUsageRow(icon: "chart.bar", title: "AI复盘", description: "每次日复盘和周复盘消耗1能量值，月复盘消耗3能量值")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// 能量使用行
struct EnergyUsageRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppTheme.primaryColor)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}