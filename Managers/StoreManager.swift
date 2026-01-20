import Foundation
import StoreKit
import Combine
import SwiftUI

class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var isPro: Bool = UserDefaults.standard.bool(forKey: "isPro") {
        didSet {
            UserDefaults.standard.set(isPro, forKey: "isPro")
            UsageManager.shared.setVipStatus(isPro)
        }
    }
    
    @Published var products: [Product] = []
    static let proProductID = "com.lottery.bangbangda.pro"
    
    private var updates: Task<Void, Never>? = nil
    
    private init() {
        updates = newTransactionListenerTask()
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }
    
    deinit { updates?.cancel() }
    
    @MainActor
    func requestProducts() async {
        do {
            products = try await Product.products(for: [StoreManager.proProductID])
        } catch { print("❌ 获取商品失败: \(error)") }
    }
    
    @MainActor
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case .success(let verification) = result {
            if let transaction = try? checkVerified(verification) {
                self.isPro = true
                await transaction.finish()
            }
        }
    }
    
    @MainActor
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateCustomerProductStatus()
    }
    
    @MainActor
    func updateCustomerProductStatus() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result), transaction.productID == StoreManager.proProductID {
                hasPro = true
            }
        }
        self.isPro = hasPro
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }
    
    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if let _ = try? self.checkVerified(result) {
                    await self.updateCustomerProductStatus()
                }
            }
        }
    }
}

enum StoreError: Error { case failedVerification }
