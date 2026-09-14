import SwiftUI

struct HGStatusPopup<Content: View, Actions: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            Text(title).font(HGFont.bold(20, relativeTo: .title2)).padding(.top, 18)
            content
            Spacer(minLength: 0)
            actions.padding(.bottom, 20)
        }
        .background(HGColor.popupBackground)
        .presentationBackground(HGColor.popupBackground)
        .presentationDetents([.height(683)])
        .presentationCornerRadius(40)
        .presentationDragIndicator(.hidden)
    }
}

struct HGPopupCard<Content: View>: View {
    var cornerRadius: CGFloat = 25
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(20).background(HGColor.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay { RoundedRectangle(cornerRadius: cornerRadius).stroke(HGColor.inputBorder, lineWidth: 1) }
    }
}

struct HGSecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(title, action: action).font(HGFont.medium(16)).frame(maxWidth: .infinity, minHeight: 48)
            .background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(HGColor.inputBorder, lineWidth: 1) }
    }
}
