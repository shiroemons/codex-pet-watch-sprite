import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PetdexPet: Decodable, Hashable, Identifiable {
    let slug: String
    let displayName: String
    let kind: String
    let submittedBy: String
    let spritesheetUrl: String
    let petJsonUrl: String
    let zipUrl: String

    var id: String { slug }

    var spritesheetURL: URL? {
        URL(string: spritesheetUrl)
    }

    var byline: String {
        "\(kind) by \(submittedBy)"
    }
}

private struct PetdexManifest: Decodable {
    let pets: [PetdexPet]
}

enum PetdexClientError: LocalizedError {
    case invalidSpriteURL
    case invalidResponse
    case invalidSpriteSheet

    var errorDescription: String? {
        switch self {
        case .invalidSpriteURL:
            return "Petdex sprite URL is invalid."
        case .invalidResponse:
            return "Petdex returned an invalid response."
        case .invalidSpriteSheet:
            return "The downloaded Petdex sprite sheet could not be loaded."
        }
    }
}

final class PetdexClient {
    static let shared = PetdexClient()

    private let manifestURL = URL(string: "https://petdex.crafter.run/api/manifest")!
    private let cacheDirectory: URL

    private init(fileManager: FileManager = .default) {
        cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PetdexSprites", isDirectory: true)
    }

    func fetchPets() async throws -> [PetdexPet] {
        let (data, response) = try await URLSession.shared.data(from: manifestURL)
        try validate(response)

        let manifest = try JSONDecoder().decode(PetdexManifest.self, from: data)
        return manifest.pets
    }

    func install(_ pet: PetdexPet) async throws -> URL {
        guard let spriteURL = pet.spritesheetURL else {
            throw PetdexClientError.invalidSpriteURL
        }

        let (data, response) = try await URLSession.shared.data(from: spriteURL)
        try validate(response)

        let petDirectory = cacheDirectory.appendingPathComponent(safePathComponent(pet.slug), isDirectory: true)
        try FileManager.default.createDirectory(at: petDirectory, withIntermediateDirectories: true)

        let spriteFileURL = petDirectory.appendingPathComponent("spritesheet").appendingPathExtension("png")
        try writePNGSpriteSheet(from: data, to: spriteFileURL)
        return spriteFileURL
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw PetdexClientError.invalidResponse
        }
    }

    private func writePNGSpriteSheet(from data: Data, to fileURL: URL) throws {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
            image.width >= 1536,
            image.height >= 1872,
            let destination = CGImageDestinationCreateWithURL(
                fileURL as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            throw PetdexClientError.invalidSpriteSheet
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PetdexClientError.invalidSpriteSheet
        }
    }

    private func safePathComponent(_ value: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : "-"
        }

        return String(scalars)
    }
}
