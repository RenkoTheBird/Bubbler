//
//  CreateAccountView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/11/26.
//

import SwiftUI

struct CreateAccountView: View {
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    var body: some View {
        ZStack {
            
            // same gradient background
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
                
                // Header
                VStack(spacing: 18) {
                    
                    // reuse logo for consistency
                    BubblerLogoView()
                        .frame(width: 100, height: 100)
                    
                    Text("Create Account")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Join your interest bubbles")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.bottom, 25)
                
                // Email
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                    
                    TextField("Enter your email", text: $email)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(14)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                
                // Password
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                    
                    SecureField("Create a password", text: $password)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(14)
                        .foregroundColor(.white)
                }
                
                // Confirm Password
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                    
                    SecureField("Re-enter your password", text: $confirmPassword)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(14)
                        .foregroundColor(.white)
                }
                
                // Create account button
                Button(action: {
                    print("Create account tapped")
                }) {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 10)
                
                // Back to login
                HStack {
                    Text("Already have an account?")
                        .foregroundColor(.white.opacity(0.8))
                    
                    NavigationLink {
                        LoginView()
                    } label: {
                        Text("Log in")
                            .bold()
                    }
                    .foregroundColor(.white)
                }
                .padding(.top, 8)
                
                Spacer()
                
                // footer
                Text("Your feed, shaped by your interests")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 28)
        }
    }
}

#Preview {
    CreateAccountView()
}
