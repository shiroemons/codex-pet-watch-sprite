import XCTest
@testable import CodexPetWatchSprite

final class CodexPetBehaviorEngineTests: XCTestCase {
    func testEdgePositionMovesBackIntoAvailableBounds() {
        var engine = CodexPetBehaviorEngine(energy: 1, curiosity: 1, sociability: 0)

        let decision = engine.nextDecision(
            currentPosition: CGPoint(x: 50, y: 50),
            containerSize: CGSize(width: 300, height: 300),
            petSize: CGSize(width: 100, height: 100)
        )

        guard let targetPosition = decision.targetPosition else {
            return XCTFail("Expected edge pressure to produce a movement decision.")
        }

        XCTAssertEqual(decision.animation, .runningRight)
        XCTAssertGreaterThanOrEqual(targetPosition.x, 50)
        XCTAssertLessThanOrEqual(targetPosition.x, 250)
        XCTAssertGreaterThanOrEqual(targetPosition.y, 50)
        XCTAssertLessThanOrEqual(targetPosition.y, 250)
    }

    func testTinyContainerProducesStationaryDecision() {
        var engine = CodexPetBehaviorEngine()

        let decision = engine.nextDecision(
            currentPosition: CGPoint(x: 10, y: 10),
            containerSize: CGSize(width: 40, height: 40),
            petSize: CGSize(width: 100, height: 100)
        )

        XCTAssertNil(decision.targetPosition)
        XCTAssertFalse(decision.isMovement)
    }

    func testForcedMovementDecisionMovesHorizontally() {
        var engine = CodexPetBehaviorEngine()

        let decision = engine.nextMovementDecision(
            currentPosition: CGPoint(x: 120, y: 120),
            containerSize: CGSize(width: 240, height: 240),
            petSize: CGSize(width: 80, height: 80)
        )

        guard let targetPosition = decision.targetPosition else {
            return XCTFail("Expected forced movement to produce a target position.")
        }

        XCTAssertEqual(decision.animation, .runningLeft)
        XCTAssertLessThan(targetPosition.x, 120)
    }

    func testAnimationSpeedPresetOrdersRunningSpeed() {
        XCTAssertGreaterThan(
            CodexPetAnimationSpeedPreset.calm.durationScale(for: .runningRight),
            CodexPetAnimationSpeedPreset.natural.durationScale(for: .runningRight)
        )
        XCTAssertLessThan(
            CodexPetAnimationSpeedPreset.lively.durationScale(for: .runningRight),
            CodexPetAnimationSpeedPreset.natural.durationScale(for: .runningRight)
        )
    }

    func testAnimationSpeedPresetAffectsMovementDuration() {
        XCTAssertGreaterThan(
            CodexPetAnimationSpeedPreset.calm.movementDurationScale,
            CodexPetAnimationSpeedPreset.natural.movementDurationScale
        )
        XCTAssertLessThan(
            CodexPetAnimationSpeedPreset.lively.movementDurationScale,
            CodexPetAnimationSpeedPreset.natural.movementDurationScale
        )
    }

    func testSizePresetScalesAroundMedium() {
        let baseScale: CGFloat = 1.25

        XCTAssertLessThan(
            CodexPetSizePreset.extraSmall.scale(baseScale: baseScale),
            CodexPetSizePreset.small.scale(baseScale: baseScale)
        )
        XCTAssertLessThan(
            CodexPetSizePreset.small.scale(baseScale: baseScale),
            CodexPetSizePreset.medium.scale(baseScale: baseScale)
        )
        XCTAssertGreaterThan(
            CodexPetSizePreset.large.scale(baseScale: baseScale),
            CodexPetSizePreset.medium.scale(baseScale: baseScale)
        )
        XCTAssertGreaterThan(
            CodexPetSizePreset.extraLarge.scale(baseScale: baseScale),
            CodexPetSizePreset.large.scale(baseScale: baseScale)
        )
    }

    func testRunningPlaybackUsesAlternatingStrideFrames() {
        XCTAssertEqual(
            CodexPetSpriteView.Animation.runningRight.playbackFrameIndices,
            [0, 4, 1, 5, 2, 6, 3, 7]
        )
        XCTAssertEqual(
            CodexPetSpriteView.Animation.runningLeft.playbackFrameIndices,
            [0, 4, 1, 5, 2, 6, 3, 7]
        )
    }
}
