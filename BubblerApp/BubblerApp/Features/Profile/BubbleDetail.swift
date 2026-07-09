//
//  BubbleDetail.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/12/26.
//

import SwiftUI
import Combine

struct BubbleDetail: View {
    
    let bubbleName: String
    let bubbleColor: Color
    
    var body: some View {
        
        ZStack {
            
            // Background
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
                    
                    // MARK: - Core Bubble Identity
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
                    
                    // MARK: - Context Card
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
                    
                    // MARK: - Content Nodes 
                    VStack(spacing: 14) {
                        
                        NavigationLink {
                            BubbleDetail(bubbleName: "Trending", bubbleColor: .orange)
                        } label: {
                            bubbleCard("Trending signals detected")
                        }
                        
                        NavigationLink {
                            BubbleDetail(bubbleName: "Insights", bubbleColor: .purple)
                        } label: {
                            bubbleCard("Insight stream initializing…")
                        }
                        
                        NavigationLink {
                            BubbleDetail(bubbleName: "Engagement", bubbleColor: .green)
                        } label: {
                            bubbleCard("Engagement rising in this bubble")
                        }
                        
                        NavigationLink {
                            BubbleDetail(bubbleName: "Deep Dive", bubbleColor: .blue)
                        } label: {
                            bubbleCard("Recommended deep dive content")
                        }
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Related Bubbles
                    VStack(alignment: .leading, spacing: 14) {
                        
                        Text("Related Bubbles")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            
                            HStack(spacing: 14) {
                                
                                NavigationLink {
                                    BubbleDetail(bubbleName: "AI", bubbleColor: .pink)
                                } label: {
                                    relatedBubble("AI", icon: "brain.head.profile", color: .pink)
                                }
                                
                                NavigationLink {
                                    BubbleDetail(bubbleName: "Tech", bubbleColor: .blue)
                                } label: {
                                    relatedBubble("Tech", icon: "desktopcomputer", color: .blue)
                                }
                                
                                NavigationLink {
                                    BubbleDetail(bubbleName: "Space", bubbleColor: .purple)
                                } label: {
                                    relatedBubble("Space", icon: "globe.americas.fill", color: .purple)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer().frame(height: 30)
                }
            }
        }
    }
    
    // MARK: - Content Card
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
    
    // MARK: - Related Bubble Node
    private func relatedBubble(_ title: String, icon: String, color: Color) -> some View {
        
        VStack(spacing: 10) {
            
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 70, height: 70)
                
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: 55, height: 55)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(.white)
                    )
            }
            
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

#Preview {
    BubbleDetail(bubbleName: "Tech", bubbleColor: .blue)
}
