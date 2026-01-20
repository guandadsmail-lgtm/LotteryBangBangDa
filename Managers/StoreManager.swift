import StoreKit
import Combine
import SwiftUI

class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    // 🔥 核心属性：供 SettingsView 和 PaywallView 绑定
    // 使用 UserDefaults 持久化，防止没网时状态丢失
    @Published var isPro: Bool = UserDefaults.standard.bool(forKey: "isPro") {
        didSet {
            UserDefaults.standard.set(isPro, forKey: "isPro")
            // 同时更新 UsageManager 状态
            UsageManager.shared.setVipStatus(isPro)
        }
    }
    
    @Published var products: [Product] = []
    
    // 🔥 统一管理 ID，外面调用 StoreManager.proProductID 即可
    static let proProductID = "com.lottery.bangbangda.pro"
    
    private var updates: Task<Void, Never>? = nil
    
    private init() {
        // 启动监听器
        updates = newTransactionListenerTask()
        
        Task {
            // 1. 先从苹果请求商品详情 (价格、描述)
            await requestProducts()
            // 2. 检查用户有没有买过 (更新 isPro 状态)
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    // 1. 获取商品信息
    @MainActor
    func requestProducts() async {
        do {
            products = try await Product.products(for: [StoreManager.proProductID])
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    // 2. 购买逻辑
    @MainActor
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            if let transaction = try? checkVerified(verification) {
                self.isPro = true // 解锁 Pro
                await transaction.finish()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    // 3. 恢复购买 (SettingsView 调用的就是这个)
    @MainActor
    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    // 4. 更新购买状态 (核心逻辑)
    @MainActor
    func updatePurchasedProducts() async {
        var hasPro = false
        // 遍历用户当前的有效权益
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == StoreManager.proProductID {
                    hasPro = true
                }
            }
        }
        self.isPro = hasPro
    }
    
    // 监听交易更新 (处理后台续费、家庭共享等)
    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                }
            }
        }
    }
    
    // 验证签名
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
