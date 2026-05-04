import CoreGraphics
import Foundation

public enum CodexPetAnimationSpeedPreset: String, CaseIterable, Identifiable {
    case calm
    case natural
    case lively

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .calm:
            return "ゆっくり"
        case .natural:
            return "標準"
        case .lively:
            return "元気"
        }
    }

    public func durationScale(for animation: CodexPetSpriteView.Animation) -> TimeInterval {
        switch self {
        case .calm:
            switch animation {
            case .idle:
                return 1.7
            case .runningRight, .runningLeft, .running:
                return 1.75
            case .waving:
                return 1.45
            case .jumping:
                return 1.4
            case .failed:
                return 1.55
            case .waiting:
                return 1.75
            case .review:
                return 1.6
            }
        case .natural:
            switch animation {
            case .idle:
                return 1.2
            case .runningRight, .runningLeft, .running:
                return 1.15
            case .waving:
                return 1.05
            case .jumping:
                return 1.0
            case .failed:
                return 1.2
            case .waiting:
                return 1.25
            case .review:
                return 1.15
            }
        case .lively:
            switch animation {
            case .idle:
                return 1.0
            case .runningRight, .runningLeft, .running:
                return 0.92
            case .waving:
                return 0.9
            case .jumping:
                return 0.86
            case .failed:
                return 1.0
            case .waiting:
                return 1.05
            case .review:
                return 0.95
            }
        }
    }

    public var movementDurationScale: TimeInterval {
        switch self {
        case .calm:
            return 1.65
        case .natural:
            return 1.0
        case .lively:
            return 0.82
        }
    }
}

public enum CodexPetSizePreset: String, CaseIterable, Identifiable {
    case extraSmall
    case small
    case medium
    case large
    case extraLarge

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .extraSmall:
            return "極小"
        case .small:
            return "小"
        case .medium:
            return "中"
        case .large:
            return "大"
        case .extraLarge:
            return "特大"
        }
    }

    public var scaleMultiplier: CGFloat {
        switch self {
        case .extraSmall:
            return 0.58
        case .small:
            return 0.72
        case .medium:
            return 1.0
        case .large:
            return 1.14
        case .extraLarge:
            return 1.32
        }
    }

    public func scale(baseScale: CGFloat) -> CGFloat {
        baseScale * scaleMultiplier
    }
}
