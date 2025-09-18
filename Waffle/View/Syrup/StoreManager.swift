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

    nonisolated(unsafe) private var updatesTask: Task<Void, Never>? = nil

    private let productID = "syrup_2_99"

    init() {
        Task { await self.configure() }
    }

    private func clearError() { errorMessage = nil }

    // MARK: - Setup and product loading
    func configure() async {
        startObservingTransactionsIfNeeded()
        await loadProducts()
        await updateEntitlements()
    }

    private func loadProducts() async {
        isLoading = true
        clearError()
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
        clearError()
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateEntitlements()
                await transaction.finish()
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
        clearError()
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

    private func startObservingTransactionsIfNeeded() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
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

    nonisolated deinit {
        // Snapshot the task reference before cancellation to avoid main-actor isolation issues
        let task = updatesTask
        task?.cancel()
    }
}

