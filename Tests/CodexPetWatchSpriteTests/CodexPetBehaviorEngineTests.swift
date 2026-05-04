import CoreGraphics
import Testing
@testable import CodexPetWatchSprite

@Suite
struct CodexPetBehaviorEngineTests {
    @Test
    func edgePositionMovesBackIntoAvailableBounds() throws {
        var engine = CodexPetBehaviorEngine(energy: 1, curiosity: 1, sociability: 0)

        let decision = engine.nextDecision(
            currentPosition: CGPoint(x: 50, y: 50),
            containerSize: CGSize(width: 300, height: 300),
            petSize: CGSize(width: 100, height: 100)
        )

        let targetPosition = try #require(
            decision.targetPosition,
            "Expected edge pressure to produce a movement decision."
        )

        #expect(decision.animation == .runningRight)
        #expect(targetPosition.x >= 50)
        #expect(targetPosition.x <= 250)
        #expect(targetPosition.y >= 50)
        #expect(targetPosition.y <= 250)
    }

    @Test
    func tinyContainerProducesStationaryDecision() {
        var engine = CodexPetBehaviorEngine()

        let decision = engine.nextDecision(
            currentPosition: CGPoint(x: 10, y: 10),
            containerSize: CGSize(width: 40, height: 40),
            petSize: CGSize(width: 100, height: 100)
        )

        #expect(decision.targetPosition == nil)
        #expect(!decision.isMovement)
    }

    @Test
    func forcedMovementDecisionMovesHorizontally() throws {
        var engine = CodexPetBehaviorEngine()

        let decision = engine.nextMovementDecision(
            currentPosition: CGPoint(x: 120, y: 120),
            containerSize: CGSize(width: 240, height: 240),
            petSize: CGSize(width: 80, height: 80)
        )

        let targetPosition = try #require(
            decision.targetPosition,
            "Expected forced movement to produce a target position."
        )

        #expect(decision.animation == .runningLeft)
        #expect(targetPosition.x < 120)
    }

    @Test
    func animationSpeedPresetOrdersRunningSpeed() {
        #expect(
            CodexPetAnimationSpeedPreset.calm.durationScale(for: .runningRight)
                > CodexPetAnimationSpeedPreset.natural.durationScale(for: .runningRight)
        )
        #expect(
            CodexPetAnimationSpeedPreset.lively.durationScale(for: .runningRight)
                < CodexPetAnimationSpeedPreset.natural.durationScale(for: .runningRight)
        )
    }

    @Test
    func animationSpeedPresetAffectsMovementDuration() {
        #expect(
            CodexPetAnimationSpeedPreset.calm.movementDurationScale
                > CodexPetAnimationSpeedPreset.natural.movementDurationScale
        )
        #expect(
            CodexPetAnimationSpeedPreset.lively.movementDurationScale
                < CodexPetAnimationSpeedPreset.natural.movementDurationScale
        )
    }

    @Test
    func sizePresetScalesAroundMedium() {
        let baseScale: CGFloat = 1.25

        #expect(
            CodexPetSizePreset.extraSmall.scale(baseScale: baseScale)
                < CodexPetSizePreset.small.scale(baseScale: baseScale)
        )
        #expect(
            CodexPetSizePreset.small.scale(baseScale: baseScale)
                < CodexPetSizePreset.medium.scale(baseScale: baseScale)
        )
        #expect(
            CodexPetSizePreset.large.scale(baseScale: baseScale)
                > CodexPetSizePreset.medium.scale(baseScale: baseScale)
        )
        #expect(
            CodexPetSizePreset.extraLarge.scale(baseScale: baseScale)
                > CodexPetSizePreset.large.scale(baseScale: baseScale)
        )
    }

    @Test
    func runningPlaybackUsesAlternatingStrideFrames() {
        #expect(CodexPetSpriteView.Animation.runningRight.playbackFrameIndices == [0, 4, 1, 5, 2, 6, 3, 7])
        #expect(CodexPetSpriteView.Animation.runningLeft.playbackFrameIndices == [0, 4, 1, 5, 2, 6, 3, 7])
    }
}
