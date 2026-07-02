import UIKit

enum SlideTransition: String, CaseIterable, Codable {
    case mixed
    case randomSelected
    case crossfade
    case slide
    case push
    case zoom
    case zoomOut
    case pushUp
    case pushDown
    case blur
    case flip

    var displayName: String {
        switch self {
        case .crossfade:      return "크로스페이드"
        case .slide:          return "슬라이드"
        case .push:           return "푸시"
        case .zoom:           return "줌 인"
        case .zoomOut:        return "줌 아웃"
        case .pushUp:         return "밀어올리기"
        case .pushDown:       return "내리기"
        case .blur:           return "블러"
        case .flip:           return "플립"
        case .mixed:          return "혼합(전체 순환)"
        case .randomSelected: return "랜덤 선택"
        }
    }

    static let concreteEffects: [SlideTransition] = [
        .crossfade, .slide, .push, .zoom, .zoomOut, .pushUp, .pushDown, .blur, .flip
    ]
    static let maxRandomSelection = 5
    private static let cycle: [SlideTransition] = concreteEffects

    func resolved(pool: [SlideTransition], index: Int) -> SlideTransition {
        if self == .randomSelected {
            let effects = pool.isEmpty ? [SlideTransition.crossfade] : pool
            var x = UInt64(bitPattern: Int64(index &+ 1))
            x = (x &* 0x9E3779B97F4A7C15) ^ (x >> 29)
            return effects[Int(x % UInt64(effects.count))]
        } else if self == .mixed {
            return SlideTransition.cycle[((index % SlideTransition.cycle.count) + SlideTransition.cycle.count) % SlideTransition.cycle.count]
        }
        return self
    }

    /// Apply UIKit transition from `fromView` to `toView` inside `container`.
    func apply(from fromView: UIView,
               to toView: UIView,
               in container: UIView,
               duration: TimeInterval,
               completion: @escaping () -> Void) {
        toView.frame = container.bounds
        switch self {
        case .crossfade, .mixed, .randomSelected:
            toView.alpha = 0
            container.addSubview(toView)
            UIView.animate(withDuration: duration, animations: {
                toView.alpha = 1
                fromView.alpha = 0
            }, completion: { _ in fromView.removeFromSuperview(); completion() })

        case .slide:
            toView.transform = CGAffineTransform(translationX: container.bounds.width, y: 0)
            container.addSubview(toView)
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
                toView.transform = .identity
                fromView.transform = CGAffineTransform(translationX: -container.bounds.width, y: 0)
            }, completion: { _ in fromView.removeFromSuperview(); fromView.transform = .identity; completion() })

        case .push:
            toView.transform = CGAffineTransform(translationX: container.bounds.width, y: 0)
            container.addSubview(toView)
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
                toView.transform = .identity
                fromView.transform = CGAffineTransform(translationX: -container.bounds.width * 0.3, y: 0)
            }, completion: { _ in fromView.removeFromSuperview(); fromView.transform = .identity; completion() })

        case .zoom:
            toView.alpha = 0
            toView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
            container.addSubview(toView)
            UIView.animate(withDuration: duration, animations: {
                toView.alpha = 1
                toView.transform = .identity
                fromView.alpha = 0
            }, completion: { _ in fromView.removeFromSuperview(); completion() })

        case .zoomOut:
            toView.alpha = 0
            toView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            container.addSubview(toView)
            UIView.animate(withDuration: duration, animations: {
                toView.alpha = 1
                toView.transform = .identity
                fromView.alpha = 0
            }, completion: { _ in fromView.removeFromSuperview(); completion() })

        case .pushUp:
            toView.transform = CGAffineTransform(translationX: 0, y: container.bounds.height)
            container.addSubview(toView)
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
                toView.transform = .identity
                fromView.transform = CGAffineTransform(translationX: 0, y: -container.bounds.height)
            }, completion: { _ in fromView.removeFromSuperview(); fromView.transform = .identity; completion() })

        case .pushDown:
            toView.transform = CGAffineTransform(translationX: 0, y: -container.bounds.height)
            container.addSubview(toView)
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
                toView.transform = .identity
                fromView.transform = CGAffineTransform(translationX: 0, y: container.bounds.height)
            }, completion: { _ in fromView.removeFromSuperview(); fromView.transform = .identity; completion() })

        case .blur:
            let blurView = UIVisualEffectView(effect: nil)
            blurView.frame = container.bounds
            container.addSubview(blurView)
            toView.alpha = 0
            container.addSubview(toView)
            UIView.animate(withDuration: duration * 0.5, animations: {
                blurView.effect = UIBlurEffect(style: .dark)
                fromView.alpha = 0
            }, completion: { _ in
                UIView.animate(withDuration: duration * 0.5, animations: {
                    blurView.effect = nil
                    toView.alpha = 1
                }, completion: { _ in
                    blurView.removeFromSuperview()
                    fromView.removeFromSuperview()
                    completion()
                })
            })

        case .flip:
            container.addSubview(toView)
            toView.alpha = 0
            var transform = CATransform3DIdentity
            transform.m34 = -1.0 / 500.0
            fromView.layer.transform = transform
            UIView.animateKeyframes(withDuration: duration, delay: 0, options: [], animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                    fromView.layer.transform = CATransform3DRotate(transform, .pi / 2, 0, 1, 0)
                    fromView.alpha = 0
                }
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                    toView.layer.transform = CATransform3DRotate(transform, 0, 0, 1, 0)
                    toView.alpha = 1
                }
            }, completion: { _ in
                fromView.layer.transform = CATransform3DIdentity
                toView.layer.transform = CATransform3DIdentity
                fromView.removeFromSuperview()
                completion()
            })
        }
    }
}
