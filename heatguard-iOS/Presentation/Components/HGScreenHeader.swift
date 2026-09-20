import SwiftUI

struct HGScreenHeader: View {
    var onMenuTap: () -> Void = {}
    var onNotificationTap: () -> Void = {}

    var body: some View {
        HStack {
            headerButton("menu", action: onMenuTap)
            Spacer()
            Text("폭염가드")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(HGColor.primaryText)
            Spacer()
            headerButton("bell", action: onNotificationTap)
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
