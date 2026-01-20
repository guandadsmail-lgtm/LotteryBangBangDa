import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("isSoundOn") private var isSoundOn = true
    @AppStorage("isHapticOn") private var isHapticOn = true
    @AppStorage("hasAgreedCompliance") var hasAgreedCompliance: Bool = true
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "050505").ignoresSafeArea()
                
                List {
                    // --- 头部 Banner ---
                    Section {
                        HStack(spacing: 16) {
                            Image("AppIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                // 🌍 这里的名字通常不用翻译，保持品牌一致
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
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    
                    // --- 体验设置 ---
                    Section(header: Text("体验设置", comment: "Section Header: Experience").foregroundColor(.gray)) {
                        CustomToggle(isOn: $isSoundOn, icon: "speaker.wave.2.fill", color: .blue, title: String(localized: "音效"))
                            .onChange(of: isSoundOn) { _, newValue in
                                if !newValue { AudioManager.shared.stopAll() }
                            }
                        
                        CustomToggle(isOn: $isHapticOn, icon: "iphone.radiowaves.left.and.right", color: .green, title: String(localized: "震动反馈"))
                    }
                    .listRowBackground(Color(hex: "1C1C1E"))
                    
                    // --- 高级功能 ---
                    Section(header: Text("高级功能", comment: "Section Header: Premium").foregroundColor(.gray)) {
                        Button(action: { restorePurchase() }) {
                            SettingsRow(icon: "arrow.clockwise", color: .orange, title: String(localized: "恢复购买记录"))
                        }
                        
                        Button(action: {
                            hasAgreedCompliance = false
                            dismiss()
                        }) {
                            SettingsRow(icon: "doc.text.fill", color: .purple, title: String(localized: "查看合规声明"))
                        }
                    }
                    .listRowBackground(Color(hex: "1C1C1E"))
                    
                    // --- 支持与关于 ---
                    Section(header: Text("支持", comment: "Section Header: Support").foregroundColor(.gray)) {
                        Button(action: {
                            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                                SKStoreReviewController.requestReview(in: scene)
                            }
                        }) {
                            SettingsRow(icon: "star.fill", color: .yellow, title: String(localized: "给个好评"))
                        }
                        
                        Link(destination: URL(string: "https://your-privacy-policy-url.com")!) {
                            SettingsRow(icon: "hand.raised.fill", color: .blue, title: String(localized: "隐私政策"))
                        }
                        
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
                            // 🌍 长文本国际化
                            Text("本应用仅为随机数模拟生成工具，旨在提供娱乐体验。应用内所有结果均为算法随机生成，与现实世界中任何官方彩票开奖结果无关。\n\n本应用不提供任何形式的网络购彩、赌博或资金交易服务。请用户理性对待，切勿沉迷。", comment: "Disclaimer text footer")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineSpacing(4)
                        }
                        .padding(.top, 10)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(Text("设置"))
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
    
    func restorePurchase() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

struct CustomToggle: View {
    @Binding var isOn: Bool
    let icon: String
    let color: Color
    let title: String // String 自动支持 LocalizedStringKey，但在传递时最好明确类型，这里直接传 String 即可
    
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
