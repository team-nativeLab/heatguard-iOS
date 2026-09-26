import SwiftUI

struct HGMenuProfile: Equatable {
    let name: String
    let role: String
    let email: String

    static let preview = HGMenuProfile(
        name: "김현장",
        role: "이음산업건설 · 현장작업자",
        email: "worker@ieum.co.kr"
    )

    var initial: String {
        String(name.prefix(1))
    }
}

struct HGMenuDrawer: View {
    let profile: HGMenuProfile
    let onDismiss: () -> Void
    let onProfileEdit: () -> Void
    let onInquiry: () -> Void
    let onLogout: () -> Void
    let onWithdrawal: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.black.opacity(0.35)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)

                drawerContent
                    .padding(.top, proxy.safeAreaInsets.top)
                    .frame(width: min(proxy.size.width * 0.78, 320))
                    .frame(maxHeight: .infinity)
                    .background(HGColor.surface)
            }
            .ignoresSafeArea()
        }
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
                .font(HGFont.bold(18, relativeTo: .title3))
                .foregroundStyle(HGColor.primary)
                .frame(width: 48, height: 48)
                .background(HGColor.homeMetricIconBackground, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(HGFont.bold(15, relativeTo: .subheadline))
                    .foregroundStyle(HGColor.primaryText)
                Text(profile.role)
                    .font(HGFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(HGColor.secondaryText)
                Text(profile.email)
                    .font(HGFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(HGColor.secondaryText)
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
                .font(HGFont.semiBold(14, relativeTo: .subheadline))
                .foregroundStyle(HGColor.primaryText)

            Button("회원탈퇴", action: onWithdrawal)
                .font(HGFont.regular(12, relativeTo: .caption))
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
                    .font(HGFont.medium(14, relativeTo: .subheadline))
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
}

#Preview {
    HGMenuDrawer(
        profile: .preview,
        onDismiss: {},
        onProfileEdit: {},
        onInquiry: {},
        onLogout: {},
        onWithdrawal: {}
    )
}
