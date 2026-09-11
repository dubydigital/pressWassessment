//
//  PersistedChatMessage.swift
//  SampleAISDK
//
//  SwiftData shape for later conversation persistence / RAG indexing.
//  Not wired into the live chat loop yet — ChatViewModel keeps context
//  in memory and sends the full `messages` array on every `/api/chat` call.
//

import Foundation
import SwiftData

@Model
final class PersistedChatMessage {
    var id: UUID
    var conversationID: UUID
    var roleRaw: String
    var content: String
    var createdAt: Date
    var attachmentFileName: String?
    var attachmentMIMEType: String?

    /// Future RAG: ids of chunks retrieved for this turn.
    var retrievedChunkIDs: [String]

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: ChatRole,
        content: String,
        createdAt: Date = .now,
        attachmentFileName: String? = nil,
        attachmentMIMEType: String? = nil,
        retrievedChunkIDs: [String] = []
    ) {
        self.id = id
        self.conversationID = conversationID
        self.roleRaw = role.rawValue
        self.content = content
        self.createdAt = createdAt
        self.attachmentFileName = attachmentFileName
        self.attachmentMIMEType = attachmentMIMEType
        self.retrievedChunkIDs = retrievedChunkIDs
    }

    var role: ChatRole {
        ChatRole(rawValue: roleRaw) ?? .user
    }
}
