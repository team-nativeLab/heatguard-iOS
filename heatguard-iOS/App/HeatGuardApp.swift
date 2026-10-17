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

    var body: some Scene {
        WindowGroup {
            rootView
                .preferredColorScheme(.light)
                .task {
                    #if DEBUG
                    if isChecklistUITesting {
                        isRestoringSession = false
                        return
                    }
                    #endif
                    await restoreSession()
                }
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
        #if DEBUG
        if isChecklistUITesting {
            NavigationStack {
                ChecklistView(
                    times: ["08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00", "22:00"],
                    siteName: "인천 복합물류센터 신축",
                    teamName: "A팀",
                    service: HGChecklistUITestService()
                )
            }
        } else {
            standardRootView
        }
        #else
        standardRootView
        #endif
    }

    @ViewBuilder
    private var standardRootView: some View {
        if isRestoringSession {
            ProgressView()
        } else if isAuthenticated {
            HomeView(onSessionEnded: { isAuthenticated = false })
        } else {
            LoginView { _ in isAuthenticated = true }
        }
    }

    #if DEBUG
    private var isChecklistUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-checklist")
    }
    #endif

    @MainActor
    private func restoreSession() async {
        isAuthenticated = (try? await HGAuthenticationService().restoreSession()) != nil
        isRestoringSession = false
    }
}
