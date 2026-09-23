import SwiftUI

@main
@MainActor
struct ShellApp: App {
    @State private var shop = ShopBoardModel()

    var body: some Scene {
        WindowGroup {
            ShellRootView(featureProvider: ShopBoardProvider(shop: shop), onDeepLink: { url in
                shop.deepLinkedBatchID = UUID(uuidString: url.lastPathComponent)
            })
                .tint(ShellConfiguration.tint)
        }
    }
}
