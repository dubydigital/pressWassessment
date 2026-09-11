//
//  ChatFontSize.swift
//  PantryPal
//

import SwiftUI

enum ChatFontSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    static let storageKey = "chatFontSize"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var systemImage: String {
        switch self {
        case .small: "textformat.size.smaller"
        case .medium: "textformat.size"
        case .large: "textformat.size.larger"
        }
    }

    var messageFont: Font {
        switch self {
        case .small: .subheadline
        case .medium: .body
        case .large: .title3
        }
    }

    var headlineFont: Font {
        switch self {
        case .small: .subheadline.weight(.semibold)
        case .medium: .headline
        case .large: .title3.weight(.semibold)
        }
    }

    var secondaryFont: Font {
        switch self {
        case .small: .caption2
        case .medium: .caption
        case .large: .subheadline
        }
    }
}
