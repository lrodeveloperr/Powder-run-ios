import SwiftUI

struct FeatureView: View {
    let destination: ShellDestination
    let context: FeatureCanvasContext
    @Environment(ShellModel.self) private var model
    @State private var completedActions = 0

    var body: some View {
        GeometryReader { geometry in
            switch activeContentState {
            case .loading:
                ProgressView("loading").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                ContentUnavailableView("empty.title", systemImage: "tray", description: Text("empty.message"))
            case .error:
                ContentUnavailableView {
                    Label("error.title", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("error.message")
                } actions: {
                    Button("tryAgain", action: recoverFromDemoError).buttonStyle(.borderedProminent)
                }
            case .populated:
                if geometry.size.width >= 700 {
                    HStack(spacing: 0) {
                        featureList.frame(width: min(420, geometry.size.width * 0.42))
                        Divider()
                        ContentUnavailableView("select.title", systemImage: "rectangle.split.2x1", description: Text("select.message"))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(uiColor: .secondarySystemBackground))
                    }
                } else {
                    featureList
                }
            }
        }
    }

    private var activeContentState: SampleContentState {
#if DEBUG
        model.contentState
#else
        .populated
#endif
    }

    private func recoverFromDemoError() {
#if DEBUG
        model.contentState = .populated
#endif
    }

    private var featureList: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("feature.today").font(.largeTitle.bold())
                    Text("feature.boundary.message").foregroundStyle(.secondary)
                    if let remaining = context.remainingFreeActions() {
                        Text("usage.remaining \(remaining)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 8)
            }

            Section("feature.access.section") {
                Button("feature.completeSample") { completeSampleAction() }
                LabeledContent("feature.completed", value: "\(completedActions)")
            }

            Section {
                ForEach(1...8, id: \.self) { index in
                    NavigationLink {
                        PlaceholderDetail(title: "Item \(index)")
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey(destination.titleKey)) + Text(" · \(index)")
                            Text("feature.supporting").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func completeSampleAction() {
        // The derived feature supplies its own stable completion ID after its
        // real operation succeeds. This UUID represents a newly completed demo action.
        let result = context.recordSuccessfulAction(UUID().uuidString)
        if case .invalidIdentifier = result { return }
        completedActions += 1
    }
}

private struct PlaceholderDetail: View {
    let title: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "square.dashed", description: Text("feature.replaceDetail"))
            .navigationTitle(title)
    }
}
