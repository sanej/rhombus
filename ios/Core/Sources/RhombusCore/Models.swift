import Foundation

public enum FeatureStatus: String, Codable, CaseIterable, Sendable {
    case idea, planned, inProgress, blocked, done

    public var label: String {
        switch self {
        case .idea: return "Idea"
        case .planned: return "Planned"
        case .inProgress: return "In Progress"
        case .blocked: return "Blocked"
        case .done: return "Done"
        }
    }
}

public struct Product: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var createdAt: String
    public init(id: String, name: String, createdAt: String = "") {
        self.id = id; self.name = name; self.createdAt = createdAt
    }
}

public struct Feature: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var productId: String
    public var title: String
    public var status: FeatureStatus
    public var updatedAt: String
    public init(id: String, productId: String, title: String, status: FeatureStatus, updatedAt: String = "") {
        self.id = id; self.productId = productId; self.title = title; self.status = status; self.updatedAt = updatedAt
    }
}

public struct AppState: Codable, Equatable, Sendable {
    public var products: [Product]
    public var features: [Feature]
    public init(products: [Product] = [], features: [Feature] = []) {
        self.products = products; self.features = features
    }
}
