import Foundation

/// Shop-authored reusable setup. Never contains a powder lot, customer, quantity,
/// operator for a run, measured value, inspection result or handoff fact.
public struct ShopPreset: Codable, Equatable, Sendable {
    public let id: UUID
    public let revision: Int
    public let title: String
    public let partIdentity: String
    public let substrate: String
    public let finish: String
    public let requiredPreparationCheckpoints: [String]
    public let recipe: CureRecipe
    public let suggestedBooth: String
    public let suggestedOven: String
    public let measurementPoint: String
    public let measurementMethod: String
    public let sourceReviewedBy: String
    public let reviewedAt: Date

    public init(id: UUID = UUID(), revision: Int = 1, title: String,
                partIdentity: String, substrate: String, finish: String,
                requiredPreparationCheckpoints: [String], recipe: CureRecipe,
                suggestedBooth: String, suggestedOven: String,
                measurementPoint: String, measurementMethod: String,
                sourceReviewedBy: String, reviewedAt: Date = Date()) throws {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let checks = requiredPreparationCheckpoints.map(trim)
        try recipe.validate()
        guard revision > 0, revision < Int.max,
              ![title, partIdentity, substrate, finish, suggestedBooth, suggestedOven,
                measurementPoint, measurementMethod, sourceReviewedBy].map(trim).contains(""),
              !checks.isEmpty, !checks.contains(""), Set(checks).count == checks.count else {
            throw RunError.invalid("A shop preset needs a distinct name, part, process, preparation checks and source reviewer.")
        }
        self.id = id; self.revision = revision; self.title = trim(title)
        self.partIdentity = trim(partIdentity); self.substrate = trim(substrate)
        self.finish = trim(finish); self.requiredPreparationCheckpoints = checks
        self.recipe = recipe; self.suggestedBooth = trim(suggestedBooth)
        self.suggestedOven = trim(suggestedOven)
        self.measurementPoint = trim(measurementPoint)
        self.measurementMethod = trim(measurementMethod)
        self.sourceReviewedBy = trim(sourceReviewedBy); self.reviewedAt = reviewedAt
    }

    public func validate() throws {
        _ = try ShopPreset(id: id, revision: revision, title: title,
                           partIdentity: partIdentity, substrate: substrate, finish: finish,
                           requiredPreparationCheckpoints: requiredPreparationCheckpoints,
                           recipe: recipe, suggestedBooth: suggestedBooth, suggestedOven: suggestedOven,
                           measurementPoint: measurementPoint, measurementMethod: measurementMethod,
                           sourceReviewedBy: sourceReviewedBy, reviewedAt: reviewedAt)
    }
}
