import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @State private var manager = SubscriptionManager()

    var body: some View {
        List {
            Section {
                if manager.isPremium {
                    Label("Premium активен", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("Откройте все темы и функции")
                }
            }
            Section("Планы") {
                ForEach(manager.products, id: \.id) { product in
                    Button {
                        Task { try? await manager.purchase(product) }
                    } label: {
                        HStack {
                            Text(product.displayName)
                            Spacer()
                            Text(product.displayPrice)
                        }
                    }
                }
            }
            Section {
                Button("Восстановить покупки") {
                    Task { try? await manager.restorePurchases() }
                }
            }
        }
        .navigationTitle("Подписка")
        .task { try? await manager.loadProducts() }
    }
}
