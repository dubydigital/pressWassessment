//
//  MainTabView.swift
//  SampleAISDK
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Int = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(0)

            DisclaimerView()
                .tabItem {
                    Label("Disclaimers", systemImage: "exclamationmark.triangle")
                }
                .tag(1)

            // TODO: Used for Local Persistence
//            PersistenceView()
//                .tabItem {
//                    Label("Data", systemImage: "internaldrive")
//                }
//                .tag(2)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: Item.self, inMemory: true)
}
