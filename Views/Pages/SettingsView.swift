
import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("isSoundOn") private var isSoundOn = true
    @AppStorage("isHapticOn") private var isHapticOn = true
    @AppStorage("hasAgreedCompliance") var hasAgreedCompliance: Bool = true
    
    // 🔥 监听 StoreManager 状态，如果已买 Pro 就隐藏购买按钮
    @ObservedObject var storeManager = StoreManager.shared
    
    // 🔥 控制购买页面的弹出
    @State private var showPaywall = false
    
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
                                Text(String(localized: "彩票帮帮忙")) // 确保 Localizable 里有这个 Key
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
                    Section(header: Text("体验设置").foregroundColor(.gray)) {
                        CustomToggle(isOn: $isSoundOn, icon: "speaker.wave.2.fill", color: .blue, title: String(localized: "音效"))
                            .onChange(of: isSoundOn) { _, newValue in
                                if !newValue { AudioManager.shared.stopAll() }
                            }
                        
                        CustomToggle(isOn: $isHapticOn, icon: "iphone.radiowaves.left.and.right", color: .green, title: String(localized: "震动反馈"))
                    }
                    .listRowBackground(Color(hex: "1C1C1E"))
                    
                    // --- 高级功能 ---
                    Section(header: Text("高级功能").foregroundColor(.gray)) {
                        
                        // 🔥 新增：购买入口 (只有非 Pro 用户才显示)
                        if !storeManager.isPro {
                            Button(action: { showPaywall = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 28, height: 28)
                                        .background(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                                        .cornerRadius(6)
                                    Text(String(localized: "升级到 Pro 版"))
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        } else {
                            // Pro 用户显示尊贵标识
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text(String(localized: "已解锁 Pro 功能"))
                                    .foregroundColor(.gray)
                            }
                        }
                        
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
                    Section(header: Text("支持").foregroundColor(.gray)) {
                        Button(action: {
                            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                                SKStoreReviewController.requestReview(in: scene)
                            }
                        }) {
                            SettingsRow(icon: "star.fill", color: .yellow, title: String(localized: "给个好评"))
                        }
                        
                        // 隐私政策链接
                        Link(destination: URL(string: "https://guandadsmail-lgtm.github.io/LotteryBangBangDa/PRIVACY")!) {
                            SettingsRow(icon: "hand.raised.fill", color: .blue, title: String(localized: "隐私政策"))
                        }
                        
                        HStack {
                            Text(String(localized: "当前版本"))
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
                            Text(String(localized: "免责声明"))
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.6))
                            Text(String(localized: "本应用仅为随机数模拟生成工具，旨在提供娱乐体验。应用内所有结果均为算法随机生成，与现实世界中任何官方彩票开奖结果无关。\n\n本应用不提供任何形式的网络购彩、赌博或资金交易服务。请用户理性对待，切勿沉迷。"))
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
            .navigationTitle(String(localized: "设置"))
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
            // 🔥 弹窗：显示购买页面
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // 恢复购买逻辑
    func restorePurchase() {
        Task {
            await StoreManager.shared.restorePurchases()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
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
}
