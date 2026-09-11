//
//  ChatSessionStore.swift
//  SampleAISDK
//
//  Persistence is intentionally a swap-in. In-memory keeps context for the
//  current session (what `/api/chat` needs). Replace with SwiftData later
//  so threads survive launches and can be indexed for RAG.
//

import Foundation

protocol ChatSessionStoring: AnyObject {
    func loadMessages() async throws -> [ChatMessage]
    func saveMessages(_ messages: [ChatMessage]) async throws
    func clear() async throws
}

final class InMemoryChatSessionStore: ChatSessionStoring {
    private var messages: [ChatMessage] = []

    func loadMessages() async throws -> [ChatMessage] {
        messages
    }

    func saveMessages(_ messages: [ChatMessage]) async throws {
        self.messages = messages
    }

    func clear() async throws {
        messages = []
    }
}

/// Placeholder for a future SwiftData-backed store.
/// Map `ChatMessage` ↔ `PersistedChatMessage` and persist `conversationID`.
final class SwiftDataChatSessionStore: ChatSessionStoring {
    func loadMessages() async throws -> [ChatMessage] {
        []
    }

    func saveMessages(_ messages: [ChatMessage]) async throws {
        // TODO: insert/update PersistedChatMessage rows
    }

    func clear() async throws {
        // TODO: delete persisted rows for the active conversation
    }
}
