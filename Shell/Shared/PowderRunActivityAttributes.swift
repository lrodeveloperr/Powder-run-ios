import ActivityKit
import LiveActivityKit

struct PowderRunActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        let model: LiveActivityContentModel
    }
    let batchID: String
}
