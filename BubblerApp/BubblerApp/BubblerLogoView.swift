//
//  BubblerLogoView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/11/26.
//

import SwiftUI

struct BubblerLogoView: View {
    var body: some View {
        ZStack {
            
            // light background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(0.25),
                            Color.blue.opacity(0.15),
                            Color.blue.opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 140
                    )
                )
                .frame(width: 180, height: 180)
            
            // main bubble cluster
            Bubble(x: -25, y: -30, size: 38, opacity: 0.9)
            Bubble(x: 15, y: -45, size: 22, opacity: 0.7)
            Bubble(x: 35, y: -10, size: 26, opacity: 0.75)
            
            Bubble(x: -35, y: 15, size: 30, opacity: 0.8)
            Bubble(x: 10, y: 25, size: 40, opacity: 0.85)
            Bubble(x: 45, y: 35, size: 20, opacity: 0.65)
            
            Bubble(x: -10, y: 55, size: 24, opacity: 0.7)
            
            // highlight the bubble
            Bubble(x: 5, y: 5, size: 18, opacity: 1.0)
                .shadow(color: .white.opacity(0.3), radius: 6)
        }
        .frame(width: 180, height: 180)
    }
}

//
// bubble
struct Bubble: View {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(opacity),
                        Color.cyan.opacity(opacity * 0.6),
                        Color.blue.opacity(opacity * 0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.80), lineWidth: 1)
            )
            .frame(width: size, height: size)
            .offset(x: x, y: y)
            .blur(radius: 0.2)
            .shadow(color: .blue.opacity(0.15), radius: 4)
    }
}
