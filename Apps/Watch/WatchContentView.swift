import CodexPetWatchSprite
import SwiftUI
import WatchKit

struct WatchContentView: View {
    @State private var selectedAnimation: CodexPetSpriteView.Animation = .idle
    @State private var petPosition: CGPoint = .zero
    @AppStorage("codexPetWatchAnimationSpeedPreset") private var animationSpeedPresetRawValue = CodexPetAnimationSpeedPreset.natural.rawValue
    @AppStorage("codexPetWatchSizePreset") private var sizePresetRawValue = CodexPetSizePreset.medium.rawValue
    @State private var behaviorAnimation: CodexPetSpriteView.Animation?
    @State private var behaviorEngine = CodexPetBehaviorEngine()
    @State private var behaviorToken = UUID()
    @State private var behaviorMotionEndsAt: Date?
    @State private var behaviorMotionStartedAt: Date?
    @State private var behaviorMotionStartPosition: CGPoint?
    @State private var behaviorMotionTargetPosition: CGPoint?
    @State private var behaviorMotionDuration: TimeInterval?
    @State private var lastMovementAnimation: CodexPetSpriteView.Animation = .runningRight
    @State private var stationaryBehaviorCount = 0
    @State private var showsActionControls = false
    @State private var actionHideToken = UUID()
    @GestureState private var dragState: PetDragState?

    private let behaviorTimer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()
    private let actionAutoHideDelay = 2.4
    private let actionButtonWidth: CGFloat = 124
    private let basePetScale: CGFloat = 0.52
    private let screenSize = WKInterfaceDevice.current().screenBounds.size

    private var animationSpeedPreset: CodexPetAnimationSpeedPreset {
        get {
            CodexPetAnimationSpeedPreset(rawValue: animationSpeedPresetRawValue) ?? .natural
        }
        nonmutating set {
            animationSpeedPresetRawValue = newValue.rawValue
        }
    }

    private var sizePreset: CodexPetSizePreset {
        get {
            CodexPetSizePreset(rawValue: sizePresetRawValue) ?? .medium
        }
        nonmutating set {
            sizePresetRawValue = newValue.rawValue
        }
    }

    private var petScale: CGFloat {
        sizePreset.scale(baseScale: basePetScale)
    }

    private var petSize: CGSize {
        CGSize(width: 192 * petScale, height: 208 * petScale)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showActionControlsTemporarily()
                        }
                    }

                CodexPetSpriteView(
                    animation: dragState?.animation ?? behaviorAnimation ?? selectedAnimation,
                    scale: petScale,
                    durationScale: animationSpeedPreset.durationScale(
                        for: dragState?.animation ?? behaviorAnimation ?? selectedAnimation
                    )
                )
                    .frame(width: petSize.width, height: petSize.height)
                    .position(currentPetPosition(in: geometry.size, dragState: dragState))
                    .gesture(petDragGesture(in: geometry.size))

                VStack {
                    Spacer()

                    if showsActionControls {
                        actionControls
                            .padding(.bottom, 48)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                if petPosition == .zero {
                    petPosition = defaultPetPosition(in: geometry.size)
                }
            }
            .onReceive(behaviorTimer) { _ in
                performIntelligentBehaviorIfNeeded(in: geometry.size)
            }
        }
        .frame(width: screenSize.width, height: screenSize.height)
    }

    private var actionControls: some View {
        VStack(spacing: 4) {
            Button {
                selectedAnimation = selectedAnimation.next
                showActionControlsTemporarily()
            } label: {
                Label(selectedAnimation.title, systemImage: "forward.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: actionButtonWidth)

            Button {
                animationSpeedPreset = animationSpeedPreset.next
                showActionControlsTemporarily()
            } label: {
                Text(animationSpeedPreset.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: actionButtonWidth)
            .accessibilityLabel("Speed \(animationSpeedPreset.title)")

            Button {
                sizePreset = sizePreset.next
                showActionControlsTemporarily()
            } label: {
                Text(sizePreset.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: actionButtonWidth)
            .accessibilityLabel("Size \(sizePreset.title)")
        }
        .font(.caption2)
        .frame(width: actionButtonWidth)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func petDragGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { _ in
                cancelBehaviorMotion()
            }
            .updating($dragState) { value, state, _ in
                state = PetDragState(
                    translation: value.translation,
                    animation: dragAnimation(for: value.translation)
                )
            }
            .onEnded { value in
                let currentPosition = currentPetPosition(in: containerSize, dragState: nil)
                lastMovementAnimation = dragAnimation(for: value.translation)
                petPosition = clampedPetPosition(
                    CGPoint(
                        x: currentPosition.x + value.translation.width,
                        y: currentPosition.y + value.translation.height
                    ),
                    in: containerSize
                )
                behaviorEngine.reset()
                stationaryBehaviorCount = 0
            }
    }

    private func performIntelligentBehaviorIfNeeded(in containerSize: CGSize) {
        guard dragState == nil else {
            return
        }
        if let behaviorMotionEndsAt, Date() < behaviorMotionEndsAt {
            return
        }

        let currentPosition = currentPetPosition(in: containerSize, dragState: nil)
        var decision = behaviorEngine.nextDecision(
            currentPosition: currentPosition,
            containerSize: containerSize,
            petSize: movementPetSize(in: containerSize),
            bottomReservedHeight: bottomReservedHeight
        )

        if decision.isMovement, !isNoticeableWatchMovement(decision, from: currentPosition, in: containerSize) {
            decision = visibleWatchMovementDecision(from: currentPosition, in: containerSize)
        }

        if decision.isMovement {
            stationaryBehaviorCount = 0
        } else {
            stationaryBehaviorCount += 1
        }

        if stationaryBehaviorCount >= 2 {
            decision = visibleWatchMovementDecision(from: currentPosition, in: containerSize)
            stationaryBehaviorCount = 0
        }

        let token = UUID()
        behaviorToken = token
        behaviorAnimation = decision.animation
        let behaviorDuration = decision.duration * animationSpeedPreset.movementDurationScale

        if let nextPosition = decision.targetPosition {
            lastMovementAnimation = decision.animation
            startBehaviorMotion(
                from: currentPosition,
                to: nextPosition,
                duration: behaviorDuration
            )
            withAnimation(.linear(duration: behaviorDuration)) {
                petPosition = nextPosition
            }
        } else {
            clearBehaviorMotion()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + behaviorDuration) {
            if dragState == nil, behaviorToken == token {
                behaviorAnimation = nil
                clearBehaviorMotion()
            }
        }
    }

    private func showActionControlsTemporarily() {
        showsActionControls = true
        scheduleActionAutoHide()
    }

    private func scheduleActionAutoHide() {
        let token = UUID()
        actionHideToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + actionAutoHideDelay) {
            if actionHideToken == token {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsActionControls = false
                }
            }
        }
    }

    private var bottomReservedHeight: CGFloat {
        showsActionControls ? 120 : 36
    }

    private func visibleWatchMovementDecision(
        from currentPosition: CGPoint,
        in containerSize: CGSize
    ) -> CodexPetBehaviorEngine.Decision {
        behaviorEngine.nextMovementDecision(
            currentPosition: currentPosition,
            containerSize: containerSize,
            petSize: movementPetSize(in: containerSize),
            bottomReservedHeight: bottomReservedHeight
        )
    }

    private func isNoticeableWatchMovement(
        _ decision: CodexPetBehaviorEngine.Decision,
        from currentPosition: CGPoint,
        in containerSize: CGSize
    ) -> Bool {
        guard let targetPosition = decision.targetPosition else {
            return false
        }

        let movementPetSize = movementPetSize(in: containerSize)
        let horizontalRoom = max(0, containerSize.width - movementPetSize.width)
        let verticalRoom = max(0, containerSize.height - bottomReservedHeight - petSize.height)
        let horizontalDelta = abs(targetPosition.x - currentPosition.x)
        let verticalDelta = abs(targetPosition.y - currentPosition.y)
        let distance = hypot(horizontalDelta, verticalDelta)
        let minimumHorizontalDelta = min(max(horizontalRoom * 0.3, 12), 30)
        let minimumDistance = min(max(min(horizontalRoom, verticalRoom) * 0.22, 14), 34)

        return horizontalDelta >= minimumHorizontalDelta || distance >= minimumDistance
    }

    private func dragAnimation(for translation: CGSize) -> CodexPetSpriteView.Animation {
        if translation.width < -6 {
            return .runningLeft
        } else if translation.width > 6 {
            return .runningRight
        } else if abs(translation.height) > 6 {
            return lastMovementAnimation
        } else {
            return selectedAnimation
        }
    }

    private func cancelBehaviorMotion() {
        if let currentBehaviorPosition = currentBehaviorMotionPosition() {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                petPosition = currentBehaviorPosition
            }
        }

        behaviorToken = UUID()
        behaviorAnimation = nil
        clearBehaviorMotion()
    }

    private func startBehaviorMotion(
        from startPosition: CGPoint,
        to targetPosition: CGPoint,
        duration: TimeInterval
    ) {
        let startedAt = Date()
        behaviorMotionStartedAt = startedAt
        behaviorMotionStartPosition = startPosition
        behaviorMotionTargetPosition = targetPosition
        behaviorMotionDuration = duration
        behaviorMotionEndsAt = startedAt.addingTimeInterval(duration)
    }

    private func clearBehaviorMotion() {
        behaviorMotionStartedAt = nil
        behaviorMotionStartPosition = nil
        behaviorMotionTargetPosition = nil
        behaviorMotionDuration = nil
        behaviorMotionEndsAt = nil
    }

    private func currentBehaviorMotionPosition() -> CGPoint? {
        guard
            let behaviorMotionStartedAt,
            let behaviorMotionStartPosition,
            let behaviorMotionTargetPosition,
            let behaviorMotionDuration,
            behaviorMotionDuration > 0
        else {
            return nil
        }

        let progress = min(max(Date().timeIntervalSince(behaviorMotionStartedAt) / behaviorMotionDuration, 0), 1)
        return CGPoint(
            x: behaviorMotionStartPosition.x + (behaviorMotionTargetPosition.x - behaviorMotionStartPosition.x) * progress,
            y: behaviorMotionStartPosition.y + (behaviorMotionTargetPosition.y - behaviorMotionStartPosition.y) * progress
        )
    }

    private func currentPetPosition(in containerSize: CGSize, dragState: PetDragState?) -> CGPoint {
        let basePosition = petPosition == .zero ? defaultPetPosition(in: containerSize) : petPosition
        guard let dragState else {
            return basePosition
        }

        return clampedPetPosition(
            CGPoint(
                x: basePosition.x + dragState.translation.width,
                y: basePosition.y + dragState.translation.height
            ),
            in: containerSize
        )
    }

    private func defaultPetPosition(in containerSize: CGSize) -> CGPoint {
        CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
    }

    private func clampedPetPosition(_ position: CGPoint, in containerSize: CGSize) -> CGPoint {
        let movementPetSize = movementPetSize(in: containerSize)

        return CGPoint(
            x: clampedCoordinate(position.x, contentLength: movementPetSize.width, containerLength: containerSize.width),
            y: clampedCoordinate(position.y, contentLength: petSize.height, containerLength: containerSize.height)
        )
    }

    private func movementPetSize(in containerSize: CGSize) -> CGSize {
        CGSize(
            width: max(1, petSize.width - horizontalEdgeAllowance(in: containerSize) * 2),
            height: petSize.height
        )
    }

    private func horizontalEdgeAllowance(in containerSize: CGSize) -> CGFloat {
        let fullyVisibleHorizontalRoom = max(0, containerSize.width - petSize.width)
        guard fullyVisibleHorizontalRoom > 0 else {
            return 0
        }

        return min(
            petSize.width * 0.22,
            max(12, fullyVisibleHorizontalRoom * 0.38),
            26
        )
    }

    private func clampedCoordinate(
        _ value: CGFloat,
        contentLength: CGFloat,
        containerLength: CGFloat
    ) -> CGFloat {
        let minimum = contentLength / 2
        let maximum = containerLength - contentLength / 2
        guard minimum <= maximum else {
            return containerLength / 2
        }

        return min(max(value, minimum), maximum)
    }
}

private struct PetDragState {
    let translation: CGSize
    let animation: CodexPetSpriteView.Animation
}

private extension CodexPetSpriteView.Animation {
    var next: Self {
        let animations = Self.allCases
        guard let index = animations.firstIndex(of: self) else {
            return .idle
        }

        return animations[(index + 1) % animations.count]
    }

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .runningRight:
            return "Right"
        case .runningLeft:
            return "Left"
        case .waving:
            return "Wave"
        case .jumping:
            return "Jump"
        case .failed:
            return "Failed"
        case .waiting:
            return "Waiting"
        case .running:
            return "Run"
        case .review:
            return "Review"
        }
    }
}

private extension CodexPetAnimationSpeedPreset {
    var next: Self {
        let presets = Self.allCases
        guard let index = presets.firstIndex(of: self) else {
            return .natural
        }

        return presets[(index + 1) % presets.count]
    }
}

private extension CodexPetSizePreset {
    var next: Self {
        let presets = Self.allCases
        guard let index = presets.firstIndex(of: self) else {
            return .medium
        }

        return presets[(index + 1) % presets.count]
    }
}
