//
//  HGFont.swift
//  heatguard-iOS
//

import SwiftUI

enum HGFont {
    enum Family: String {
        case pretendard = "Pretendard"
        case notoSansKR = "NotoSansKR"
    }

    static func notoRegular(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        custom(.regular, size: size, relativeTo: textStyle, family: .notoSansKR)
    }

    static func notoMedium(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        custom(.medium, size: size, relativeTo: textStyle, family: .notoSansKR)
    }

    static func notoBold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        custom(.bold, size: size, relativeTo: textStyle, family: .notoSansKR)
    }

    static func regular(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        custom(.regular, size: size, relativeTo: textStyle)
    }

    static func medium(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        custom(.medium, size: size, relativeTo: textStyle)
    }

    static func semiBold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        custom(.semiBold, size: size, relativeTo: textStyle)
    }

    static func bold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        custom(.bold, size: size, relativeTo: textStyle)
    }

    static let display = bold(32, relativeTo: .largeTitle)
    static let title = semiBold(24, relativeTo: .title)
    static let heading = semiBold(20, relativeTo: .title2)
    static let body = regular(16)
    static let bodyEmphasized = medium(16)
    static let caption = medium(12, relativeTo: .caption)
}

private extension HGFont {
    enum Weight: String {
        case regular = "Regular"
        case medium = "Medium"
        case semiBold = "SemiBold"
        case bold = "Bold"
    }

    static func custom(_ weight: Weight, size: CGFloat, relativeTo textStyle: Font.TextStyle, family: Family = .pretendard) -> Font {
        Font.custom("\(family.rawValue)-\(weight.rawValue)", size: size, relativeTo: textStyle)
    }
}
