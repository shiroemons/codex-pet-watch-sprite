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
    @State private var stationaryBehaviorCount = 0
    @State private var petHorizontalOffset: CGFloat = 0
    @State private var petVerticalOffset: CGFloat = 0
    @State private var lastMovementWasDiagonal: Bool?
    @State private var repeatedMovementStyleCount = 0
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
                    .offset(
                        x: dragState == nil ? petHorizontalOffset : 0,
                        y: dragState == nil ? petVerticalOffset : 0
                    )
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
            .updating($dragState) { value, state, _ in
                state = PetDragState(
                    translation: value.translation,
                    animation: value.translation.width < 0 ? .runningLeft : .runningRight
                )
            }
            .onEnded { value in
                let currentPosition = currentPetPosition(in: containerSize, dragState: nil)
                petPosition = clampedPetPosition(
                    CGPoint(
                        x: currentPosition.x + value.translation.width,
                        y: currentPosition.y + value.translation.height
                    ),
                    in: containerSize
                )
            }
    }

    private func performIntelligentBehaviorIfNeeded(in containerSize: CGSize) {
        guard dragState == nil else {
            return
        }

        let currentPosition = currentPetPosition(in: containerSize, dragState: nil)
        var decision = behaviorEngine.nextDecision(
            currentPosition: currentPosition,
            containerSize: containerSize,
            petSize: petSize,
            bottomReservedHeight: 36
        )

        if decision.isMovement {
            stationaryBehaviorCount = 0
        } else {
            stationaryBehaviorCount += 1
        }

        if stationaryBehaviorCount >= 2 {
            decision = behaviorEngine.nextMovementDecision(
                currentPosition: currentPosition,
                containerSize: containerSize,
                petSize: petSize,
                bottomReservedHeight: 36
            )
            stationaryBehaviorCount = 0
        }

        let token = UUID()
        behaviorToken = token
        let shouldMoveHorizontally = decision.isMovement
        let baseBehaviorDuration = shouldMoveHorizontally ? 1.0 : decision.duration
        let behaviorDuration = baseBehaviorDuration * animationSpeedPreset.movementDurationScale

        if shouldMoveHorizontally {
            let nextOffset = nextMovementOffset(in: containerSize)
            behaviorAnimation = nextOffset.width < petHorizontalOffset ? .runningLeft : .runningRight

            withAnimation(.linear(duration: behaviorDuration)) {
                petHorizontalOffset = nextOffset.width
                petVerticalOffset = nextOffset.height
            }
        } else {
            behaviorAnimation = decision.animation
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + behaviorDuration) {
            if dragState == nil, behaviorToken == token {
                behaviorAnimation = nil
            }
        }
    }

    private func nextMovementOffset(in containerSize: CGSize) -> CGSize {
        let availableTravel = (containerSize.width - petSize.width) / 2
        let horizontalTravel = min(54, max(36, availableTravel))
        let verticalTravel = min(14, max(8, (containerSize.height - petSize.height - 36) / 4))
        let shouldMoveDiagonally = nextMovementStyleIsDiagonal()

        let nextHorizontalOffset: CGFloat
        if petHorizontalOffset >= 0 {
            nextHorizontalOffset = -horizontalTravel
        } else {
            nextHorizontalOffset = horizontalTravel
        }

        let nextVerticalOffset: CGFloat
        if shouldMoveDiagonally {
            nextVerticalOffset = nextDiagonalVerticalOffset(verticalTravel: verticalTravel)
        } else {
            nextVerticalOffset = 0
        }

        return CGSize(width: nextHorizontalOffset, height: nextVerticalOffset)
    }

    private func nextMovementStyleIsDiagonal() -> Bool {
        let shouldMoveDiagonally: Bool

        if repeatedMovementStyleCount >= 2, let lastMovementWasDiagonal {
            shouldMoveDiagonally = !lastMovementWasDiagonal
        } else if lastMovementWasDiagonal == true {
            shouldMoveDiagonally = Int.random(in: 0..<10) < 4
        } else {
            shouldMoveDiagonally = Int.random(in: 0..<10) < 7
        }

        if lastMovementWasDiagonal == shouldMoveDiagonally {
            repeatedMovementStyleCount += 1
        } else {
            lastMovementWasDiagonal = shouldMoveDiagonally
            repeatedMovementStyleCount = 1
        }

        return shouldMoveDiagonally
    }

    private func nextDiagonalVerticalOffset(verticalTravel: CGFloat) -> CGFloat {
        let candidates: [CGFloat] = [-verticalTravel, verticalTravel].filter { candidate in
            abs(candidate - petVerticalOffset) > 1
        }

        return candidates.randomElement() ?? -petVerticalOffset
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
        CGPoint(
            x: clampedCoordinate(position.x, contentLength: petSize.width, containerLength: containerSize.width),
            y: clampedCoordinate(position.y, contentLength: petSize.height, containerLength: containerSize.height)
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
