// Main tab bar

import SwiftUI

struct MainTabView: View {
    private enum FeedMode {
        case graph
        case ranked
    }

    @State private var feedMode: FeedMode = .graph

    var body: some View {
        TabView {
            NavigationStack {
                Group {
                    switch feedMode {
                    case .graph:
                        GraphFeedView()
                    case .ranked:
                        FeedView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            feedMode = feedMode == .graph ? .ranked : .graph
                        } label: {
                            Label(
                                feedMode == .graph ? "Feed" : "Graph",
                                systemImage: feedMode == .graph ? "list.bullet" : "circle.grid.hex.fill"
                            )
                        }
                        .accessibilityLabel(feedMode == .graph ? "Switch to Feed" : "Switch to Graph")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            CreatePostView()
                        } label: {
                            Label("Create Post", systemImage: "square.and.pencil")
                        }
                        .accessibilityLabel("Create Post")
                    }
                }
            }
            .tabItem {
                Label("Feed", systemImage: "house.fill")
            }

            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthSession())
        .environmentObject(LikedPostsStore())
}
