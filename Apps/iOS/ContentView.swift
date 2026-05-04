import CodexPetWatchSprite
import SwiftUI

struct ContentView: View {
    @State private var selectedAnimation: CodexPetSpriteView.Animation = .idle
    @State private var petPosition: CGPoint = .zero
    @State private var playbackSpeed = 0.55
    @State private var petScale = 1.25
    @State private var isFrameFixed = false
    @State private var selectedFrame = 0
    @State private var showsControls = false
    @State private var isRandomMovementEnabled = true
    @State private var randomMovementAnimation: CodexPetSpriteView.Animation?
    @State private var controlHideToken = UUID()
    @GestureState private var dragState: PetDragState?

    private let randomMoveDuration = 1.2
    private let randomMoveTimer = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()
    private let controlsAutoHideDelay = 3.0

    private var petSize: CGSize {
        CGSize(width: 192 * petScale, height: 208 * petScale)
    }

    var body: some View {
        GeometryReader { geometry in
            let displayedAnimation = dragState?.animation ?? randomMovementAnimation ?? selectedAnimation

            ZStack {
                Color.black
                    .ignoresSafeArea()

                CodexPetSpriteView(
                    animation: displayedAnimation,
                    scale: petScale,
                    durationScale: 1 / playbackSpeed,
                    fixedFrameIndex: fixedFrameIndex(for: displayedAnimation)
                )
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
            .onReceive(randomMoveTimer) { _ in
                moveRandomlyIfNeeded(in: geometry.size)
            }
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

            VStack(spacing: 8) {
                controlSlider(
                    title: "Speed",
                    valueText: String(format: "%.2fx", playbackSpeed),
                    value: $playbackSpeed,
                    range: 0.25...2
                )
                .onChange(of: playbackSpeed) { _ in
                    scheduleControlsAutoHide()
                }

                controlSlider(
                    title: "Size",
                    valueText: String(format: "%.2fx", petScale),
                    value: $petScale,
                    range: 0.5...1.8
                )
                .onChange(of: petScale) { _ in
                    scheduleControlsAutoHide()
                }

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

                Toggle("Random Move", isOn: $isRandomMovementEnabled)
                    .font(.caption)
                    .onChange(of: isRandomMovementEnabled) { isEnabled in
                        if !isEnabled {
                            randomMovementAnimation = nil
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

    private func controlSlider(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText)
            }
            .font(.caption)

            Slider(value: value, in: range)
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
            .updating($dragState) { value, state, _ in
                state = PetDragState(
                    translation: value.translation,
                    animation: dragAnimation(for: value.translation)
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
        } else {
            return .running
        }
    }

    private func fixedFrameIndex(for animation: CodexPetSpriteView.Animation) -> Int? {
        guard isFrameFixed, dragState == nil, randomMovementAnimation == nil else {
            return nil
        }

        return min(selectedFrame, animation.frameCount - 1)
    }

    private func moveRandomlyIfNeeded(in containerSize: CGSize) {
        guard isRandomMovementEnabled, !isFrameFixed, dragState == nil else {
            return
        }

        guard Bool.random() else {
            playRandomStationaryAnimation()
            return
        }

        let currentPosition = currentPetPosition(in: containerSize, dragState: nil)
        let nextPosition = randomPetPosition(in: containerSize)
        randomMovementAnimation = nextPosition.x < currentPosition.x ? .runningLeft : .runningRight

        withAnimation(.linear(duration: randomMoveDuration)) {
            petPosition = nextPosition
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + randomMoveDuration) {
            if isRandomMovementEnabled, dragState == nil {
                randomMovementAnimation = nil
            }
        }
    }

    private func playRandomStationaryAnimation() {
        randomMovementAnimation = [
            .idle,
            .waving,
            .jumping,
            .waiting,
            .review
        ].randomElement() ?? .idle

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if isRandomMovementEnabled, dragState == nil {
                randomMovementAnimation = nil
            }
        }
    }

    private func randomPetPosition(in containerSize: CGSize) -> CGPoint {
        let minimumX = petSize.width / 2
        let maximumX = max(minimumX, containerSize.width - petSize.width / 2)
        let minimumY = petSize.height / 2
        let controlsHeight: CGFloat = showsControls ? 300 : 76
        let maximumY = max(minimumY, containerSize.height - controlsHeight - petSize.height / 2)

        return CGPoint(
            x: CGFloat.random(in: minimumX...maximumX),
            y: CGFloat.random(in: minimumY...maximumY)
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
