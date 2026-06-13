//
//  SearchView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/13/26.
//

import SwiftUI

struct SearchView: View {
    var body: some View {

        ZStack {
            
            //gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.9),
                    Color.cyan.opacity(0.6),
                    Color.indigo.opacity(0.8),
                    Color.blue.opacity(1.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            
            Text("Search Bubbles 🔍")
                .font(.title.bold())
                .foregroundColor(.white)
        }
    }
}

#Preview {
    SearchView()
}
