import Foundation
import StoreKit
import Combine  // ✨ 核心修复：引入 Combine 框架
import SwiftUI  // ✨ 建议加上：确保 ObservableObject 正常工作

// 定义你的商品 ID (去 App Store Connect 后台填的一样)
// ⚠️ 请确保这里的 ID 和你本地测试文件(LotteryConfig.storekit)里的 Product ID 一致
let PRO_PRODUCT_ID = "com.lottery.bangbangda.pro"

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var isPurchased: Bool = false
    
    private var updates: Task<Void, Never>? = nil
    
    private init() {
        // 启动监听器
        updates = newTransactionListenerTask()
        // 启动时检查是否有权限
        Task {
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    // 1. 从苹果请求商品信息
    func requestProducts() async {
        do {
            let storeProducts = try await Product.products(for: [PRO_PRODUCT_ID])
            self.products = storeProducts
        } catch {
            print("❌ 获取商品失败: \(error)")
        }
    }
    
    // 2. 发起购买
    func purchase() async throws {
        guard let product = products.first else { return }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            
        case .userCancelled, .pending:
            break
        default:
            break
        }
    }
    
    // 3. 恢复购买
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateCustomerProductStatus()
    }
    
    // 检查当前用户权限
    func updateCustomerProductStatus() async {
        var purchased = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == PRO_PRODUCT_ID {
                    purchased = true
                }
            } catch {
                print("⚠️ 交易验证失败")
            }
        }
        
        self.isPurchased = purchased
        UsageManager.shared.setVipStatus(purchased)
    }
    
    // 验证签名
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // 监听交易更新
    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateCustomerProductStatus()
                    await transaction.finish()
                } catch {
                    print("❌ 监听更新出错")
                }
            }
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
