// Main tab bar

import SwiftUI

struct MainTabView: View {
    
    var body: some View {
        
        TabView {
            
            NavigationStack {
                GraphFeedView()
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
}
