//
//  SearchView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/13/26.
//
import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = SearchViewModel()

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
                        Button {
                            Task {
                                await viewModel.search(using: authSession)
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.75))
                        }
                        .disabled(viewModel.isLoading)
                        .accessibilityLabel("Search")

                        TextField("Search for a bubble...", text: $viewModel.searchText)
                            .foregroundColor(.white)
                            .tint(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit {
                                Task {
                                    await viewModel.search(using: authSession)
                                }
                            }

                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                                viewModel.clearResults()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.55))
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding()
                    .background(.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    )

                    if !viewModel.recentSearches.isEmpty {
                        recentSearchesSection
                    }

                    resultsSection

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 22)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task(id: authSession.userId) {
            viewModel.loadRecentSearches(for: authSession.userId)
        }
    }

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Searches")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(viewModel.recentSearches, id: \.self) { search in
                    Button {
                        Task {
                            await viewModel.runRecentSearch(search, using: authSession)
                        }
                    } label: {
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
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if viewModel.isLoading {
            stateCard(
                title: "Searching",
                message: "Looking for bubbles that match your query.",
                showsProgress: true
            )
        } else if let errorMessage = viewModel.errorMessage {
            stateCard(
                title: "Couldn't search",
                message: errorMessage
            )
        } else if viewModel.hasSearched {
            VStack(alignment: .leading, spacing: 14) {
                Text(viewModel.posts.isEmpty ? "No results" : "Results")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if viewModel.posts.isEmpty {
                    stateCard(
                        title: "Nothing matched",
                        message: "Try a different query or pick a recent search."
                    )
                } else {
                    VStack(spacing: 18) {
                        ForEach(viewModel.posts) { post in
                            PostCardView(
                                post: post,
                                onDeleted: {
                                    viewModel.removePost(id: post.id)
                                },
                                onEdited: { content in
                                    viewModel.updatePostContent(id: post.id, content: content)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private func stateCard(title: String, message: String, showsProgress: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if showsProgress {
                    ProgressView()
                        .tint(.white)
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            Text(message)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack {
        SearchView()
            .environmentObject(AuthSession())
    }
}
