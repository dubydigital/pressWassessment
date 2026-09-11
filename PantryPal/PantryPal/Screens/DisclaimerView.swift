//
//  DisclaimerView.swift
//  PantryPal
//

import SwiftUI

struct DisclaimerView: View {
    @AppStorage(ChatFontSize.storageKey) private var chatFontSize: ChatFontSize = .medium

    var body: some View {
        NavigationStack {
            List {
                header
                ForEach(DisclaimerTopic.allCases) { topic in
                    Section {
                        Text(topic.body)
                            .font(chatFontSize.messageFont)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        Label(topic.title, systemImage: topic.systemImage)
                            .font(chatFontSize.secondaryFont.weight(.semibold))
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Disclaimers")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)

                Text("Please read before cooking")
                    .font(chatFontSize.headlineFont)

                Text("PantryPal is a cooking assistant. These notices always apply, including when chat responses do not repeat them.")
                    .font(chatFontSize.messageFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.orange.opacity(0.12))
    }
}

private enum DisclaimerTopic: String, CaseIterable, Identifiable {
    case allergens
    case medicalAdvice
    case dataRetention
    case foodSafety
    case children

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allergens: "Allergen notice"
        case .medicalAdvice: "No medical or dietary advice"
        case .dataRetention: "Health-related information"
        case .foodSafety: "Food safety"
        case .children: "Not for children under 13"
        }
    }

    var systemImage: String {
        switch self {
        case .allergens: "allergens"
        case .medicalAdvice: "cross.case"
        case .dataRetention: "lock.shield"
        case .foodSafety: "fork.knife"
        case .children: "figure.and.child.holdinghands"
        }
    }

    var body: String {
        switch self {
        case .allergens:
            APIConfig.allergenNotice
        case .medicalAdvice:
            "PantryPal does not provide medical, nutrition, or therapeutic advice. Ordinary food preferences, such as vegetarian cooking, may be used to suggest recipes. If you mention a health condition, PantryPal will not treat that as a basis for dietary advice and recommends speaking with a qualified professional."
        case .dataRetention:
            "This version does not store health-related mentions, medical dietary restrictions, or conversation history across sessions."
        case .foodSafety:
            "PantryPal does not tell you whether food is safe to eat, including questions about spoilage or foodborne illness. For food-safety questions, consult a recognized authority such as the USDA, FDA, or your local equivalent."
        case .children:
            "PantryPal is intended for adults. It is not directed at children under 13."
        }
    }
}

#Preview {
    DisclaimerView()
}
