//
//  JoinGameView.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import SwiftUI

//Scrollbar
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct CowboyScrollView<Content: View>: View {
    private let content: Content

    @State private var contentHeight: CGFloat = 0
    @State private var containerHeight: CGFloat = 0
    @State private var offsetY: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var thumbRatio: CGFloat {
        guard contentHeight > 0 else { return 1 }
        return min(1, containerHeight / contentHeight)
    }

    private var progress: CGFloat {
        let maxOffset = max(contentHeight - containerHeight, 1)
        return min(max(offsetY / maxOffset, 0), 1)
    }

    var body: some View {
        HStack(spacing: 10) {
            GeometryReader { outerGeo in
                ScrollView(.vertical, showsIndicators: false) {
                    content
                        .background(
                            GeometryReader { innerGeo in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetKey.self,
                                        value: -innerGeo.frame(in: .named("cowboyScroll")).origin.y
                                    )
                                    .preference(
                                        key: ContentHeightKey.self,
                                        value: innerGeo.size.height
                                    )
                            }
                        )
                }
                .coordinateSpace(name: "cowboyScroll")
                .onAppear { containerHeight = outerGeo.size.height }
                .onChange(of: outerGeo.size.height) {
                    containerHeight = outerGeo.size.height
                }
            }
            .onPreferenceChange(ScrollOffsetKey.self) { offsetY = $0 }
            .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }

            // Track + thumb (idk wtf this part is, i generate this part bruh)
            GeometryReader { trackGeo in
                let thumbHeight = max(trackGeo.size.height * thumbRatio, 24)
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.brown.opacity(0.35))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(height: thumbHeight)
                        .offset(y: (trackGeo.size.height - thumbHeight) * progress)
                }
            }
            .frame(width: 10)
        }
    }
}


struct JoinGameView: View {
    @ObservedObject private var connection: GameConnectionManager
    @StateObject private var controller: JoinGameController
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToConfirmation = false

    init(connection: GameConnectionManager) {
        _connection = ObservedObject(wrappedValue: connection)
        _controller = StateObject(wrappedValue: JoinGameController(connection: connection))
    }

    var body: some View {
        ZStack {
            Image(.backgroundMainScreen)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ScreenTopBar(title: "Join Game") {
                    controller.stop() // leaving the list — tear down here, not on disappear.
                    dismiss()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Game List")
                        .font(.headingCSG)

                    CowboyScrollView {
                        VStack(spacing: 12) {
                            ForEach(controller.rooms) { room in
                                Button {
                                    controller.join(room: room)
                                } label: {
                                    Text(room.displayName)
                                        .frame(maxWidth:.infinity, alignment: .center)
                                }
                                .buttonStyle(.cowboy)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 260)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.primaryCSG)
                        .stroke(Color.ternaryCSG,lineWidth: 4)
                )
                .padding(.horizontal, 16)

                Spacer()
            }
        }
                .toolbar(.hidden, for: .navigationBar)
        .onAppear { controller.start() }
        .onChange(of: connection.state) { _, newState in
            // Joined a room — both players meet on the confirmation screen.
            if case .connected = newState {
                navigateToConfirmation = true
            }
        }
        .fullScreenCover(isPresented: $navigateToConfirmation, onDismiss: {
            // Back from the pre-duel screen without a match — browse again.
            if case .connected = connection.state {} else {
                controller.start()
            }
        }) {
            ConfirmationScreenView(connection: connection)
        }
    }
}

#Preview {
    JoinGameView(connection: GameConnectionManager())
}
