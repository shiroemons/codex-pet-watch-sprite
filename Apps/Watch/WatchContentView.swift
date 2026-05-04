import CodexPetWatchSprite
import SwiftUI

struct WatchContentView: View {
    @State private var selectedAnimation: CodexPetSpriteView.Animation = .idle
    @State private var petPosition: CGPoint = .zero
    @State private var randomMovementAnimation: CodexPetSpriteView.Animation?
    @State private var showsActionControls = false
    @State private var actionHideToken = UUID()
    @GestureState private var dragState: PetDragState?

    private let randomMoveDuration = 1.1
    private let randomMoveTimer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()
    private let actionAutoHideDelay = 2.4
    private let petSize = CGSize(width: 100, height: 108)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showActionControlsTemporarily()
                        }
                    }

                CodexPetSpriteView(
                    animation: dragState?.animation ?? randomMovementAnimation ?? selectedAnimation,
                    scale: 0.52,
                    durationScale: 1.8
                )
                    .frame(width: petSize.width, height: petSize.height)
                    .position(currentPetPosition(in: geometry.size, dragState: dragState))
                    .gesture(petDragGesture(in: geometry.size))

                VStack {
                    Spacer()

                    if showsActionControls {
                        Button {
                            selectedAnimation = selectedAnimation.next
                            showActionControlsTemporarily()
                        } label: {
                            Label(selectedAnimation.title, systemImage: "forward.fill")
                        }
                        .font(.caption2)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
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

    private func moveRandomlyIfNeeded(in containerSize: CGSize) {
        guard dragState == nil else {
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
            if dragState == nil {
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            if dragState == nil {
                randomMovementAnimation = nil
            }
        }
    }

    private func randomPetPosition(in containerSize: CGSize) -> CGPoint {
        let minimumX = petSize.width / 2
        let maximumX = max(minimumX, containerSize.width - petSize.width / 2)
        let minimumY = petSize.height / 2
        let maximumY = max(minimumY, containerSize.height - 36 - petSize.height / 2)

        return CGPoint(
            x: CGFloat.random(in: minimumX...maximumX),
            y: CGFloat.random(in: minimumY...maximumY)
        )
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
