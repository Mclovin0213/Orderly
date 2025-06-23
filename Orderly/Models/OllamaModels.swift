// Models/OllamaModels.swift
import Foundation
import Combine // Add Combine for @Published

// Request for /api/generate
struct OllamaGenerateRequest: Codable {
    let model: String
    let prompt: String
    var stream: Bool = false // Changed to var
    // Add other options like system prompt, template, context if needed later
    // let system: String?
    // let template: String?
    // let context: [Int]? // For conversational context
}

// Response for /api/generate (non-streaming)
struct OllamaGenerateResponse: Codable {
    let model: String
    let createdAt: String // Or Date with custom decoder
    let response: String
    let done: Bool
    // These are other potential fields, adjust based on actual non-streaming response
    let totalDuration: Int?
    let loadDuration: Int?
    let promptEvalCount: Int?
    let promptEvalDuration: Int?
    let evalCount: Int?
    let evalDuration: Int?
    // let context: [Int]? // For conversational context
}

struct OllamaErrorResponse: Codable {
    let error: String
}

// For /api/tags (to list models or check availability)
struct OllamaTagsResponse: Codable {
    struct Model: Codable, Identifiable {
        let name: String
        let modifiedAt: String
        let size: Int
        var id: String { name } // Make it Identifiable
    }
    let models: [Model]
}

// Changed from struct to class and added ObservableObject
class ProposedFileSystemChange: ObservableObject, Codable, Identifiable {
    let id = UUID() // For SwiftUI lists
    var folderName: String
    var filesToMove: [String]
    var isNewFolder: Bool = true

    @Published var isApproved: Bool = true // Default to approved

    // Manual Codable conformance
    enum CodingKeys: String, CodingKey {
        case folderName
        case filesToMove
        case isNewFolder
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        folderName = try container.decode(String.self, forKey: .folderName)
        filesToMove = try container.decode([String].self, forKey: .filesToMove)
        isNewFolder = try container.decode(Bool.self, forKey: .isNewFolder)
        // id and isApproved are not decoded from JSON, they are local state/generated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(folderName, forKey: .folderName)
        try container.encode(filesToMove, forKey: .filesToMove)
        try container.encode(isNewFolder, forKey: .isNewFolder)
        // id and isApproved are not encoded to JSON
    }

    // Custom initializer for creating instances in code (e.g., for previews)
    init(folderName: String, filesToMove: [String], isNewFolder: Bool, isApproved: Bool = true) {
        self.folderName = folderName
        self.filesToMove = filesToMove
        self.isNewFolder = isNewFolder
        self.isApproved = isApproved
    }
}