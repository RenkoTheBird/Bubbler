//
//  CreateAccountView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/11/26.
//

import Combine
import SwiftUI

struct CreateAccountView: View {
    @EnvironmentObject private var authSession: AuthSession

    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var dateOfBirth: Date = Self.defaultBirthDate

    private static var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    private var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let earliest = calendar.date(byAdding: .year, value: -120, to: Date()) ?? Date.distantPast
        return earliest...Date()
    }

    private var isOldEnough: Bool {
        AgeGate.isOldEnough(dateOfBirth: dateOfBirth)
    }

    private var ageGateError: String? {
        isOldEnough ? nil : AgeGate.underageMessage
    }

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

            ScrollView {
                VStack(spacing: 22) {

                    Spacer(minLength: 24)

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

                    // Username
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)

                        TextField("Choose a username", text: $username)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(14)
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

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
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                    }

                    // Date of birth
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date of birth")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)

                        DatePicker(
                            "Date of birth",
                            selection: $dateOfBirth,
                            in: birthDateRange,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(14)
                        .colorScheme(.dark)
                        .accessibilityLabel("Date of birth")

                        if let ageGateError {
                            Text(ageGateError)
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("ageGateError")
                        }
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

                    if let authError = authSession.authError {
                        Text(authError)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }

                    Text(agreementText)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .tint(.white)
                        .padding(.top, 4)

                    // Create account button
                    Button(action: {
                        Task {
                            await authSession.createAccount(
                                username: username,
                                email: email,
                                password: password,
                                confirmPassword: confirmPassword,
                                dateOfBirth: dateOfBirth
                            )
                        }
                    }) {
                        Group {
                            if authSession.isWorking {
                                ProgressView()
                                    .tint(.blue)
                            } else {
                                Text("Create Account")
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
                    .disabled(authSession.isWorking || !isOldEnough)
                    .opacity(isOldEnough ? 1 : 0.55)
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

                    Spacer(minLength: 24)

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

    private var agreementText: AttributedString {
        var text = AttributedString("By signing up, you agree to Bubbler's ")

        var terms = AttributedString("Terms of Use")
        terms.link = URL(string: "bubbler://terms")
        terms.underlineStyle = .single

        let connector = AttributedString(" and ")

        var privacy = AttributedString("Privacy Policy")
        privacy.link = URL(string: "bubbler://privacy")
        privacy.underlineStyle = .single

        text.append(terms)
        text.append(connector)
        text.append(privacy)
        return text
    }
}

#Preview {
    CreateAccountView()
        .environmentObject(AuthSession())
}
