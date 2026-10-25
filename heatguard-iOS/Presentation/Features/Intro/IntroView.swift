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

                Image("IntroBlueGlow")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 1.14)
                    .position(x: geometry.size.width * 0.17, y: geometry.size.height * 0.84)

                Image("IntroWarmGlow")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 1.04)
                    .position(x: geometry.size.width * 0.82, y: geometry.size.height * 0.86)

                brand
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.474)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
        .accessibilityIdentifier("intro-screen")
    }

    private var brand: some View {
        VStack(spacing: 0) {
            Image("BrandIcon")
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
