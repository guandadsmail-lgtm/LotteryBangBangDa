import SwiftUI
import StoreKit // 引入 StoreKit 用于评分和恢复购买

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // 绑定 UserDefaults
    @AppStorage("isSoundOn") private var isSoundOn = true
    @AppStorage("isHapticOn") private var isHapticOn = true
    @AppStorage("hasAgreedCompliance") var hasAgreedCompliance: Bool = true // 用于重置合规弹窗测试
    
    // 获取当前版本号
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    
    var body: some View {
        NavigationView {
            ZStack {
                // 1. 全局深色背景
                Color(hex: "050505").ignoresSafeArea()
                
                List {
                    // --- 头部 Banner ---
                    Section {
                        HStack(spacing: 16) {
                            Image("AppIcon") // 如果 Assets 里没有 AppIcon 图片，这里会显示占位符或空白，建议放一张 logo 图片
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("彩票帮帮忙")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                Text("LotteryBangBangDa")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .fontDesign(.monospaced)
                            }
                        }
                        .padding(.vertical, 10)
                        .listRowBackground(Color.clear) // 透明背景
                        .listRowInsets(EdgeInsets())    // 去掉默认边距
                    }
                    
                    // --- 体验设置 ---
                    Section(header: Text("体验设置").foregroundColor(.gray)) {
                        CustomToggle(isOn: $isSoundOn, icon: "speaker.wave.2.fill", color: .blue, title: "音效")
                            .onChange(of: isSoundOn) { _, newValue in
                                if !newValue { AudioManager.shared.stopAll() }
                            }
                        
                        CustomToggle(isOn: $isHapticOn, icon: "iphone.radiowaves.left.and.right", color: .green, title: "震动反馈")
                    }
                    .listRowBackground(Color(hex: "1C1C1E")) // 卡片背景色
                    
                    // --- 会员与购买 (审核必须) ---
                    Section(header: Text("高级功能").foregroundColor(.gray)) {
                        // 恢复购买
                        Button(action: {
                            // TODO: 对接 StoreKit 恢复购买逻辑
                            restorePurchase()
                        }) {
                            SettingsRow(icon: "arrow.clockwise", color: .orange, title: "恢复购买记录")
                        }
                        
                        // 重新查看合规声明 (测试用)
                        Button(action: {
                            hasAgreedCompliance = false
                            dismiss()
                        }) {
                            SettingsRow(icon: "doc.text.fill", color: .purple, title: "查看合规声明")
                        }
                    }
                    .listRowBackground(Color(hex: "1C1C1E"))
                    
                    // --- 支持与关于 ---
                    Section(header: Text("支持").foregroundColor(.gray)) {
                        // 评分
                        Button(action: {
                            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                                SKStoreReviewController.requestReview(in: scene)
                            }
                        }) {
                            SettingsRow(icon: "star.fill", color: .yellow, title: "给个好评")
                        }
                        
                        // 隐私政策链接 (上架必须)
                        Link(destination: URL(string: "https://your-privacy-policy-url.com")!) {
                            SettingsRow(icon: "hand.raised.fill", color: .blue, title: "隐私政策")
                        }
                        
                        // 版本号
                        HStack {
                            Text("当前版本")
                            Spacer()
                            Text(appVersion)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color(hex: "1C1C1E"))
                    
                    // --- 底部免责声明 ---
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("免责声明")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.6))
                            Text("本应用仅为随机数模拟生成工具，旨在提供娱乐体验。应用内所有结果均为算法随机生成，与现实世界中任何官方彩票开奖结果无关。\n\n本应用不提供任何形式的网络购彩、赌博或资金交易服务。请用户理性对待，切勿沉迷。")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineSpacing(4)
                        }
                        .padding(.top, 10)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.insetGrouped) // 这种风格最像 iOS 设置，但在黑色背景下需要微调
                .scrollContentBackground(.hidden) // 隐藏 List 默认背景
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.3))
                            .font(.system(size: 24))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // 模拟恢复购买
    func restorePurchase() {
        // 这里后续会接入 StoreKit
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - 辅助组件

struct CustomToggle: View {
    @Binding var isOn: Bool
    let icon: String
    let color: Color
    let title: String
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(color)
                    .cornerRadius(6)
                Text(title)
                    .foregroundColor(.white)
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 28, height: 28)
                .background(color)
                .cornerRadius(6)
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}
