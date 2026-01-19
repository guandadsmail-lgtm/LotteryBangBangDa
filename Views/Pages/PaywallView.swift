import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var storeManager = StoreManager.shared
    @State private var isProcessing = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        ZStack {
            // 背景
            Color(hex: "050505").ignoresSafeArea()
            
            VStack(spacing: 30) {
                // 关闭按钮
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                Spacer()
                
                // 图标
                Image(systemName: "crown.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .orange.opacity(0.5), radius: 20)
                
                VStack(spacing: 12) {
                    Text("解锁 Pro 无限版")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    Text("您的 10 次免费试用已结束")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                // 功能列表
                VStack(alignment: .leading, spacing: 15) {
                    FeatureRow(icon: "infinity", text: "无限次生成号码")
                    FeatureRow(icon: "nosign", text: "移除所有限制")
                    FeatureRow(icon: "heart.fill", text: "支持独立开发者更新")
                }
                .padding(.vertical, 20)
                
                Spacer()
                
                // 购买按钮区域
                VStack(spacing: 16) {
                    if let product = storeManager.products.first {
                        Button(action: { buy(product) }) {
                            HStack {
                                if isProcessing {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("立即解锁 \(product.displayPrice)")
                                        .font(.headline.bold())
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .cornerRadius(28)
                        }
                        .disabled(isProcessing)
                    } else {
                        // 如果还在加载商品信息
                        ProgressView("正在连接 App Store...")
                            .foregroundColor(.gray)
                    }
                    
                    Button("恢复购买") {
                        Task { await storeManager.restorePurchases() }
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
            
            // 成功提示动画
            if showSuccess {
                Color.black.opacity(0.8).ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("解锁成功！")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .transition(.scale)
            }
        }
        .onAppear {
            Task {
                await storeManager.requestProducts()
            }
        }
        .onChange(of: storeManager.isPurchased) { _, isPurchased in
            if isPurchased {
                withAnimation { showSuccess = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
    
    func buy(_ product: Product) {
        isProcessing = true
        Task {
            do {
                try await storeManager.purchase()
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.yellow)
                .frame(width: 24)
            Text(text)
                .foregroundColor(.white.opacity(0.9))
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
