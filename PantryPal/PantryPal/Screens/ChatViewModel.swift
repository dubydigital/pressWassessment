//
//  ChatViewModel.swift
//  SampleAISDK
//

import Foundation
import Observation

@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var draft: String = ""
    var pendingAttachment: ChatAttachment?
    var isWebSearchEnabled: Bool = true
    /// Reserved for later. When the Fastify `rag` tool is live, flip this
    /// and send `tools: ["webSearch", "rag"]`.
    var isRAGEnabled: Bool = false
    var activity: AssistantActivity = .idle
    var errorMessage: String?

    private let sessionStore: any ChatSessionStoring
    private var sendTask: Task<Void, Never>?

    var isBusy: Bool {
        activity != .idle
    }

    var canSend: Bool {
        let hasText = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !isBusy && (hasText || pendingAttachment != nil)
    }

    var requestedTools: [ChatTool] {
        var tools: [ChatTool] = []
        if isWebSearchEnabled { tools.append(.webSearch) }
        if isRAGEnabled { tools.append(.rag) }
        return tools
    }

    init(sessionStore: any ChatSessionStoring = InMemoryChatSessionStore()) {
        self.sessionStore = sessionStore
    }

    func attach(fileName: String, mimeType: String, data: Data) {
        errorMessage = nil
        if data.count > APIConfig.maxAttachmentBytes {
            errorMessage = ChatAPIError.fileTooLarge(fileName).localizedDescription
            return
        }
        pendingAttachment = ChatAttachment(
            fileName: fileName,
            mimeType: mimeType,
            data: data
        )
    }

    func removeAttachment() {
        pendingAttachment = nil
    }

    func send() {
        guard canSend else { return }
        sendTask?.cancel()
        sendTask = Task { await performSend() }
    }

    func stop() {
        sendTask?.cancel()
        sendTask = nil
        if activity != .idle {
            activity = .idle
        }
    }

    func clearConversation() {
        stop()
        messages = []
        errorMessage = nil
        Task { try? await sessionStore.clear() }
    }

    private func performSend() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = pendingAttachment
        draft = ""
        pendingAttachment = nil
        errorMessage = nil

        let userContent: String = {
            if text.isEmpty {
                return "Please look at this file: \(attachment?.fileName ?? "attachment")."
            }
            return text
        }()

        let userMessage = ChatMessage(
            role: .user,
            content: userContent,
            attachment: attachment?.metadataOnly()
        )
        messages.append(userMessage)

        activity = initialActivity()

        let history = messages.map {
            ChatAPIMessage(role: $0.role, content: $0.content)
        }

        let assistantID = UUID()

        do {
            try await ChatAPIClient.streamChat(
                messages: history,
                tools: requestedTools,
                attachment: attachment
            ) { token in
                self.appendToken(token, to: assistantID)
            }

            activity = .idle
            try? await sessionStore.saveMessages(messages)
        } catch is CancellationError {
            activity = .idle
            if messages.contains(where: { $0.id == assistantID }) {
                try? await sessionStore.saveMessages(messages)
            }
        } catch let urlError as URLError where urlError.code == .cancelled {
            activity = .idle
            if messages.contains(where: { $0.id == assistantID }) {
                try? await sessionStore.saveMessages(messages)
            }
        } catch {
            activity = .idle
            errorMessage = error.localizedDescription
            if let last = messages.last, last.id == assistantID, last.content.isEmpty {
                messages.removeLast()
            }
        }
    }

    private func initialActivity() -> AssistantActivity {
        if isRAGEnabled { return .retrievingDocs }
        if isWebSearchEnabled { return .searchingWeb }
        return .thinking
    }

    private func appendToken(_ token: String, to assistantID: UUID) {
        if !messages.contains(where: { $0.id == assistantID }) {
            activity = .streaming
            messages.append(ChatMessage(id: assistantID, role: .assistant, content: ""))
        }
        if let index = messages.firstIndex(where: { $0.id == assistantID }) {
            messages[index].content += token
        }
    }
}
