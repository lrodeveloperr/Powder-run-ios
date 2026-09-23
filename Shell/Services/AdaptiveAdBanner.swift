import SwiftUI

#if ADS_ENABLED
import GoogleMobileAds
import UIKit

struct AdaptiveAdBanner: View {
    let adUnitID: String
    let requestsAds: Bool
    @State private var availableWidth: CGFloat = 320

    private var adSize: AdSize {
        largeAnchoredAdaptiveBanner(width: max(1, availableWidth))
    }

    var body: some View {
        Group {
            if requestsAds && !adUnitID.isEmpty {
                BannerContainer(adSize: adSize, adUnitID: adUnitID)
                    .frame(width: adSize.size.width, height: adSize.size.height)
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: adSize.size.height)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            guard width > 0, abs(width - availableWidth) > 0.5 else { return }
            availableWidth = width
        }
    }
}

private struct BannerContainer: UIViewRepresentable {
    let adSize: AdSize
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        if banner.adSize.size != adSize.size {
            banner.adSize = adSize
            banner.load(Request())
        }
        if banner.rootViewController == nil { banner.rootViewController = rootViewController }
    }

    private var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
#else
/// Keeps root composition identical while producing no advertising view.
struct AdaptiveAdBanner: View {
    let adUnitID: String
    let requestsAds: Bool
    var body: some View { EmptyView() }
}
#endif
