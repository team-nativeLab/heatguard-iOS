import SwiftUI

struct IntroView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [.white, HGColor.introBackgroundEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Ellipse()
                    .fill(Color(red: 191 / 255, green: 217 / 255, blue: 1).opacity(0.6))
                    .frame(width: 300, height: 260)
                    .blur(radius: 40)
                    .position(x: geometry.size.width * 0.174, y: geometry.size.height * 0.835)

                Ellipse()
                    .fill(Color(red: 1, green: 216 / 255, blue: 194 / 255).opacity(0.55))
                    .frame(width: 260, height: 220)
                    .blur(radius: 40)
                    .position(x: geometry.size.width * 0.821, y: geometry.size.height * 0.858)

                brand
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.474)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("intro-screen")
    }

    private var brand: some View {
        VStack(spacing: 0) {
            Image("IntroBrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .padding(.bottom, 20)

            Text("폭염가드")
                .font(HGFont.bold(32, relativeTo: .largeTitle))
                .foregroundStyle(HGColor.introTitle)
                .padding(.bottom, 8)

            Text("폭염 속 현장의 안전을 지키는\n가장 빠른 방법")
                .font(HGFont.regular(15))
                .foregroundStyle(HGColor.introSubtitle)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}
