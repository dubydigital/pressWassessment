//
//  ChatAPIClient.swift
//  SampleAISDK
//
//  POST /api/chat
//    JSON            — no file
//    multipart       — photo / PDF attached
//  Response is a UTF-8 text stream (same as the Fastify handler).
//

import Foundation

enum ChatAPIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String?)
    case fileTooLarge(String)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The chat API returned an unexpected response."
        case .httpStatus(let code, let body):
            if let body, !body.isEmpty {
                "Chat API error (\(code)): \(body)"
            } else {
                "Chat API error (\(code))."
            }
        case .fileTooLarge(let name):
            "\(name) is over 10 MB, which is the server limit."
        case .encodingFailed:
            "Could not encode the chat request."
        }
    }
}

enum ChatAPIClient {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }()

    static func streamChat(
        messages: [ChatAPIMessage],
        tools: [ChatTool],
        attachment: ChatAttachment?,
        onToken: @escaping (String) -> Void
    ) async throws {
        if let attachment, attachment.fileSize > APIConfig.maxAttachmentBytes {
            throw ChatAPIError.fileTooLarge(attachment.fileName)
        }

        var request = URLRequest(url: APIConfig.chatURL)
        request.httpMethod = "POST"

        if let attachment, let data = attachment.data {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue(
                "multipart/form-data; boundary=\(boundary)",
                forHTTPHeaderField: "Content-Type"
            )
            request.httpBody = try makeMultipartBody(
                messages: messages,
                tools: tools,
                attachment: attachment,
                data: data,
                boundary: boundary
            )
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(
                ChatJSONBody(
                    messages: messages,
                    tools: tools.map(\.rawValue)
                )
            )
        }

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ChatAPIError.invalidResponse
        }

        if http.statusCode != 200 {
            let body = try await readAll(from: bytes)
            throw ChatAPIError.httpStatus(http.statusCode, body)
        }

        var utf8Remainder = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            utf8Remainder.append(byte)
            if let chunk = String(data: utf8Remainder, encoding: .utf8) {
                utf8Remainder.removeAll(keepingCapacity: true)
                if !chunk.isEmpty {
                    onToken(chunk)
                }
            }
        }
    }

    private static func makeMultipartBody(
        messages: [ChatAPIMessage],
        tools: [ChatTool],
        attachment: ChatAttachment,
        data: Data,
        boundary: String
    ) throws -> Data {
        let encoder = JSONEncoder()
        let messagesJSON = String(data: try encoder.encode(messages), encoding: .utf8)
        let toolsJSON = String(data: try encoder.encode(tools.map(\.rawValue)), encoding: .utf8)
        guard let messagesJSON, let toolsJSON else {
            throw ChatAPIError.encodingFailed
        }

        var body = Data()
        func append(_ string: String) {
            body.append(Data(string.utf8))
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"messages\"\r\n\r\n")
        append("\(messagesJSON)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"tools\"\r\n\r\n")
        append("\(toolsJSON)\r\n")

        append("--\(boundary)\r\n")
        append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(attachment.fileName)\"\r\n"
        )
        append("Content-Type: \(attachment.mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n")
        append("--\(boundary)--\r\n")
        return body
    }

    private static func readAll(from bytes: URLSession.AsyncBytes) async throws -> String? {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return String(data: data, encoding: .utf8)
    }
}
