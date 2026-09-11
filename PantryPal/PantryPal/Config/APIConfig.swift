//
//  APIConfig.swift
//  SampleAISDK
//

import Foundation

enum APIConfig {
    /// DEBUG talks to the local Fastify Vercel AI SDK server.
    /// Release uses a placeholder until a real host is deployed.
    static var baseURL: URL {
        #if DEBUG
        URL(string: "http://localhost:3000")!
        #else
        URL(string: "https://your-production-api.example.com")!
        #endif
    }

    static var chatURL: URL {
        baseURL.appending(path: "api/chat")
    }

    static var policyURL: URL {
        baseURL.appending(path: "api/policy")
    }

    /// Canonical allergen copy. Must match `ALLERGEN_NOTICE` in `server.ts`.
    /// Rendered by the app, not by the model.
    static let allergenNotice =
        "Always verify ingredient labels and preparation methods for your specific allergies."

    static let maxAttachmentBytes = 10 * 1024 * 1024
}
