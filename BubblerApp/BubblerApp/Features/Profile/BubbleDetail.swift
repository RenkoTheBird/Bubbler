//
//  BubbleDetail.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/12/26.
//

import SwiftUI

struct BubbleDetail: View {
    
    let bubbleName: String
    let bubbleColor: Color
    
    var body: some View {
        
        ZStack {
            
            // darker gradient
            LinearGradient(
                colors: [
                    bubbleColor.opacity(0.8),
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                
                VStack(spacing: 28) {
                    
                    Spacer().frame(height: 25)
                    
                    // ssymmetrical center piece
                    VStack(spacing: 14) {
                        
                        ZStack {
                            Circle()
                                .fill(bubbleColor.opacity(0.25))
                                .frame(width: 90, height: 90)
                                .blur(radius: 0.5)
                            
                            Circle()
                                .stroke(bubbleColor.opacity(0.6), lineWidth: 1)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "circle.grid.2x2.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 22, weight: .semibold))
                        }
                        
                        Text(bubbleName.uppercased())
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(2)
                        
                        Text("Active Bubble Universe")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // context card 
                    VStack(spacing: 10) {
                        
                        Text("Context Layer")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(1)
                        
                        Text("Everything you see is shaped by your interaction with this bubble.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    
                    // feed stack
                    VStack(spacing: 14) {
                        
                        //PLACEHOLDERS
                        bubbleCard("Posts connected to this bubble will appear here after your feed has data.")
                        bubbleCard("Your interactions in the feed will shape the context shown in this view.")
                        bubbleCard("Use the feed to grow this bubble with real topics and activity.")
                        bubbleCard("Seeded content can be added later when the database is ready.")
                    }
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 30)
                }
            }
        }
    }
    
    // unified card
    private func bubbleCard(_ text: String) -> some View {
        
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(bubbleColor.opacity(0.15), lineWidth: 1)
                    )
            )
    }
}
//PLACEHOLDER
#Preview {
    BubbleDetail(bubbleName: "Tech", bubbleColor: .blue)
}
