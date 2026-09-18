import SwiftUI

struct HGScreenHeader: View {
    var body: some View {
        HStack {
            headerButton("menu")
            Spacer()
            Text("폭염가드")
                .font(HGFont.bold(20, relativeTo: .title2))
                .foregroundStyle(HGColor.primaryText)
            Spacer()
            headerButton("bell")
        }
        .frame(height: 28)
    }

    private func headerButton(_ imageName: String) -> some View {
        Button {} label: {
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
