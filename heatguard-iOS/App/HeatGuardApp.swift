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
                .task { await restoreSession() }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if isRestoringSession {
            ProgressView()
        } else if isAuthenticated {
            HomeView()
        } else {
            LoginView { _ in isAuthenticated = true }
        }
    }

    @MainActor
    private func restoreSession() async {
        isAuthenticated = (try? await HGAuthenticationService().restoreSession()) != nil
        isRestoringSession = false
    }
}
