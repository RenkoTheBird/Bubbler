//
//  LoginView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/11/26.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var backendConnection: BackendConnection
    
    @State private var email: String = ""
    @State private var password: String = ""
    
    var body: some View {
        ZStack {
            
            // Blue gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(1.8),
                    Color.cyan.opacity(0.7),
                    Color.blue.opacity(1.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 22) {
                
                Spacer()
                
                // Logo and Title Section
                VStack(spacing: 18) {
                    
                    // Logo here
                    BubblerLogoView()
                        .frame(width: 120, height: 120)
                    
                    Text("Bubbler")
                        .font(.system(size: 50, weight: .black, design: .rounded))
                        .kerning(2)
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.3), radius: 10)
                    
                    
                    
                    Text("See what you actually care about")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))

                    backendStatus
                }
                .padding(.bottom, 30)
                
                // Email field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                    
                    TextField("Enter your email", text: $email)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(14)
                        .foregroundColor(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                }
                
                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                    
                    SecureField("Enter your password", text: $password)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(14)
                        .foregroundColor(.white)
                }

                if let authError = authSession.authError {
                    Text(authError)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                }
                
                // login button
                Button(action: {
                    Task {
                        await authSession.signIn(email: email, password: password)
                    }
                }) {
                    Group {
                        if authSession.isWorking {
                            ProgressView()
                                .tint(.blue)
                        } else {
                            Text("Log In")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .disabled(authSession.isWorking)
                .padding(.top, 10)
                
                // Sign up
                HStack {
                    Text("New to Bubbler?")
                        .foregroundColor(.white.opacity(0.8))
                    
                    NavigationLink {
                        CreateAccountView()
                    } label: {
                        Text("Create account")
                            .foregroundColor(.white)
                            .bold()
                    }
                    .foregroundColor(.white)
                    .bold()
                }
                .padding(.top, 8)
                
                Spacer()
                
                // small footer glow text
                Text("Powered by interest-based bubbles")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 28)
        }
        .task {
            await backendConnection.refresh()
        }
    }

    private var backendStatus: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(backendStatusColor)
                .frame(width: 8, height: 8)

            Text(backendStatusText)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))
        }
        .accessibilityElement(children: .combine)
    }

    private var backendStatusText: String {
        switch backendConnection.state {
        case .checking:
            return "Checking backend"
        case .connected:
            return "Backend connected"
        case .unavailable:
            return "Backend unavailable"
        }
    }

    private var backendStatusColor: Color {
        switch backendConnection.state {
        case .checking:
            return .yellow
        case .connected:
            return .green
        case .unavailable:
            return .red
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthSession())
        .environmentObject(BackendConnection())
}
