import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class StoreManager {
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String? = nil
    private(set) var product: Product? = nil
    private(set) var isPurchased: Bool = false

    private let productID = "syrup_4_99"

    init() {
        Task { await self.configure() }
    }

    // MARK: - Setup and product loading
    func configure() async {
        await observeTransactions()
        await loadProducts()
        await updateEntitlements()
    }

    private func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [productID])
            self.product = products.first
        } catch {
            self.errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase / Restore
    func purchase() async -> Bool {
        guard let product else {
            errorMessage = "Product not available."
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateEntitlements()
                return true
            case .userCancelled:
                return false
            case .pending:
                // Pending (Ask to Buy, etc.)
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    func restore() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await updateEntitlements()
            return true
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Entitlements
    private func updateEntitlements() async {
        var hasSyrup = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == productID {
                    hasSyrup = true
                }
            }
        }
        self.isPurchased = hasSyrup
    }

    private func observeTransactions() async {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = result {
                    if transaction.productID == self.productID {
                        await self.updateEntitlements()
                    }
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "StoreManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unverified transaction"])
        case .verified(let safe):
            return safe
        }
    }
}
