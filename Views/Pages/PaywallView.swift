import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var storeManager = StoreManager.shared
    
    var body: some View {
        ZStack {
            // 背景色
            Color(hex: "050505").ignoresSafeArea()
            
            VStack(spacing: 25) {
                // 顶部关闭按钮
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                // 图标与标题
                VStack(spacing: 15) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .orange.opacity(0.5), radius: 10)
                    
                    Text("升级到 Pro 版")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    Text("解锁全部高级功能，支持开发者")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                
                // 功能列表
                VStack(spacing: 15) {
                    FeatureRow(icon: "slot", text: "解锁老虎机模式")
                    FeatureRow(icon: "list.bullet.rectangle", text: "无限历史记录存储")
                    FeatureRow(icon: "square.and.arrow.up", text: "移除底部广告")
                    FeatureRow(icon: "heart.fill", text: "支持独立开发")
                }
                .padding(.vertical, 20)
                
                Spacer()
                
                // 购买区域
                if storeManager.isPro {
                    // 已购买状态
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("您已是尊贵的 Pro 用户")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                } else {
                    // 未购买状态
                    VStack(spacing: 15) {
                        if let product = storeManager.products.first(where: { $0.id == StoreManager.proProductID }) {
                            // 购买按钮
                            Button(action: {
                                Task {
                                    try? await storeManager.purchase(product)
                                }
                            }) {
                                HStack {
                                    Text("立即解锁")
                                    Spacer()
                                    Text(product.displayPrice) // 显示本地价格 (例如 ¥6.00 或 $0.99)
                                }
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(12)
                            }
                        } else {
                            // 加载中...
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            Text("正在连接 App Store...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // 恢复购买按钮
                        Button("恢复购买记录") {
                            Task {
                                await storeManager.restorePurchases()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 5)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 30)
        }
        .preferredColorScheme(.dark)
    }
}

// 辅助视图：功能行
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon == "slot" ? "die.face.5.fill" : icon) // 这里做个简单映射，或者您可以换成您喜欢的图标
                .font(.title3)
                .frame(width: 30)
                .foregroundColor(.yellow)
            
            Text(text)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    PaywallView()
}
