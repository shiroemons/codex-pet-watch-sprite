import CoreGraphics
import Foundation

public struct CodexPetBehaviorEngine {
    public struct Decision: Equatable {
        public let animation: CodexPetSpriteView.Animation
        public let targetPosition: CGPoint?
        public let duration: TimeInterval

        public var isMovement: Bool {
            targetPosition != nil
        }
    }

    private enum Intent {
        case returnToComfortZone
        case explore
        case inspect
        case rest
        case greet
        case celebrate
    }

    private var energy: Double
    private var curiosity: Double
    private var sociability: Double
    private var focusPoint: CGPoint?
    private var stationaryStreak: Int
    private var movementStreak: Int
    private var facingAnimation: CodexPetSpriteView.Animation

    public init(
        energy: Double = 0.72,
        curiosity: Double = 0.62,
        sociability: Double = 0.45
    ) {
        self.energy = min(max(energy, 0), 1)
        self.curiosity = min(max(curiosity, 0), 1)
        self.sociability = min(max(sociability, 0), 1)
        self.focusPoint = nil
        self.stationaryStreak = 0
        self.movementStreak = 0
        self.facingAnimation = .runningRight
    }

    public mutating func reset() {
        energy = 0.72
        curiosity = 0.62
        sociability = 0.45
        focusPoint = nil
        stationaryStreak = 0
        movementStreak = 0
        facingAnimation = .runningRight
    }

    public mutating func nextDecision(
        currentPosition: CGPoint,
        containerSize: CGSize,
        petSize: CGSize,
        bottomReservedHeight: CGFloat = 0
    ) -> Decision {
        let bounds = movementBounds(
            containerSize: containerSize,
            petSize: petSize,
            bottomReservedHeight: bottomReservedHeight
        )

        guard bounds.width > 1, bounds.height > 1 else {
            return stationaryDecision(intent: .rest)
        }

        updateNeeds()

        let position = clamp(currentPosition, to: bounds)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let edgePressure = edgePressure(for: position, in: bounds)

        if edgePressure > 0.82 {
            return movementDecision(
                from: position,
                to: biasedPoint(around: center, in: bounds, radius: 0.22),
                intent: .returnToComfortZone
            )
        }

        let intent = chooseIntent(edgePressure: edgePressure)
        switch intent {
        case .returnToComfortZone:
            return movementDecision(
                from: position,
                to: comfortPoint(from: position, toward: center, in: bounds),
                intent: intent
            )
        case .explore:
            let target = focusPoint ?? randomPoint(in: bounds)
            focusPoint = shouldKeepFocus(near: position, target: target) ? target : randomPoint(in: bounds)
            return movementDecision(
                from: position,
                to: focusPoint ?? target,
                intent: intent
            )
        case .inspect:
            let target = nearbyPoint(from: position, in: bounds)
            focusPoint = target
            return movementDecision(from: position, to: target, intent: intent)
        case .rest, .greet, .celebrate:
            return stationaryDecision(intent: intent)
        }
    }

    public mutating func nextMovementDecision(
        currentPosition: CGPoint,
        containerSize: CGSize,
        petSize: CGSize,
        bottomReservedHeight: CGFloat = 0
    ) -> Decision {
        let bounds = movementBounds(
            containerSize: containerSize,
            petSize: petSize,
            bottomReservedHeight: bottomReservedHeight
        )

        guard bounds.width > 1, bounds.height > 1 else {
            return stationaryDecision(intent: .rest)
        }

        updateNeeds()

        let position = clamp(currentPosition, to: bounds)
        let target = visibleMovementPoint(from: position, in: bounds)
        focusPoint = target

        return movementDecision(from: position, to: target, intent: .inspect)
    }

    private mutating func updateNeeds() {
        energy = min(1, energy + Double.random(in: 0.04...0.09))
        curiosity = min(1, curiosity + Double.random(in: 0.03...0.08))
        sociability = min(1, sociability + Double.random(in: 0.02...0.06))
    }

    private mutating func chooseIntent(edgePressure: Double) -> Intent {
        let restWeight = (1 - energy) * 2.2 + Double(movementStreak) * 0.28
        let exploreWeight = curiosity * 1.4 + Double(stationaryStreak) * 0.2
        let inspectWeight = curiosity * 0.9 + energy * 0.45
        let greetWeight = sociability * 0.9
        let celebrateWeight = energy * 0.35 + sociability * 0.2
        let returnWeight = edgePressure * 1.8

        return weightedIntent([
            (.returnToComfortZone, returnWeight),
            (.explore, exploreWeight),
            (.inspect, inspectWeight),
            (.rest, restWeight),
            (.greet, greetWeight),
            (.celebrate, celebrateWeight)
        ])
    }

    private mutating func movementDecision(
        from currentPosition: CGPoint,
        to targetPosition: CGPoint,
        intent: Intent
    ) -> Decision {
        stationaryStreak = 0
        movementStreak += 1
        energy = max(0, energy - 0.22)
        curiosity = max(0, curiosity - (intent == .explore ? 0.24 : 0.12))

        let horizontalDistance = targetPosition.x - currentPosition.x
        let distance = hypot(targetPosition.x - currentPosition.x, targetPosition.y - currentPosition.y)
        guard distance >= 6 else {
            return stationaryDecision(intent: .inspect)
        }

        let duration = min(max(TimeInterval(distance / 95), 0.75), 1.8)
        let animation: CodexPetSpriteView.Animation
        if horizontalDistance < -4 {
            animation = .runningLeft
        } else if horizontalDistance > 4 {
            animation = .runningRight
        } else {
            animation = facingAnimation
        }
        facingAnimation = animation

        return Decision(
            animation: animation,
            targetPosition: targetPosition,
            duration: duration
        )
    }

    private mutating func stationaryDecision(intent: Intent) -> Decision {
        stationaryStreak += 1
        movementStreak = 0

        let animation: CodexPetSpriteView.Animation
        let duration: TimeInterval

        switch intent {
        case .rest:
            energy = min(1, energy + 0.18)
            animation = Bool.random() ? .waiting : .idle
            duration = 1.4
        case .greet:
            sociability = max(0, sociability - 0.35)
            animation = .waving
            duration = 1.2
        case .celebrate:
            energy = max(0, energy - 0.16)
            animation = .jumping
            duration = 1.1
        case .inspect:
            curiosity = max(0, curiosity - 0.14)
            animation = .review
            duration = 1.5
        case .returnToComfortZone, .explore:
            animation = .idle
            duration = 1.2
        }

        if stationaryStreak >= 3 {
            curiosity = min(1, curiosity + 0.22)
        }

        return Decision(
            animation: animation,
            targetPosition: nil,
            duration: duration
        )
    }

    private func weightedIntent(_ weightedIntents: [(Intent, Double)]) -> Intent {
        let totalWeight = weightedIntents.reduce(0) { $0 + max($1.1, 0) }
        guard totalWeight > 0 else {
            return .rest
        }

        var cursor = Double.random(in: 0..<totalWeight)
        for (intent, weight) in weightedIntents {
            cursor -= max(weight, 0)
            if cursor <= 0 {
                return intent
            }
        }

        return weightedIntents.last?.0 ?? .rest
    }

    private func shouldKeepFocus(near position: CGPoint, target: CGPoint) -> Bool {
        let distance = hypot(target.x - position.x, target.y - position.y)
        return distance > 42 && Double.random(in: 0...1) < 0.68
    }

    private func movementBounds(
        containerSize: CGSize,
        petSize: CGSize,
        bottomReservedHeight: CGFloat
    ) -> CGRect {
        let minimumX = petSize.width / 2
        let maximumX = max(minimumX, containerSize.width - petSize.width / 2)
        let minimumY = petSize.height / 2
        let maximumY = max(
            minimumY,
            containerSize.height - max(bottomReservedHeight, 0) - petSize.height / 2
        )

        return CGRect(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX,
            height: maximumY - minimumY
        )
    }

    private func edgePressure(for position: CGPoint, in bounds: CGRect) -> Double {
        let horizontalInset = min(position.x - bounds.minX, bounds.maxX - position.x)
        let verticalInset = min(position.y - bounds.minY, bounds.maxY - position.y)
        let nearestInset = max(0, min(horizontalInset, verticalInset))
        let comfortInset = max(18, min(bounds.width, bounds.height) * 0.18)

        return min(max(1 - Double(nearestInset / comfortInset), 0), 1)
    }

    private func randomPoint(in bounds: CGRect) -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: bounds.minX...bounds.maxX),
            y: CGFloat.random(in: bounds.minY...bounds.maxY)
        )
    }

    private func nearbyPoint(from position: CGPoint, in bounds: CGRect) -> CGPoint {
        let longestAxis = max(bounds.width, bounds.height)
        let step = min(max(longestAxis * CGFloat.random(in: 0.16...0.32), 32), 220)
        let angle = CGFloat.random(in: 0...(2 * .pi))

        return clamp(
            CGPoint(
                x: position.x + cos(angle) * step,
                y: position.y + sin(angle) * step
            ),
            to: bounds
        )
    }

    private func comfortPoint(from position: CGPoint, toward center: CGPoint, in bounds: CGRect) -> CGPoint {
        let travelFraction = CGFloat.random(in: 0.45...0.72)
        let jitterX = bounds.width * CGFloat.random(in: -0.08...0.08)
        let jitterY = bounds.height * CGFloat.random(in: -0.08...0.08)

        return clamp(
            CGPoint(
                x: position.x + (center.x - position.x) * travelFraction + jitterX,
                y: position.y + (center.y - position.y) * travelFraction + jitterY
            ),
            to: bounds
        )
    }

    private func visibleMovementPoint(from position: CGPoint, in bounds: CGRect) -> CGPoint {
        let horizontalTarget = position.x < bounds.midX ? bounds.maxX : bounds.minX
        let verticalTravel = max(8, bounds.height * 0.36)
        let verticalTarget = position.y + CGFloat.random(in: -verticalTravel...verticalTravel)

        return clamp(
            CGPoint(
                x: horizontalTarget,
                y: verticalTarget
            ),
            to: bounds
        )
    }

    private func biasedPoint(around anchor: CGPoint, in bounds: CGRect, radius: CGFloat) -> CGPoint {
        let offsetX = bounds.width * CGFloat.random(in: -radius...radius)
        let offsetY = bounds.height * CGFloat.random(in: -radius...radius)

        return clamp(
            CGPoint(x: anchor.x + offsetX, y: anchor.y + offsetY),
            to: bounds
        )
    }

    private func clamp(_ position: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(position.x, bounds.minX), bounds.maxX),
            y: min(max(position.y, bounds.minY), bounds.maxY)
        )
    }
}
