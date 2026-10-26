import SwiftUI

struct HGScreenHeader: View {
    var title = "현장가드"
    var onMenuTap: () -> Void = {}
    var notificationCount: Int?
    var onNotificationsTap: (() -> Void)?

    var body: some View {
        HStack {
            headerButton("menu", action: onMenuTap)
                .accessibilityLabel("메뉴")
            Spacer()
            Text(title)
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(HGColor.primaryText)
            Spacer()
            if let onNotificationsTap {
                HGNotificationButton(notificationCount: notificationCount, action: onNotificationsTap)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .frame(height: 44)
    }

    private func headerButton(_ imageName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HGScreenHeader()
        .padding()
}
