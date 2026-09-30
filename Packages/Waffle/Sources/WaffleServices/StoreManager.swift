//
//  StoreManager.swift
//  WaffleServices
//
//  StoreKit 2 wrapper for the one-time Syrup purchase. Conforms to Core's
//  `EntitlementProviding` seam so gating logic tests with a fake instead of StoreKit.
//

import Foundation
import StoreKit
import WaffleCore

@MainActor
@Observable
public final class StoreManager: EntitlementProviding {
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String? = nil
    public private(set) var product: Product? = nil
    public private(set) var isPurchased: Bool = false

    private var updatesTask: Task<Void, Never>?

    private let productID = "syrup_2_99"

    public init() {
        Task { await self.configure() }
    }

    private func clearError() { errorMessage = nil }

    // MARK: - Setup and product loading

    public func configure() async {
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
            self.errorMessage = String(localized: "Failed to load products: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase / Restore

    public func purchase() async -> Bool {
        guard let product else {
            errorMessage = String(localized: "Product not available.")
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
            errorMessage = String(localized: "Purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    public func restore() async -> Bool {
        isLoading = true
        clearError()
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await updateEntitlements()
            return true
        } catch {
            errorMessage = String(localized: "Restore failed: \(error.localizedDescription)")
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
}
