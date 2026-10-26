import SwiftUI

struct HGNotificationButton: View {
    let notificationCount: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(HGColor.primaryText)
                    .frame(width: 28, height: 28)

                if let notificationCount, notificationCount > 0 {
                    Text(notificationCount > 99 ? "99+" : String(notificationCount))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 15, minHeight: 15)
                        .background(HGColor.error, in: Capsule())
                        .overlay(Capsule().stroke(HGColor.appBackground, lineWidth: 1.5))
                        .offset(x: 7, y: -6)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(notificationCount.map { "알림, 읽지 않은 알림 \($0)개" } ?? "알림")
    }
}

private struct HGRouteNavigationHeader: ViewModifier {
    let title: String
    let notificationCount: Int?
    let onNotificationsTap: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(HGFont.bold(20, relativeTo: .title2))
                        .foregroundStyle(HGColor.navigationTitle)
                }
                if let onNotificationsTap {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HGNotificationButton(notificationCount: notificationCount, action: onNotificationsTap)
                    }
                }
            }
            .toolbarBackground(HGColor.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    func hgRouteNavigationHeader(
        title: String = "폭염가드",
        notificationCount: Int? = nil,
        onNotificationsTap: (() -> Void)? = nil
    ) -> some View {
        modifier(
            HGRouteNavigationHeader(
                title: title,
                notificationCount: notificationCount,
                onNotificationsTap: onNotificationsTap
            )
        )
    }
}
