//
//  ChatModels.swift
//  SampleAISDK
//

import Foundation

enum ChatRole: String, Codable, Hashable {
    case user
    case assistant
    case system
}

/// Tools the SwiftUI client can request. The Fastify `/api/chat` handler
/// looks these up in `ALL_TOOLS`. Add cases here when the server grows
/// (RAG is already reserved on both sides).
enum ChatTool: String, Codable, CaseIterable, Identifiable {
    case webSearch
    case rag

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .webSearch: "Web Search"
        case .rag: "Documents (RAG)"
        }
    }
}

struct ChatAttachment: Identifiable, Hashable {
    let id: UUID
    var fileName: String
    var mimeType: String
    var data: Data?
    var fileSize: Int

    init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        data: Data? = nil,
        fileSize: Int? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
        self.fileSize = fileSize ?? data?.count ?? 0
    }

    var isImage: Bool { mimeType.hasPrefix("image/") }

    /// Payload for a later turn — history is text-only; file bytes are
    /// only sent on the turn they were attached.
    func metadataOnly() -> ChatAttachment {
        ChatAttachment(
            id: id,
            fileName: fileName,
            mimeType: mimeType,
            data: nil,
            fileSize: fileSize
        )
    }
}

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    var role: ChatRole
    var content: String
    var createdAt: Date
    var attachment: ChatAttachment?

    init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        createdAt: Date = .now,
        attachment: ChatAttachment? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.attachment = attachment
    }
}

enum AssistantActivity: Equatable {
    case idle
    case thinking
    case searchingWeb
    case retrievingDocs
    case streaming

    var statusText: String {
        switch self {
        case .idle: ""
        case .thinking: "Thinking…"
        case .searchingWeb: "Searching the web…"
        case .retrievingDocs: "Looking through your documents…"
        case .streaming: "Writing…"
        }
    }

    var showsIndicator: Bool {
        self == .thinking || self == .searchingWeb || self == .retrievingDocs
    }
}

struct ChatAPIMessage: Codable, Hashable {
    var role: ChatRole
    var content: String
}

struct ChatJSONBody: Codable {
    var messages: [ChatAPIMessage]
    var tools: [String]
}
