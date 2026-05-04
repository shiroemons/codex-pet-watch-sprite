import ImageIO
import SwiftUI

public struct CodexPetSpriteView: View {
    public enum Animation: Int, CaseIterable, Equatable {
        case idle = 0
        case runningRight = 1
        case runningLeft = 2
        case waving = 3
        case jumping = 4
        case failed = 5
        case waiting = 6
        case running = 7
        case review = 8

        var durations: [TimeInterval] {
            switch self {
            case .idle:
                return [0.280, 0.110, 0.110, 0.140, 0.140, 0.320]
            case .runningRight, .runningLeft:
                return [0.120, 0.120, 0.120, 0.120, 0.120, 0.120, 0.120, 0.220]
            case .waving:
                return [0.140, 0.140, 0.140, 0.280]
            case .jumping:
                return [0.140, 0.140, 0.140, 0.140, 0.280]
            case .failed:
                return [0.140, 0.140, 0.140, 0.140, 0.140, 0.140, 0.140, 0.240]
            case .waiting:
                return [0.150, 0.150, 0.150, 0.150, 0.150, 0.260]
            case .running:
                return [0.120, 0.120, 0.120, 0.120, 0.120, 0.220]
            case .review:
                return [0.150, 0.150, 0.150, 0.150, 0.150, 0.280]
            }
        }
    }

    private let animation: Animation
    private let scale: CGFloat
    private let resourceName: String
    private let resourceExtension: String
    private let bundle: Bundle

    @State private var frames: [CGImage] = []

    public init(
        animation: Animation = .idle,
        scale: CGFloat = 1,
        resourceName: String = "spritesheet",
        resourceExtension: String = "webp",
        bundle: Bundle? = nil
    ) {
        self.animation = animation
        self.scale = scale
        self.resourceName = resourceName
        self.resourceExtension = resourceExtension
        self.bundle = bundle ?? .module
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            if let frame = frame(at: timeline.date) {
                Image(decorative: frame, scale: 1, orientation: .up)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: Self.cellWidth * scale, height: Self.cellHeight * scale)
            } else {
                Color.clear
                    .frame(width: Self.cellWidth * scale, height: Self.cellHeight * scale)
            }
        }
        .onAppear(perform: loadFrames)
        .onChange(of: animation) { _ in
            loadFrames()
        }
        .accessibilityHidden(true)
    }

    private func frame(at date: Date) -> CGImage? {
        guard !frames.isEmpty else {
            return nil
        }

        let durations = animation.durations
        let totalDuration = durations.reduce(0, +)
        var cursor = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: totalDuration)

        for index in durations.indices {
            cursor -= durations[index]
            if cursor <= 0 {
                return frames[min(index, frames.count - 1)]
            }
        }

        return frames.last
    }

    private func loadFrames() {
        guard
            let url = bundle.url(forResource: resourceName, withExtension: resourceExtension),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            assertionFailure("Could not load \(resourceName).\(resourceExtension).")
            frames = []
            return
        }

        frames = animation.durations.indices.compactMap { column in
            let rect = CGRect(
                x: CGFloat(column) * Self.cellWidth,
                y: CGFloat(animation.rawValue) * Self.cellHeight,
                width: Self.cellWidth,
                height: Self.cellHeight
            )

            return sheet.cropping(to: rect)
        }
    }

    private static let cellWidth: CGFloat = 192
    private static let cellHeight: CGFloat = 208
}

struct CodexPetSpriteView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            CodexPetSpriteView(animation: .idle, scale: 1)
            CodexPetSpriteView(animation: .runningRight, scale: 1)
            CodexPetSpriteView(animation: .review, scale: 1)
        }
    }
}
