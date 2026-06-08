import StoreKit

@Observable
final class SubscriptionManager {
    private(set) var isPremium: Bool = false
    private(set) var products: [Product] = []

    func loadProducts() async throws {
        products = try await Product.products(for: [
            AppConstants.monthlyProductID,
            AppConstants.yearlyProductID
        ])
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            isPremium = true
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePremiumStatus()
    }

    private func updatePremiumStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                isPremium = transaction.productID == AppConstants.monthlyProductID
                    || transaction.productID == AppConstants.yearlyProductID
            }
        }
    }
}
