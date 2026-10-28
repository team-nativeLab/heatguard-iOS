//
//  heatguard_iOSApp.swift
//  heatguard-iOS
//
//  Created by 이시우 on 9/13/26.
//

import SwiftUI

@main
struct HeatGuardApp: App {
    @State private var isRestoringSession = true
    @State private var hasFinishedIntro = false
    @State private var isAuthenticated = false
    @State private var showsTeamFlow = false
    @State private var startsAccountRegistration = false
    @State private var pendingInvitationToken: String?

    var body: some Scene {
        WindowGroup {
            rootView
                .preferredColorScheme(.light)
                .task { await startApp() }
                .onOpenURL(perform: handleIncomingURL)
                .onReceive(NotificationCenter.default.publisher(for: .hgSessionExpired)) { notification in
                    handleSessionExpired(notification.object as? String)
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if !hasFinishedIntro {
            IntroView()
        } else if isRestoringSession {
            ProgressView()
        } else if showsTeamFlow {
            NavigationStack {
                TeamMembershipFlowView(
                    linkToken: pendingInvitationToken,
                    startsWithRegistration: startsAccountRegistration,
                    onClose: closeTeamFlow,
                    onAuthenticated: { _ in isAuthenticated = true },
                    onTeamSelected: finishTeamSelection
                )
            }
        } else if isAuthenticated {
            HomeView(
                onSessionEnded: handleSessionEnded,
                onTeamSelectionRequested: { showsTeamFlow = true }
            )
        } else {
            LoginView(
                onAuthenticated: { _ in Task { await routeAuthenticatedSession() } },
                onSignUpTap: {
                    startsAccountRegistration = true
                    showsTeamFlow = true
                }
            )
        }
    }

    @MainActor
    private func startApp() async {
        async let introDuration: Void = waitForIntroDuration()
        await restoreSession()
        await introDuration
        hasFinishedIntro = true
    }

    private func waitForIntroDuration() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }

    @MainActor
    private func restoreSession() async {
        try? HGAuthTokenStore(account: "app-session-access-token").clear()
        UserDefaults.standard.removeObject(forKey: "selected-app-site-id")
        do {
            isAuthenticated = (try await HGAuthenticationService().restoreSession()) != nil
            if isAuthenticated { await routeToSelectedTeamIfNeeded() }
        } catch {
            isAuthenticated = false
        }
        isRestoringSession = false
    }

    @MainActor
    private func routeAuthenticatedSession() async {
        isAuthenticated = true
        await routeToSelectedTeamIfNeeded()
    }

    @MainActor
    private func routeToSelectedTeamIfNeeded() async {
        do {
            let memberships = try await HGAuthenticationService().memberships()
            if let selectedTeamID = memberships.selectedTeamID,
               memberships.items.contains(where: { $0.teamID == selectedTeamID }) {
                showsTeamFlow = false
                return
            }
            if memberships.items.count == 1, let onlyMembership = memberships.items.first {
                try await HGAuthenticationService().selectMembership(teamID: onlyMembership.teamID)
                showsTeamFlow = false
                return
            }
            showsTeamFlow = true
        } catch {
            // Keep the authenticated worker in the team-selection flow so the API error is visible.
            showsTeamFlow = true
        }
    }

    @MainActor
    private func finishTeamSelection() {
        isAuthenticated = true
        showsTeamFlow = false
        startsAccountRegistration = false
        pendingInvitationToken = nil
    }

    @MainActor
    private func closeTeamFlow() {
        showsTeamFlow = false
        startsAccountRegistration = false
        pendingInvitationToken = nil
        if isAuthenticated {
            Task { await routeToSelectedTeamIfNeeded() }
        }
    }

    @MainActor
    private func handleSessionEnded() {
        HGAuthenticationService().endLocalSession()
        isAuthenticated = false
        showsTeamFlow = false
    }

    @MainActor
    private func handleSessionExpired(_ expiredToken: String?) {
        guard let expiredToken, (try? HGAuthTokenStore.shared.load()) == expiredToken else { return }
        HGAuthenticationService().endLocalSession(clearDraft: false)
        isAuthenticated = false
        showsTeamFlow = false
    }

    private func handleIncomingURL(_ url: URL) {
        guard ["heatguard", "heartguard"].contains(url.scheme?.lowercased() ?? ""),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        let token: String?
        if url.host == "team" {
            let path = url.pathComponents.dropFirst()
            guard path.count == 2, path.first == "invitations" else { return }
            token = path.last
        } else if ["link", "team-invite"].contains(url.host ?? "") {
            token = components.queryItems?.first(where: { $0.name == "token" })?.value
                ?? url.pathComponents.dropFirst().first
        } else {
            return
        }

        guard let token, !token.isEmpty else { return }
        pendingInvitationToken = token
        startsAccountRegistration = false
        showsTeamFlow = true
    }
}
