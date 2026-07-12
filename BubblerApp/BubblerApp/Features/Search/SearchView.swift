//
//  SearchView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/13/26.
//
import SwiftUI
struct SearchView: View {
    
    @State private var searchText = ""
    
    let trendingBubbles = [
        "Aviation", "Travel", "Photography",
        "Fitness", "Music", "Gaming",
        "Food", "Tech", "College",
        "Sports", "Cars", "Fashion"
    ]
    
    let recentSearches = [
        "Planes",
        "Programming",
        "Miami",
        "Cookies"
    ]
    
    var body: some View {
        
        ZStack {
            
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.9),
                    Color.cyan.opacity(0.55),
                    Color.indigo.opacity(0.9),
                    Color.black.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                
                VStack(alignment: .leading, spacing: 26) {
                    
                    Spacer().frame(height: 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("find your next bubble")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.75))
                        
                        TextField("Search for a bubble...", text: $searchText)
                            .foregroundColor(.white)
                            .tint(.white)
                    }
                    .padding()
                    .background(.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Trending Bubbles")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 110), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(trendingBubbles, id: \.self) { bubble in
                                Text(bubble)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .background(.white.opacity(0.15))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(.white.opacity(0.25), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recent Searches")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        VStack(spacing: 12) {
                            ForEach(recentSearches, id: \.self) { search in
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.white.opacity(0.75))
                                    
                                    Text(search)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                .padding()
                                .background(.white.opacity(0.13))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 22)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
#Preview {
    SearchView()
}

