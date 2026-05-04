import ImageIO
import SwiftUI

public struct CodexPetSpriteView: View {
    public enum Animation: Int, CaseIterable, Equatable, Hashable {
        case idle = 0
        case runningRight = 1
        case runningLeft = 2
        case waving = 3
        case jumping = 4
        case failed = 5
        case waiting = 6
        case running = 7
        case review = 8

        public var frameCount: Int {
            durations.count
        }

        var durations: [TimeInterval] {
            switch self {
            case .idle:
                return [0.280, 0.110, 0.110, 0.140, 0.140, 0.320]
            case .runningRight, .runningLeft:
                return [0.115, 0.115, 0.115, 0.115, 0.115, 0.115, 0.115, 0.115]
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

        var playbackFrameIndices: [Int] {
            switch self {
            case .runningRight, .runningLeft:
                return [0, 4, 1, 5, 2, 6, 3, 7]
            case .running:
                return [0, 3, 1, 4, 2, 5]
            case .idle, .waving, .jumping, .failed, .waiting, .review:
                return Array(0..<frameCount)
            }
        }
    }

    private let animation: Animation
    private let scale: CGFloat
    private let durationScale: TimeInterval
    private let fixedFrameIndex: Int?
    private let resourceName: String
    private let resourceExtension: String
    private let spriteSheetFileURL: URL?
    private let bundle: Bundle

    @State private var frameCache: [Animation: [CGImage]] = [:]

    public init(
        animation: Animation = .idle,
        scale: CGFloat = 1,
        durationScale: TimeInterval = 1,
        fixedFrameIndex: Int? = nil,
        spriteSheetFileURL: URL? = nil,
        resourceName: String = "spritesheet",
        resourceExtension: String = "png",
        bundle: Bundle? = nil
    ) {
        self.animation = animation
        self.scale = scale
        self.durationScale = max(durationScale, 0.1)
        self.fixedFrameIndex = fixedFrameIndex
        self.spriteSheetFileURL = spriteSheetFileURL
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
                    .frame(width: Self.cellSize.width * scale, height: Self.cellSize.height * scale)
            } else {
                Color.clear
                    .frame(width: Self.cellSize.width * scale, height: Self.cellSize.height * scale)
            }
        }
        .onAppear(perform: loadFrames)
        .onChange(of: spriteSheetFileURL) { _ in
            loadFrames()
        }
        .accessibilityHidden(true)
    }

    private func frame(at date: Date) -> CGImage? {
        guard
            let frames = frameCache[animation],
            !frames.isEmpty
        else {
            return nil
        }

        if let fixedFrameIndex {
            return frames[min(max(fixedFrameIndex, 0), frames.count - 1)]
        }

        let durations = animation.durations.map { $0 * durationScale }
        let totalDuration = durations.reduce(0, +)
        var cursor = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: totalDuration)

        let frameIndices = animation.playbackFrameIndices
        for index in durations.indices {
            cursor -= durations[index]
            if cursor <= 0 {
                let frameIndex = frameIndices[min(index, frameIndices.count - 1)]
                return frames[min(frameIndex, frames.count - 1)]
            }
        }

        return frames.last
    }

    private func loadFrames() {
        frameCache = CodexPetSpriteFrameLoader.frames(from: spriteSheetURL()) ?? [:]
    }

    private func spriteSheetURL() -> URL? {
        if let spriteSheetFileURL {
            return spriteSheetFileURL
        }

        var extensions: [String] = []
        for resourceExtension in [resourceExtension, "png", "webp"] where !extensions.contains(resourceExtension) {
            extensions.append(resourceExtension)
        }

        for resourceExtension in extensions {
            if let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) {
                return url
            }
        }

        return nil
    }

    nonisolated public static let cellSize = CGSize(width: 192, height: 208)
}

public struct CodexPetSpriteFrameView: View {
    private let animation: CodexPetSpriteView.Animation
    private let frameIndex: Int
    private let scale: CGFloat
    private let resourceName: String
    private let resourceExtension: String
    private let spriteSheetFileURL: URL?
    private let bundle: Bundle

    public init(
        animation: CodexPetSpriteView.Animation = .idle,
        frameIndex: Int = 0,
        scale: CGFloat = 1,
        spriteSheetFileURL: URL? = nil,
        resourceName: String = "spritesheet",
        resourceExtension: String = "png",
        bundle: Bundle? = nil
    ) {
        self.animation = animation
        self.frameIndex = frameIndex
        self.scale = scale
        self.spriteSheetFileURL = spriteSheetFileURL
        self.resourceName = resourceName
        self.resourceExtension = resourceExtension
        self.bundle = bundle ?? .module
    }

    public var body: some View {
        if let frame = CodexPetSpriteFrameLoader.frame(
            animation: animation,
            frameIndex: frameIndex,
            spriteSheetURL: spriteSheetURL()
        ) {
            Image(decorative: frame, scale: 1, orientation: .up)
                .interpolation(.none)
                .resizable()
                .frame(
                    width: CodexPetSpriteView.cellSize.width * scale,
                    height: CodexPetSpriteView.cellSize.height * scale
                )
        } else {
            Color.clear
                .frame(
                    width: CodexPetSpriteView.cellSize.width * scale,
                    height: CodexPetSpriteView.cellSize.height * scale
                )
        }
    }

    private func spriteSheetURL() -> URL? {
        if let spriteSheetFileURL {
            return spriteSheetFileURL
        }

        var extensions: [String] = []
        for resourceExtension in [resourceExtension, "png", "webp"] where !extensions.contains(resourceExtension) {
            extensions.append(resourceExtension)
        }

        for resourceExtension in extensions {
            if let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) {
                return url
            }
        }

        return nil
    }
}

private enum CodexPetSpriteFrameLoader {
    static func frames(from spriteSheetURL: URL?) -> [CodexPetSpriteView.Animation: [CGImage]]? {
        guard
            let sheet = spriteSheet(from: spriteSheetURL)
        else {
            return nil
        }

        return Dictionary(uniqueKeysWithValues: CodexPetSpriteView.Animation.allCases.map { animation in
            let frames = animation.durations.indices.compactMap { column in
                frame(animation: animation, frameIndex: column, spriteSheet: sheet)
            }

            return (animation, frames)
        })
    }

    static func frame(
        animation: CodexPetSpriteView.Animation,
        frameIndex: Int,
        spriteSheetURL: URL?
    ) -> CGImage? {
        guard
            let sheet = spriteSheet(from: spriteSheetURL)
        else {
            return nil
        }

        return frame(animation: animation, frameIndex: frameIndex, spriteSheet: sheet)
    }

    private static func spriteSheet(from url: URL?) -> CGImage? {
        guard
            let url,
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func frame(
        animation: CodexPetSpriteView.Animation,
        frameIndex: Int,
        spriteSheet: CGImage
    ) -> CGImage? {
        let index = min(max(frameIndex, 0), animation.frameCount - 1)
        let rect = CGRect(
            x: CGFloat(index) * CodexPetSpriteView.cellSize.width,
            y: CGFloat(animation.rawValue) * CodexPetSpriteView.cellSize.height,
            width: CodexPetSpriteView.cellSize.width,
            height: CodexPetSpriteView.cellSize.height
        )

        return spriteSheet.cropping(to: rect)
    }
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
