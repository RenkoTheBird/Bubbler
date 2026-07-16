//
//  SettingsView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/12/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authSession: AuthSession
    
    var body: some View {
        
        ZStack {
            
            // gradient background
            LinearGradient(
                colors: [
                    Color.black,
                    Color.blue.opacity(0.6),
                    Color.indigo.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                
                VStack(spacing: 26) {
                    
                    Spacer().frame(height: 20)
                    
                    // header
                    VStack(spacing: 6) {
                        Text("Settings")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Control your Bubbler experience")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 10)
                    
                    // account
                    settingsSection(title: "Account") {
                        NavigationLink {
                            ProfileInformationView()
                        } label: {
                            settingsRow(icon: "person.fill", title: "Profile Information")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            EmailSettingsView()
                        } label: {
                            settingsRow(icon: "envelope.fill", title: "Email Settings")
                        }
                        .buttonStyle(.plain)

                        settingsRow(icon: "lock.fill", title: "Password & Security")
                        Button {
                            authSession.signOut()
                        } label: {
                            settingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Log Out")
                        }

                        NavigationLink {
                            DeleteAccountView()
                        } label: {
                            settingsRow(
                                icon: "trash.fill",
                                title: "Delete Account",
                                tint: .red.opacity(0.9)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // bubbler system
                    settingsSection(title: "Bubble System") {
                        NavigationLink {
                            PreferencesSettingsView()
                        } label: {
                            settingsRow(icon: "slider.horizontal.3", title: "Recommendation Preferences")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer().frame(height: 30)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // section wrapper
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.6))
                .tracking(1)
            
            VStack(spacing: 12) {
                content()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
    }
    
    // row
    private func settingsRow(
        icon: String,
        title: String,
        tint: Color = .white.opacity(0.9)
    ) -> some View {
        
        HStack {
            
            Image(systemName: icon)
                .foregroundColor(tint.opacity(0.9))
                .frame(width: 22)
            
            Text(title)
                .foregroundColor(tint)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthSession())
}
