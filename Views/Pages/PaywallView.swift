import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var storeManager = StoreManager.shared
    
    var body: some View {
        ZStack {
            // 1. 深邃背景
            Color(hex: "050505").ignoresSafeArea()
            
            // 背景光效
            RadialGradient(
                gradient: Gradient(colors: [Color.orange.opacity(0.15), .clear]),
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                // --- 顶部关闭按钮 ---
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.3))
                            .padding()
                    }
                }
                
                // --- 核心视觉区域 ---
                VStack(spacing: 15) {
                    // 皇冠图标动画效果
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.orange.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                            .frame(width: 120, height: 120)
                            .blur(radius: 10)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: .orange.opacity(0.6), radius: 15, y: 5)
                    }
                    
                    Text("Upgrade to Pro")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    // 副标题强调解除限制
                    Text("Remove 10-Time Limit")
                        .font(.headline)
                        .foregroundColor(.orange.opacity(0.9))
                        .padding(.top, -5)
                }
                .padding(.top, 0)
                
                // --- 权益列表 (根据您的新规则重写) ---
                VStack(spacing: 25) {
                    // 卖点 1: 无限次玩 (这是痛点)
                    FeatureRow(
                        icon: "infinity",
                        iconColor: .green,
                        text: "Unlimited Shuffles & Plays"
                    )
                    
                    // 卖点 2: 解锁全部模式
                    FeatureRow(
                        icon: "lock.open.fill",
                        iconColor: .blue,
                        text: "Unlock All Lottery Modes"
                    )
                    
                    // 卖点 3: 无限历史记录
                    FeatureRow(
                        icon: "list.bullet.rectangle.portrait.fill",
                        iconColor: .purple,
                        text: "Unlimited History Storage"
                    )
                    
                    // 卖点 4: 开发者支持
                    FeatureRow(
                        icon: "heart.fill",
                        iconColor: .red,
                        text: "Support Independent Developer"
                    )
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.05))
                        .padding(.horizontal)
                )
                
                Spacer()
                
                // --- 底部购买区域 ---
                VStack(spacing: 15) {
                    if storeManager.isPro {
                        // 已购买状态
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("You are a Pro user")
                        }
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                        .background(
                            Capsule().fill(Color.green.opacity(0.1))
                        )
                    } else {
                        // 购买按钮
                        Button(action: {
                            Task {
                                HapticManager.shared.impact(style: .medium)
                                if let product = storeManager.products.first {
                                    try? await storeManager.purchase(product)
                                }
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                
                                HStack {
                                    if storeManager.products.isEmpty {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 5)
                                    }
                                    
                                    // 动态显示价格
                                    if let product = storeManager.products.first {
                                        Text("Unlock Now")
                                            .font(.headline.bold()) +
                                        Text(" - \(product.displayPrice)")
                                            .font(.subheadline)
                                    } else {
                                        Text("Unlock Now")
                                            .font(.headline.bold())
                                    }
                                }
                                .foregroundColor(.white)
                            }
                            .frame(height: 56)
                            .shadow(color: .orange.opacity(0.4), radius: 10, y: 5)
                        }
                        
                        // 恢复购买
                        Button(action: {
                            Task {
                                await storeManager.restorePurchases()
                            }
                        }) {
                            Text("Restore Purchases")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.4))
                                .underline()
                        }
                        .padding(.top, 5)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 组件：权益行
struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let text: String // 传入英文 Key
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            // 使用 LocalizedStringKey 自动翻译
            Text(LocalizedStringKey(text))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundColor(iconColor.opacity(0.6))
        }
        .padding(.horizontal, 10)
    }
}
