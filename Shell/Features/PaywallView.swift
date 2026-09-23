import StoreKit
import SwiftUI

/// Commerce surfaces deliberately contain no app icon, logo, custom image
/// asset, or brand mark. Keep all benefits factual and product-specific.
struct PaywallView: View {
    @Environment(ShellModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var legalDocument: LegalDocument?
    @State private var showingManageSubscriptions = false
    let showsDoneButton: Bool

    init(showsDoneButton: Bool = false) {
        self.showsDoneButton = showsDoneButton
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("paywall.title")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text("paywall.message")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                ForEach(["paywall.benefit.unlimited", "paywall.benefit.noAds", "paywall.benefit.support"], id: \.self) { benefit in
                    Label(LocalizedStringKey(benefit), systemImage: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }

                if model.access.purchases.subscriptionCondition == .billingRetry {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("paywall.billingRetry.title", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                        Text("paywall.billingRetry.message").foregroundStyle(.secondary)
                        Button("subscription.manage") { showingManageSubscriptions = true }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                    }
                } else if !model.access.purchases.subscriptionProducts.isEmpty {
                    ForEach(model.access.purchases.subscriptionProducts, id: \.id) { product in
                        Button {
                            Task { await model.access.purchases.purchase(product) }
                        } label: {
                            VStack(spacing: 2) {
                                Text(product.displayName).font(.headline)
                                if let subscription = product.subscription {
                                    Text(product.displayPrice) + Text(" · ") + Text(periodKey(subscription.subscriptionPeriod))
                                }
                                Text("paywall.purchase").font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(model.access.purchases.isPurchasing || model.access.purchases.isRestoring)
                        .accessibilityIdentifier("shell.paywall.purchase.\(product.id)")
                    }
                } else if model.access.purchases.isLoadingProducts {
                    ProgressView("paywall.loadingProduct").frame(maxWidth: .infinity)
                } else {
                    Button("paywall.retryProduct") {
                        Task { await model.access.purchases.start() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("shell.paywall.retryProduct")
                }

                if !model.access.purchases.subscriptionProducts.isEmpty {
                    Text("paywall.subscriptionDisclosure")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("paywall.restore") { Task { await model.access.purchases.restore() } }
                    .frame(maxWidth: .infinity)
                    .disabled(model.access.purchases.isPurchasing || model.access.purchases.isRestoring)
                    .accessibilityIdentifier("shell.paywall.restore")

                HStack {
                    Button("privacy") { legalDocument = .privacy }
                    Spacer()
                    Button("terms") { legalDocument = .terms }
                }
                .font(.footnote)
            }
            .frame(maxWidth: 560)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("upgrade")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("shell.paywall")
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) { Button("done") { dismiss() } }
            }
        }
        .sheet(item: $legalDocument) { document in
            LegalView(document: document)
                .ignoresSafeArea()
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .onChange(of: model.access.purchases.isEntitled) { _, entitled in
            if entitled { dismiss() }
        }
        .alert("store", isPresented: purchaseErrorBinding) {
            Button("ok") {}
        } message: {
            Text(model.access.purchases.message)
        }
    }

    private var purchaseErrorBinding: Binding<Bool> {
        Binding(
            get: { model.access.purchases.showingError },
            set: { model.access.purchases.showingError = $0 }
        )
    }

    private func periodKey(_ period: Product.SubscriptionPeriod) -> LocalizedStringKey {
        switch period.unit {
        case .day: period.value == 1 ? "paywall.period.day.one" : "paywall.period.day.other \(period.value)"
        case .week: period.value == 1 ? "paywall.period.week.one" : "paywall.period.week.other \(period.value)"
        case .month: period.value == 1 ? "paywall.period.month.one" : "paywall.period.month.other \(period.value)"
        case .year: period.value == 1 ? "paywall.period.year.one" : "paywall.period.year.other \(period.value)"
        @unknown default: "paywall.period.unknown"
        }
    }
}
