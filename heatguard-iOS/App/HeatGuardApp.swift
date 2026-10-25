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
    @State private var showsAppAccountFlow = false
    @State private var startsAccountRegistration = false
    @State private var selectedAppSite: HGAppSite?
    @State private var pendingLinkToken: String?

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
        } else if showsAppAccountFlow {
            NavigationStack {
                AppAccountFlowView(
                    linkToken: pendingLinkToken,
                    startsWithRegistration: startsAccountRegistration,
                    onClose: {
                        showsAppAccountFlow = false
                        startsAccountRegistration = false
                        pendingLinkToken = nil
                    },
                    onSiteSelected: { site in
                        selectedAppSite = site
                        showsAppAccountFlow = false
                        startsAccountRegistration = false
                    },
                    onSiteUnlinked: { siteID in
                        if selectedAppSite?.id == siteID { selectedAppSite = nil }
                    },
                    onLinkClaimed: { pendingLinkToken = nil }
                )
            }
        } else if let selectedAppSite {
            AppSiteDashboardView(
                site: selectedAppSite,
                onChangeSite: { showsAppAccountFlow = true },
                onLogout: { Task { await logoutAppAccount() } }
            )
        } else if isAuthenticated {
            HomeView(onSessionEnded: handleTeamSessionEnded)
        } else {
            LoginView(
                onAuthenticated: { _ in isAuthenticated = true },
                onSignUpTap: {
                    startsAccountRegistration = true
                    showsAppAccountFlow = true
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
        isAuthenticated = (try? await HGAuthenticationService().restoreSession()) != nil
        if !isAuthenticated && !showsAppAccountFlow {
            let service = HGAppSiteLinkingService()
            if (try? await service.restoreSession()) == true {
                await restoreSelectedAppSite(using: service)
            }
        }
        isRestoringSession = false
    }

    @MainActor
    private func restoreSelectedAppSite(using service: HGAppSiteLinkingService) async {
        let sites: [HGAppSite]
        do {
            sites = try await service.fetchSites()
        } catch {
            showsAppAccountFlow = true
            return
        }

        let selectedID = UserDefaults.standard.string(forKey: "selected-app-site-id")
        guard let selectedID, let site = sites.first(where: { $0.id == selectedID }) else {
            if selectedID != nil { UserDefaults.standard.removeObject(forKey: "selected-app-site-id") }
            showsAppAccountFlow = true
            return
        }

        do {
            _ = try await service.select(siteID: selectedID)
            selectedAppSite = site
        } catch let error as HGAPIError {
            if case let .server(_, statusCode, _) = error, [403, 404].contains(statusCode) {
                UserDefaults.standard.removeObject(forKey: "selected-app-site-id")
                showsAppAccountFlow = true
            } else {
                selectedAppSite = site
            }
        } catch {
            selectedAppSite = site
        }
    }

    @MainActor
    private func logoutAppAccount() async {
        UserDefaults.standard.removeObject(forKey: "selected-app-site-id")
        selectedAppSite = nil
        showsAppAccountFlow = false
        await HGAppSiteLinkingService().logout()
    }

    @MainActor
    private func handleTeamSessionEnded() {
        isAuthenticated = false
        Task { await logoutAppAccount() }
    }

    @MainActor
    private func handleSessionExpired(_ expiredToken: String?) {
        guard let expiredToken else { return }
        if (try? HGAuthTokenStore.shared.load()) == expiredToken {
            HGAuthenticationService().endLocalSession(clearDraft: false)
            isAuthenticated = false
        } else if (try? HGAuthTokenStore(account: "app-session-access-token").load()) == expiredToken {
            Task { await logoutAppAccount() }
        }
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
