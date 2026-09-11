//
//  PopoverSampleView.swift
//  SwiftUIReference
//
//  Created by Mark Dubouzet on 8/22/26.
//

import SwiftUI

struct PopoverSampleView: View {
    @AppStorage(ChatFontSize.storageKey) private var chatFontSize: ChatFontSize = .medium
    @State private var showMenu = false

    var body: some View {
        Button {
            showMenu.toggle()
        } label: {
            Image(systemName: chatFontSize.systemImage)
                .font(.title2)
        }
        .accessibilityLabel("Chat font size")
        .accessibilityValue(chatFontSize.title)
        .popover(
            isPresented: $showMenu,
            attachmentAnchor: .rect(.bounds)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ChatFontSize.allCases) { size in
                    if size != ChatFontSize.allCases.first {
                        Divider()
                    }

                    Button {
                        chatFontSize = size
                        showMenu = false
                    } label: {
                        HStack {
                            Label(size.title, systemImage: size.systemImage)
                            Spacer(minLength: 12)
                            if chatFontSize == size {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .buttonStyle(.plain)
            .padding()
            .frame(width: 200)
            .presentationCompactAdaptation(.popover)
        }
    }
}

#Preview {
    PopoverSampleView()
}


struct MiniPopoverMenu<Label: View, Content: View>: View {

    @State private var isPresented = false

    let label: () -> Label
    let content: () -> Content

    init(
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.content = content
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            label()
        }
        .popover(
            isPresented: $isPresented,
            attachmentAnchor: .rect(.bounds)
        ) {
            content()
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }
}
