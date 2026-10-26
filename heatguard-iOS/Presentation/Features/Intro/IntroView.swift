import SwiftUI

private struct IntroGlowLayout: Identifiable {
    let imageName: String
    let frameSize: CGSize
    let centerX: CGFloat
    let centerY: CGFloat
    let assetOverflow: CGFloat

    var id: String { imageName }

    var imageSize: CGSize {
        CGSize(
            width: frameSize.width + (assetOverflow * 2),
            height: frameSize.height + (assetOverflow * 2)
        )
    }
}

private enum IntroDesign {
    // Figma nodes 1262:952 and 1262:953 expand each glow asset by 80pt on every edge.
    static let glows = [
        IntroGlowLayout(
            imageName: "IntroGlowBlue",
            frameSize: CGSize(width: 300, height: 260),
            centerX: 0.174,
            centerY: 0.835,
            assetOverflow: 80
        ),
        IntroGlowLayout(
            imageName: "IntroGlowPeach",
            frameSize: CGSize(width: 260, height: 220),
            centerX: 0.821,
            centerY: 0.858,
            assetOverflow: 80
        )
    ]
}

struct IntroView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [.white, HGColor.introBackgroundEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(IntroDesign.glows) { glow in
                    Image(glow.imageName)
                        .resizable()
                        .frame(width: glow.imageSize.width, height: glow.imageSize.height)
                        .position(
                            x: geometry.size.width * glow.centerX,
                            y: geometry.size.height * glow.centerY
                        )
                }

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
