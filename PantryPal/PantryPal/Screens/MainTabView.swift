//
//  MainTabView.swift
//  SampleAISDK
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(0)
            
            // TODO: Used for Local Persistence
//            PersistenceView()
//                .tabItem {
//                    Label("Data", systemImage: "internaldrive")
//                }
//                .tag(1)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: Item.self, inMemory: true)
}
