//
//  heatguard_iOSApp.swift
//  heatguard-iOS
//
//  Created by 이시우 on 9/13/26.
//

import SwiftUI

@main
struct HeatGuardApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isRestoringSession = true
    @State private var hasFinishedIntro = false
    @State private var isAuthenticated = false
    @State private var showsTeamFlow = false
    @State private var teamFlowHasPreviousScreen = false
    @State private var startsAccountRegistration = false
    @State private var pendingInvitationToken: String?
    @State private var restoredProfile: HGTeamProfile?

    var body: some Scene {
        WindowGroup {
            ZStack {
                rootView
                    .accessibilityHidden(scenePhase != .active)

                if scenePhase != .active {
                    privacyCover
                        .zIndex(1)
                }
            }
                .preferredColorScheme(.light)
                .task { await startApp() }
                .onOpenURL(perform: handleIncomingURL)
                .onReceive(NotificationCenter.default.publisher(for: .hgSessionExpired)) { notification in
                    handleSessionExpired(notification.object as? String)
                }
        }
    }

    private var privacyCover: some View {
        HGColor.appBackground
            .ignoresSafeArea()
            .overlay {
                Image("BrandIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("HeatGuard")
    }

    @ViewBuilder
    private var rootView: some View {
        NavigationStack {
            rootContent
                .navigationDestination(isPresented: $showsTeamFlow) {
                    teamFlowDestination
                }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if !hasFinishedIntro {
            IntroView()
        } else if isRestoringSession {
            ProgressView()
        } else if showsTeamFlow && !teamFlowHasPreviousScreen {
            HGColor.appBackground.ignoresSafeArea()
        } else if isAuthenticated {
            HomeView(
                initialProfile: restoredProfile,
                onSessionEnded: handleSessionEnded,
                onTeamSelectionRequested: {
                    startsAccountRegistration = false
                    teamFlowHasPreviousScreen = true
                    showsTeamFlow = true
                }
            )
        } else {
            LoginView(
                onAuthenticated: { _ in Task { await routeAuthenticatedSession() } },
                onSignUpTap: {
                    startsAccountRegistration = true
                    teamFlowHasPreviousScreen = true
                    showsTeamFlow = true
                }
            )
        }
    }

    private var teamFlowDestination: some View {
        TeamMembershipFlowView(
            linkToken: pendingInvitationToken,
            startsWithRegistration: startsAccountRegistration,
            onClose: closeTeamFlow,
            onAuthenticated: { _ in isAuthenticated = true },
            onTeamSelected: finishTeamSelection
        )
        .navigationBarBackButtonHidden(!teamFlowHasPreviousScreen)
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
            let session = try await HGAuthenticationService().restoreSession()
            restoredProfile = session?.profile
            isAuthenticated = session != nil
            if isAuthenticated { await routeToSelectedTeamIfNeeded() }
        } catch {
            isAuthenticated = false
        }
        isRestoringSession = false
    }

    @MainActor
    private func routeAuthenticatedSession() async {
        restoredProfile = nil
        isAuthenticated = true
        await routeToSelectedTeamIfNeeded()
    }

    @MainActor
    private func routeToSelectedTeamIfNeeded() async {
        do {
            let memberships = try await HGAuthenticationService().memberships()
            if let selectedTeamID = memberships.selectedTeamID,
               memberships.items.contains(where: { $0.teamID == selectedTeamID }) {
                teamFlowHasPreviousScreen = false
                showsTeamFlow = false
                return
            }
            if memberships.items.count == 1, let onlyMembership = memberships.items.first {
                try await HGAuthenticationService().selectMembership(teamID: onlyMembership.teamID)
                teamFlowHasPreviousScreen = false
                showsTeamFlow = false
                return
            }
            teamFlowHasPreviousScreen = false
            showsTeamFlow = true
        } catch {
            // Keep the authenticated worker in the team-selection flow so the API error is visible.
            teamFlowHasPreviousScreen = false
            showsTeamFlow = true
        }
    }

    @MainActor
    private func finishTeamSelection() {
        isAuthenticated = true
        showsTeamFlow = false
        teamFlowHasPreviousScreen = false
        startsAccountRegistration = false
        pendingInvitationToken = nil
    }

    @MainActor
    private func closeTeamFlow() {
        showsTeamFlow = false
        teamFlowHasPreviousScreen = false
        startsAccountRegistration = false
        pendingInvitationToken = nil
        if isAuthenticated {
            Task { await routeToSelectedTeamIfNeeded() }
        }
    }

    @MainActor
    private func handleSessionEnded() {
        HGAuthenticationService().endLocalSession()
        restoredProfile = nil
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
        teamFlowHasPreviousScreen = true
        showsTeamFlow = true
    }
}
