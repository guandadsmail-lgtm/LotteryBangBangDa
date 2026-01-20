import SwiftUI

struct ComplianceView: View {
    @Binding var hasAgreed: Bool
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color(hex: "000000").ignoresSafeArea()
            
            RadialGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.15), .clear]),
                center: .top,
                startRadius: 0,
                endRadius: 700
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.system(size: 60))
                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .blue.opacity(0.5), radius: 20)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: isAnimating)
                    
                    // 🌍 欢迎标题
                    Text("欢迎使用\n彩票棒棒哒")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.1), value: isAnimating)
                }
                .padding(.bottom, 50)
                
                VStack(alignment: .leading, spacing: 32) {
                    
                    // 🌍 列表项
                    makeFeatureRow(
                        icon: "gamecontroller.fill",
                        color: .orange,
                        title: String(localized: "纯粹娱乐体验"),
                        description: String(localized: "本应用仅为物理模拟与选号辅助工具，旨在提供有趣的数字互动体验。")
                    )
                    .transitionDelay(0.2)
                    
                    makeFeatureRow(
                        icon: "shield.fill",
                        color: .green,
                        title: String(localized: "安全合规"),
                        description: String(localized: "我们严守底线。不提供彩票购买，不引导博彩，不涉及任何资金交易。")
                    )
                    .transitionDelay(0.3)
                    
                    makeFeatureRow(
                        icon: "exclamationmark.bubble.fill",
                        color: .blue,
                        title: String(localized: "理性声明"),
                        description: String(localized: "模拟结果仅供参考。概率是随机的，我们不承诺任何中奖回报，请理性看待。")
                    )
                    .transitionDelay(0.4)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                VStack(spacing: 16) {
                    // 🌍 底部小字
                    Text("点击“继续”即代表您已阅读并同意上述声明")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            hasAgreed = true
                        }
                    }) {
                        // 🌍 按钮文字
                        Text("继续")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.4), radius: 10, y: 5)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 30)
                .animation(.easeOut(duration: 0.8).delay(0.6), value: isAnimating)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    private func makeFeatureRow(icon: String, color: Color, title: String, description: String) -> some View {
        ComplianceFeatureRow(icon: icon, color: color, title: title, description: description)
            .opacity(isAnimating ? 1 : 0)
            .offset(x: isAnimating ? 0 : -20)
    }
}

struct ComplianceFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(color)
                .frame(width: 40)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension View {
    func transitionDelay(_ delay: Double) -> some View {
        self.animation(.easeOut(duration: 0.6).delay(delay), value: UUID())
    }
}
