//
//  ChatView.swift
//  SampleAISDK
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isPhotoPickerPresented = false
    @State private var isFileImporterPresented = false
    @State private var isAttachDialogPresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }
                composer
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog("Attach", isPresented: $isAttachDialogPresented, titleVisibility: .visible) {
                Button("Photo Library") { isPhotoPickerPresented = true }
                Button("Files") { isFileImporterPresented = true }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(
                isPresented: $isPhotoPickerPresented,
                selection: $pickedPhoto,
                matching: .images
            )
            .onChange(of: pickedPhoto) { _, item in
                Task { await importPhoto(item) }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.image, .pdf, .plainText, .utf8PlainText],
                allowsMultipleSelection: false
            ) { result in
                importFile(result)
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty && !viewModel.activity.showsIndicator {
                        emptyState
                            .padding(.top, 48)
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.activity.showsIndicator {
                        ThinkingRow(activity: viewModel.activity)
                            .id("activity")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.activity) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Ask anything")
                .font(.headline)
            Text("Attach a photo or PDF, or turn on web search for current events.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let attachment = viewModel.pendingAttachment {
                attachmentChip(attachment)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    isAttachDialogPresented = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .disabled(viewModel.isBusy)
                .accessibilityLabel("Attach a file")

                TextField("Message", text: $viewModel.draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))

                if viewModel.isBusy {
                    Button(action: viewModel.stop) {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Stop")
                } else {
                    Button(action: viewModel.send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                    }
                    .disabled(!viewModel.canSend)
                    .accessibilityLabel("Send")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Clear", role: .destructive, action: viewModel.clearConversation)
                .disabled(viewModel.messages.isEmpty && viewModel.pendingAttachment == nil)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.isWebSearchEnabled.toggle()
            } label: {
                Image(systemName: viewModel.isWebSearchEnabled ? "globe" : "globe.slash")
            }
            .accessibilityLabel("Web search")
            .accessibilityValue(viewModel.isWebSearchEnabled ? "On" : "Off")
            .foregroundStyle(viewModel.isWebSearchEnabled ? Color.accentColor : Color.secondary)
            .disabled(viewModel.isBusy)
        }
    }

    private func attachmentChip(_ attachment: ChatAttachment) -> some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.isImage ? "photo" : "doc")
            Text(attachment.fileName)
                .lineLimit(1)
            Button(action: viewModel.removeAttachment) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Remove attachment")
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.08))
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            if viewModel.activity.showsIndicator {
                proxy.scrollTo("activity", anchor: .bottom)
            } else if let id = viewModel.messages.last?.id {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { pickedPhoto = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let type = item.supportedContentTypes.first
            let mime = type?.preferredMIMEType ?? "image/jpeg"
            let ext = type?.preferredFilenameExtension ?? "jpg"
            viewModel.attach(fileName: "photo.\(ext)", mimeType: mime, data: data)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func importFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                let type = UTType(filenameExtension: url.pathExtension)
                let mime = type?.preferredMIMEType ?? "application/octet-stream"
                viewModel.attach(fileName: url.lastPathComponent, mimeType: mime, data: data)
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if let attachment = message.attachment {
                    Label(attachment.fileName, systemImage: attachment.isImage ? "photo" : "doc")
                        .font(.caption)
                        .foregroundStyle(message.role == .user ? Color.white.opacity(0.9) : Color.secondary)
                }

                if !message.content.isEmpty {
                    Text(message.content)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(message.role == .user ? Color.white : Color.primary)

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }

    private var bubbleColor: Color {
        message.role == .user ? Color.accentColor : Color(.secondarySystemBackground)
    }
}

private struct ThinkingRow: View {
    let activity: AssistantActivity

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(activity.statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ChatView()
}
