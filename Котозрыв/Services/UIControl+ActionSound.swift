import UIKit
import ObjectiveC


extension UIApplication {

    private static let swizzleOnce: Void = {
        let cls = UIApplication.self
        let original = #selector(UIApplication.sendAction(_:to:from:for:))
        let swizzled = #selector(UIApplication.kz_sendAction(_:to:from:for:))

        guard let originalMethod = class_getInstanceMethod(cls, original),
              let swizzledMethod = class_getInstanceMethod(cls, swizzled) else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    static func enableActionSound() {
        _ = swizzleOnce
    }

    @objc fileprivate func kz_sendAction(_ action: Selector,
                                         to target: Any?,
                                         from sender: Any?,
                                         for event: UIEvent?) -> Bool {
        if let control = sender as? UIControl, !control.silentTap {
            SoundManager.shared.playAction()
        }
        return kz_sendAction(action, to: target, from: sender, for: event)
    }
}

extension UIControl {
    private static var silentTapKey: UInt8 = 0

    var silentTap: Bool {
        get { (objc_getAssociatedObject(self, &Self.silentTapKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &Self.silentTapKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
