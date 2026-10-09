import SwiftUI

private struct HGNavigationTitle: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(HGFont.notoBold(20, relativeTo: .title2))
                        .foregroundStyle(HGColor.navigationTitle)
                }
            }
            .toolbarBackground(HGColor.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    func hgNavigationTitle(_ title: String) -> some View {
        modifier(HGNavigationTitle(title: title))
    }
}
