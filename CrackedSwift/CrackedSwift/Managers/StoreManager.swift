//
//  StoreManager.swift
//  Fauna
//
//  Handles StoreKit 2 in-app purchases (e.g. shell removal).
//

import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    // MARK: - Product IDs
    
    /// Consumable product: removes one shell from the sanctuary.
    static let removeShellProductID = "Cracked.CrackedSwift.removeShell"
    
    // MARK: - Published State
    
    @Published private(set) var removeShellProduct: Product? = nil
    @Published private(set) var isPurchasing: Bool = false
    @Published private(set) var purchaseError: String? = nil
    
    private var transactionListener: Task<Void, Error>? = nil
    
    // MARK: - Init
    
    private init() {
        // Start listening for transactions (renewals, refunds, external purchases)
        transactionListener = listenForTransactions()
        
        // Fetch products on launch
        Task {
            await fetchProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Fetch Products
    
    func fetchProducts() async {
        do {
            let products = try await Product.products(for: [Self.removeShellProductID])
            removeShellProduct = products.first
            if removeShellProduct == nil {
                print("⚠️ StoreManager: removeShell product not found in App Store Connect")
            } else {
                print("💰 StoreManager: Loaded product — \(removeShellProduct!.displayName) \(removeShellProduct!.displayPrice)")
            }
        } catch {
            print("❌ StoreManager: Failed to fetch products — \(error.localizedDescription)")
        }
    }
    
    // MARK: - Purchase Shell Removal
    
    /// Purchases the shell removal consumable and, on success, removes the specified shell.
    /// - Parameter shellInstanceId: The `AnimalInstance.id` of the shell to remove.
    /// - Returns: `true` if the purchase succeeded and the shell was removed.
    @discardableResult
    func purchaseShellRemoval(shellInstanceId: String) async -> Bool {
        guard let product = removeShellProduct else {
            purchaseError = "Product not available. Please try again later."
            print("❌ StoreManager: Attempted purchase but product is nil")
            return false
        }
        
        guard !isPurchasing else { return false }
        
        isPurchasing = true
        purchaseError = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Consumable — finish immediately
                await transaction.finish()
                
                // Remove the shell from game data
                GameDataManager.shared.removeShell(instanceId: shellInstanceId)
                
                print("🥚✅ StoreManager: Shell \(shellInstanceId) removed after successful purchase")
                isPurchasing = false
                return true
                
            case .userCancelled:
                print("� StoreManager: User cancelled shell removal purchase")
                isPurchasing = false
                return false
                
            case .pending:
                print("�⏳ StoreManager: Purchase pending (Ask to Buy / SCA)")
                purchaseError = "Purchase is pending approval."
                isPurchasing = false
                return false
                
            @unknown default:
                isPurchasing = false
                return false
            }
        } catch {
            print("❌ StoreManager: Purchase failed — \(error.localizedDescription)")
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            isPurchasing = false
            return false
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    // Consumable transactions just need to be finished
                    await transaction.finish()
                    print("💰 StoreManager: Finished background transaction \(transaction.id)")
                } catch {
                    print("❌ StoreManager: Unverified transaction — \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
