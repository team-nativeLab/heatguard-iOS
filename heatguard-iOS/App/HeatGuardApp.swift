//
//  heatguard_iOSApp.swift
//  heatguard-iOS
//
//  Created by 이시우 on 9/13/26.
//

import SwiftUI

@main
struct heatguard_iOSApp: App {
    @State private var isRestoringSession = true
    @State private var isAuthenticated = false
    @State private var showsAppAccountFlow = false
    @State private var pendingLinkToken: String?

    var body: some Scene {
        WindowGroup {
            rootView
                .preferredColorScheme(.light)
                .task { await restoreSession() }
                .onOpenURL(perform: handleIncomingURL)
                .onReceive(NotificationCenter.default.publisher(for: .hgSessionExpired)) { notification in
                    guard let expiredToken = notification.object as? String,
                          (try? HGAuthTokenStore.shared.load()) == expiredToken else { return }
                    HGAuthenticationService().endLocalSession(clearDraft: false)
                    isAuthenticated = false
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if isRestoringSession {
            ProgressView()
        } else if showsAppAccountFlow {
            NavigationStack {
                AppAccountFlowView(linkToken: pendingLinkToken) {
                    showsAppAccountFlow = false
                    pendingLinkToken = nil
                }
            }
        } else if isAuthenticated {
            HomeView(onSessionEnded: { isAuthenticated = false })
        } else {
            LoginView(
                onAuthenticated: { _ in isAuthenticated = true },
                onAppAccountTap: { showsAppAccountFlow = true }
            )
        }
    }

    @MainActor
    private func restoreSession() async {
        isAuthenticated = (try? await HGAuthenticationService().restoreSession()) != nil
        if !isAuthenticated && !showsAppAccountFlow {
            showsAppAccountFlow = (try? await HGAppSiteLinkingService().restoreSession()) == true
        }
        isRestoringSession = false
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "heatguard",
              url.host == "link",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else { return }
        pendingLinkToken = token
        showsAppAccountFlow = true
    }
}
