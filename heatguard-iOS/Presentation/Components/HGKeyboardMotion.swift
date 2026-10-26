import SwiftUI
import UIKit

enum HGKeyboardMotion {
    static func overlapHeight(for notification: Notification) -> CGFloat {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return 0 }

        let screenMaxY = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.coordinateSpace.bounds.maxY }
            .first ?? frame.maxY

        return max(0, screenMaxY - frame.minY)
    }

    static func animation(for notification: Notification) -> Animation {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int

        return switch curve {
        case UIView.AnimationCurve.easeIn.rawValue:
            Animation.timingCurve(0.42, 0, 1, 1, duration: duration)
        case UIView.AnimationCurve.easeOut.rawValue:
            Animation.timingCurve(0, 0, 0.58, 1, duration: duration)
        case UIView.AnimationCurve.linear.rawValue:
            Animation.linear(duration: duration)
        default:
            Animation.easeInOut(duration: duration)
        }
    }
}
