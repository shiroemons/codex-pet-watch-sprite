import CodexPetWatchSprite
import SwiftUI

struct ContentView: View {
    @State private var selectedAnimation: CodexPetSpriteView.Animation = .idle
    @State private var petPosition: CGPoint = .zero
    @AppStorage("codexPetAnimationSpeedPreset") private var animationSpeedPresetRawValue = CodexPetAnimationSpeedPreset.natural.rawValue
    @AppStorage("codexPetSizePreset") private var sizePresetRawValue = CodexPetSizePreset.medium.rawValue
    @State private var isFrameFixed = false
    @State private var selectedFrame = 0
    @State private var showsControls = false
    @State private var isIntelligentBehaviorEnabled = true
    @State private var behaviorAnimation: CodexPetSpriteView.Animation?
    @State private var behaviorEngine = CodexPetBehaviorEngine()
    @State private var behaviorToken = UUID()
    @State private var behaviorMotionEndsAt: Date?
    @State private var behaviorMotionStartedAt: Date?
    @State private var behaviorMotionStartPosition: CGPoint?
    @State private var behaviorMotionTargetPosition: CGPoint?
    @State private var behaviorMotionDuration: TimeInterval?
    @State private var lastMovementAnimation: CodexPetSpriteView.Animation = .runningRight
    @State private var petdexPets: [PetdexPet] = []
    @State private var petdexStatusMessage = "Petdex gallery is not loaded."
    @State private var installedPetSlug: String?
    @State private var installedPetName = "Local Sprite"
    @State private var installedSpriteSheetURL: URL?
    @State private var showsPetdexGallery = false
    @State private var controlHideToken = UUID()
    @GestureState private var dragState: PetDragState?

    private let behaviorTimer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()
    private let controlsAutoHideDelay = 8.0
    private let basePetScale: CGFloat = 1.25

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
            let displayedAnimation = dragState?.animation ?? behaviorAnimation ?? selectedAnimation

            ZStack {
                Color.black
                    .ignoresSafeArea()

                CodexPetSpriteView(
                    animation: displayedAnimation,
                    scale: petScale,
                    durationScale: animationSpeedPreset.durationScale(for: displayedAnimation),
                    fixedFrameIndex: fixedFrameIndex(for: displayedAnimation),
                    spriteSheetFileURL: installedSpriteSheetURL
                )
                    .id(installedSpriteSheetURL?.path ?? "local-sprite")
                    .frame(width: petSize.width, height: petSize.height)
                    .position(currentPetPosition(in: geometry.size, dragState: dragState))
                    .gesture(petDragGesture(in: geometry.size))

                controlOverlay
            }
            .onAppear {
                if petPosition == .zero {
                    petPosition = defaultPetPosition(in: geometry.size)
                }
            }
            .onReceive(behaviorTimer) { _ in
                performIntelligentBehaviorIfNeeded(in: geometry.size)
            }
        }
        .fullScreenCover(isPresented: $showsPetdexGallery) {
            PetdexGalleryView(
                pets: $petdexPets,
                installedPetSlug: $installedPetSlug,
                installedPetName: $installedPetName,
                installedSpriteSheetURL: $installedSpriteSheetURL,
                statusMessage: $petdexStatusMessage
            )
        }
    }

    private var controlOverlay: some View {
        VStack {
            Spacer()

            HStack(alignment: .bottom) {
                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    if showsControls {
                        controls
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if showsControls {
                                hideControls()
                            } else {
                                showControlsTemporarily()
                            }
                        }
                    } label: {
                        Image(systemName: showsControls ? "xmark" : "slider.horizontal.3")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(showsControls ? "Hide controls" : "Show controls")
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Animation", selection: $selectedAnimation) {
                ForEach(CodexPetSpriteView.Animation.allCases, id: \.self) { animation in
                    Text(animation.title).tag(animation)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 118)
            .onChange(of: selectedAnimation) { animation in
                selectedFrame = min(selectedFrame, animation.frameCount - 1)
                scheduleControlsAutoHide()
            }

            petdexControls

            VStack(spacing: 8) {
                speedPresetPicker

                sizePresetPicker

                Toggle("Frame", isOn: $isFrameFixed)
                    .font(.caption)
                    .onChange(of: isFrameFixed) { _ in
                        scheduleControlsAutoHide()
                    }

                if isFrameFixed {
                    Stepper(
                        "Frame \(selectedFrame + 1) / \(selectedAnimation.frameCount)",
                        value: $selectedFrame,
                        in: 0...(selectedAnimation.frameCount - 1)
                    )
                    .font(.caption)
                    .onChange(of: selectedFrame) { _ in
                        scheduleControlsAutoHide()
                    }
                }

                Toggle("AI Behavior", isOn: $isIntelligentBehaviorEnabled)
                    .font(.caption)
                    .onChange(of: isIntelligentBehaviorEnabled) { isEnabled in
                        if !isEnabled {
                            behaviorToken = UUID()
                            behaviorAnimation = nil
                        } else {
                            behaviorEngine.reset()
                        }
                        scheduleControlsAutoHide()
                    }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxWidth: 420)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var petdexControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(installedPetName, systemImage: "person.crop.square")
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Button {
                    showsPetdexGallery = true
                    scheduleControlsAutoHide()
                } label: {
                    Label("Petdex Gallery", systemImage: "square.grid.2x2")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
            }

            Text(petdexStatusMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 18)
    }

    private var speedPresetPicker: some View {
        Picker("Speed", selection: speedPresetBinding) {
            ForEach(CodexPetAnimationSpeedPreset.allCases) { preset in
                Text(preset.title).tag(preset)
            }
        }
        .font(.caption)
        .pickerStyle(.segmented)
    }

    private var sizePresetPicker: some View {
        Picker("Size", selection: sizePresetBinding) {
            ForEach(CodexPetSizePreset.allCases) { preset in
                Text(preset.title).tag(preset)
            }
        }
        .font(.caption)
        .pickerStyle(.segmented)
    }

    private var speedPresetBinding: Binding<CodexPetAnimationSpeedPreset> {
        Binding {
            animationSpeedPreset
        } set: { preset in
            animationSpeedPreset = preset
            scheduleControlsAutoHide()
        }
    }

    private var sizePresetBinding: Binding<CodexPetSizePreset> {
        Binding {
            sizePreset
        } set: { preset in
            sizePreset = preset
            scheduleControlsAutoHide()
        }
    }

    private func showControlsTemporarily() {
        showsControls = true
        scheduleControlsAutoHide()
    }

    private func hideControls() {
        showsControls = false
        controlHideToken = UUID()
    }

    private func scheduleControlsAutoHide() {
        let token = UUID()
        controlHideToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + controlsAutoHideDelay) {
            if controlHideToken == token {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsControls = false
                }
            }
        }
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

    private func fixedFrameIndex(for animation: CodexPetSpriteView.Animation) -> Int? {
        guard isFrameFixed, dragState == nil, behaviorAnimation == nil else {
            return nil
        }

        return min(selectedFrame, animation.frameCount - 1)
    }

    private func performIntelligentBehaviorIfNeeded(in containerSize: CGSize) {
        guard isIntelligentBehaviorEnabled, !isFrameFixed, dragState == nil else {
            return
        }
        if let behaviorMotionEndsAt, Date() < behaviorMotionEndsAt {
            return
        }

        let controlsHeight: CGFloat = showsControls ? 300 : 76
        let currentPosition = currentPetPosition(in: containerSize, dragState: nil)
        let decision = behaviorEngine.nextDecision(
            currentPosition: currentPosition,
            containerSize: containerSize,
            petSize: petSize,
            bottomReservedHeight: controlsHeight
        )
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
            if isIntelligentBehaviorEnabled, dragState == nil, behaviorToken == token {
                behaviorAnimation = nil
                clearBehaviorMotion()
            }
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
    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .runningRight:
            return "Running Right"
        case .runningLeft:
            return "Running Left"
        case .waving:
            return "Waving"
        case .jumping:
            return "Jumping"
        case .failed:
            return "Failed"
        case .waiting:
            return "Waiting"
        case .running:
            return "Running"
        case .review:
            return "Review"
        }
    }
}
