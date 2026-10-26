import SwiftUI

struct HGMenuProfile: Equatable {
    let name: String
    let role: String
    let email: String

    init(name: String, role: String, email: String) {
        self.name = name
        self.role = role
        self.email = email
    }

    static let preview = HGMenuProfile(
        name: "사용자 정보 없음",
        role: "",
        email: ""
    )

    nonisolated init(profile: HGTeamProfile) {
        name = profile.name
        let roleTitle = profile.role == "TEAM_MEMBER" ? "현장작업자" : profile.role
        role = [profile.companyName, roleTitle].compactMap { $0 }.joined(separator: " · ")
        email = profile.email
    }

    var initial: String {
        String(name.prefix(1))
    }
}

struct HGMenuDrawer: View {
    private enum Metrics {
        static let width: CGFloat = 300
        static let horizontalInset: CGFloat = 24
        static let topInset: CGFloat = 86
        static let bottomInset: CGFloat = 48
        static let rowHeight: CGFloat = 52
        static let dismissThreshold: CGFloat = 0.35
    }

    @GestureState private var dragOffset: CGFloat = 0

    let profile: HGMenuProfile
    let isPresented: Bool
    let onDismiss: () -> Void
    let onHome: () -> Void
    let onTeamSelection: () -> Void
    let onProfileEdit: () -> Void
    let onInquiry: () -> Void
    let onLogout: () -> Void
    let onWithdrawal: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let drawerWidth = min(proxy.size.width, Metrics.width)
            let restingOffset = isPresented ? 0 : -drawerWidth
            let drawerOffset = max(-drawerWidth, restingOffset + min(dragOffset, 0))

            drawerContent
                .padding(.horizontal, Metrics.horizontalInset)
                .padding(.top, Metrics.topInset)
                .padding(.bottom, Metrics.bottomInset)
                .frame(width: drawerWidth)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background {
                    HGColor.surface.ignoresSafeArea()
                }
                .offset(x: drawerOffset)
                .gesture(dismissDragGesture(drawerWidth: drawerWidth))
                .animation(.easeInOut(duration: 0.24), value: isPresented)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .ignoresSafeArea()
    }

    private var drawerContent: some View {
        VStack(spacing: 0) {
            profileSection
            divider
            menuSection
            siteSelectionSection
            divider
            accountActions
        }
    }

    private var profileSection: some View {
        HStack(spacing: 12) {
            Text(profile.initial)
                .font(HGFont.bold(18, relativeTo: .title3))
                .foregroundStyle(HGColor.primary)
                .frame(width: 48, height: 48)
                .background(HGColor.photoSelectionBackground, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(HGFont.bold(18, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                if !profile.role.isEmpty {
                    Text(profile.role)
                        .font(HGFont.regular(13, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                }
                if !profile.email.isEmpty {
                    Text(profile.email)
                        .font(HGFont.regular(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.placeholder)
                }
            }
            Spacer()
        }
        .padding(.bottom, 24)
    }

    private var menuSection: some View {
        VStack(spacing: 0) {
            drawerRow(title: "홈", action: onHome)
            drawerRow(title: "내 정보 수정", action: onProfileEdit)
            drawerRow(title: "문의하기", action: onInquiry)
        }
        .padding(.top, 8)
    }

    private var siteSelectionSection: some View {
        VStack(spacing: 0) {
            drawerRow(title: "현장선택", action: onTeamSelection)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var accountActions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onLogout) {
                Text("로그아웃")
                    .font(HGFont.semiBold(15, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 15)
            .frame(height: 48, alignment: .topLeading)

            Button(action: onWithdrawal) {
                Text("회원탈퇴")
                    .font(HGFont.regular(13, relativeTo: .caption))
                    .foregroundStyle(HGColor.placeholder)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        HGColor.menuDivider
            .frame(height: 1)
    }

    private func drawerRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(HGFont.medium(15, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                Spacer()
                Text("›")
                    .font(HGFont.regular(18, relativeTo: .title3))
                    .foregroundStyle(HGColor.placeholder)
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dismissDragGesture(drawerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragOffset) { value, state, _ in
                guard value.translation.width < 0 else { return }
                state = value.translation.width
            }
            .onEnded { value in
                let shouldDismiss = value.translation.width < -drawerWidth * Metrics.dismissThreshold
                    || value.predictedEndTranslation.width < -drawerWidth * Metrics.dismissThreshold

                if shouldDismiss {
                    onDismiss()
                }
            }
    }
}

#Preview {
    HGMenuDrawer(
        profile: .preview,
        isPresented: true,
        onDismiss: {},
        onHome: {},
        onTeamSelection: {},
        onProfileEdit: {},
        onInquiry: {},
        onLogout: {},
        onWithdrawal: {}
    )
}
