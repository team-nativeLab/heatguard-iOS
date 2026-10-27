import SwiftUI

struct HGRegistrationProgress: View {
    let step: Int
    let title: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { index in
                    segment(at: index)
                }
            }
            .accessibilityHidden(true)

            Text("\(step) / 3 · \(title)")
                .font(HGFont.medium(11, relativeTo: .caption))
                .foregroundStyle(HGColor.primary)
        }
        .accessibilityElement(children: .combine)
        .onAppear { hasAppeared = true }
    }

    private func segment(at index: Int) -> some View {
        let isFilled = hasAppeared && index <= step

        return Capsule()
            .fill(HGColor.menuDivider)
            .overlay {
                Capsule()
                    .fill(HGColor.primary)
                    .scaleEffect(x: isFilled ? 1 : 0, y: 1, anchor: .leading)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.38), value: isFilled)
            }
            .frame(height: 4)
    }
}

#Preview {
    HGRegistrationProgress(step: 2, title: "이메일 인증")
        .padding(24)
}
