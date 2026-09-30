import SwiftUI

struct HGScreenHeader: View {
    var onMenuTap: () -> Void = {}
    var notificationCount: Int? = nil
    var onNotificationsTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            headerButton("menu", action: onMenuTap)
            Spacer()
            Text("폭염가드")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(HGColor.primaryText)
            Spacer()
            if let onNotificationsTap {
                Button(action: onNotificationsTap) {
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
                }
                .buttonStyle(.plain)
                .accessibilityLabel(notificationCount.map { "알림, 읽지 않은 알림 \($0)개" } ?? "알림")
            } else {
                Color.clear.frame(width: 28, height: 28)
            }
        }
        .frame(height: 28)
    }

    private func headerButton(_ imageName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HGScreenHeader()
        .padding()
}
