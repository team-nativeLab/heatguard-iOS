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
        static let maximumWidth: CGFloat = 320
        static let widthRatio: CGFloat = 0.78
        static let dismissThreshold: CGFloat = 0.35
    }

    @GestureState private var dragOffset: CGFloat = 0

    let profile: HGMenuProfile
    let isPresented: Bool
    let onDismiss: () -> Void
    let onProfileEdit: () -> Void
    let onInquiry: () -> Void
    let onLogout: () -> Void
    let onWithdrawal: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let drawerWidth = min(proxy.size.width * Metrics.widthRatio, Metrics.maximumWidth)
            let restingOffset = isPresented ? 0 : -drawerWidth
            let drawerOffset = max(-drawerWidth, restingOffset + min(dragOffset, 0))

            drawerContent
                .padding(.top, proxy.safeAreaInsets.top)
                .frame(width: drawerWidth)
                .frame(maxHeight: .infinity)
                .background(HGColor.surface)
                .offset(x: drawerOffset)
                .gesture(dismissDragGesture(drawerWidth: drawerWidth))
                .animation(.easeInOut(duration: 0.24), value: isPresented)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var drawerContent: some View {
        VStack(spacing: 0) {
            profileSection
            Divider()
            menuSection
            Spacer()
            Divider()
            accountActions
        }
    }

    private var profileSection: some View {
        HStack(spacing: 12) {
            Text(profile.initial)
                .font(HGFont.notoBold(18, relativeTo: .title3))
                .foregroundStyle(HGColor.primary)
                .frame(width: 48, height: 48)
                .background(HGColor.homeMetricIconBackground, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(HGFont.notoBold(18, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                if !profile.role.isEmpty {
                    Text(profile.role)
                        .font(HGFont.notoRegular(13, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                }
                if !profile.email.isEmpty {
                    Text(profile.email)
                        .font(HGFont.notoRegular(12, relativeTo: .caption))
                        .foregroundStyle(HGColor.secondaryText)
                }
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HGColor.secondaryText)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("메뉴 닫기")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }

    private var menuSection: some View {
        VStack(spacing: 0) {
            drawerRow(title: "내 정보 수정", action: onProfileEdit)
            drawerRow(title: "문의하기", action: onInquiry)
        }
        .padding(.top, 9)
    }

    private var accountActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("로그아웃", action: onLogout)
                .font(HGFont.notoBold(14, relativeTo: .subheadline))
                .foregroundStyle(HGColor.primaryText)

            Button("회원탈퇴", action: onWithdrawal)
                .font(HGFont.notoRegular(12, relativeTo: .caption))
                .foregroundStyle(HGColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }

    private func drawerRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(HGFont.notoMedium(15, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                Spacer()
                Image("ChevronRight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 24)
            .frame(height: 53)
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
        onProfileEdit: {},
        onInquiry: {},
        onLogout: {},
        onWithdrawal: {}
    )
}
