import ImageIO
import SwiftUI

struct PetdexGalleryView: View {
    @Binding var pets: [PetdexPet]
    @Binding var installedPetSlug: String?
    @Binding var installedPetName: String
    @Binding var installedSpriteSheetURL: URL?
    @Binding var statusMessage: String

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var installingSlug: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    TextField("Search Petdex", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    Button {
                        selectLocalSprite()
                    } label: {
                        PetdexGalleryRow(
                            title: "Local Sprite",
                            subtitle: "Bundled with this app",
                            thumbnailURL: nil,
                            systemImage: "shippingbox",
                            isSelected: installedPetSlug == nil,
                            isLoading: false
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(installingSlug != nil)
                }
                .padding()

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if pets.isEmpty, isLoading {
                            ProgressView("Loading Petdex Gallery")
                                .padding(.top, 48)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if filteredPets.isEmpty {
                            Text("No pets found.")
                                .foregroundStyle(.secondary)
                                .padding(.top, 48)
                        } else {
                            ForEach(filteredPets) { pet in
                                Button {
                                    Task {
                                        await install(pet)
                                    }
                                } label: {
                                    PetdexGalleryRow(
                                        title: pet.displayName,
                                        subtitle: pet.byline,
                                        thumbnailURL: pet.spritesheetURL,
                                        systemImage: "person.crop.square",
                                        isSelected: installedPetSlug == pet.slug,
                                        isLoading: installingSlug == pet.slug
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .disabled(isLoading || installingSlug != nil)

                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    if isLoading || installingSlug != nil {
                        ProgressView()
                    }

                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Petdex Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await loadPets(forceRefresh: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || installingSlug != nil)
                    .accessibilityLabel("Reload Petdex gallery")
                }
            }
            .task {
                await loadPets(forceRefresh: false)
            }
        }
    }

    private var filteredPets: [PetdexPet] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return pets
        }

        return pets.filter { pet in
            pet.displayName.localizedCaseInsensitiveContains(query)
                || pet.slug.localizedCaseInsensitiveContains(query)
                || pet.kind.localizedCaseInsensitiveContains(query)
                || pet.submittedBy.localizedCaseInsensitiveContains(query)
        }
    }

    private func selectLocalSprite() {
        installedSpriteSheetURL = nil
        installedPetSlug = nil
        installedPetName = "Local Sprite"
        statusMessage = "Using bundled sprite."
        dismiss()
    }

    @MainActor
    private func loadPets(forceRefresh: Bool) async {
        if isLoading || installingSlug != nil {
            return
        }

        if !forceRefresh, !pets.isEmpty {
            return
        }

        isLoading = true
        statusMessage = "Loading Petdex gallery..."

        do {
            pets = try await PetdexClient.shared.fetchPets()
            statusMessage = "Loaded \(pets.count) Petdex pets."
        } catch {
            statusMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func install(_ pet: PetdexPet) async {
        if isLoading || installingSlug != nil {
            return
        }

        installingSlug = pet.slug
        statusMessage = "Installing \(pet.displayName)..."

        do {
            installedSpriteSheetURL = try await PetdexClient.shared.install(pet)
            installedPetSlug = pet.slug
            installedPetName = pet.displayName
            statusMessage = "Installed \(pet.displayName)."
            dismiss()
        } catch {
            statusMessage = error.localizedDescription
        }

        installingSlug = nil
    }
}

private struct PetdexGalleryRow: View {
    let title: String
    let subtitle: String
    let thumbnailURL: URL?
    let systemImage: String
    let isSelected: Bool
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let thumbnailURL {
                PetdexThumbnailView(spriteSheetURL: thumbnailURL)
            } else {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 52)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isLoading {
                ProgressView()
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

private struct PetdexThumbnailView: View {
    let spriteSheetURL: URL

    @State private var thumbnail: CGImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)

            if let thumbnail {
                Image(decorative: thumbnail, scale: 1, orientation: .up)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            } else if didFail {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .frame(width: 48, height: 52)
        .task(id: spriteSheetURL) {
            await loadThumbnail()
        }
    }

    @MainActor
    private func loadThumbnail() async {
        thumbnail = nil
        didFail = false

        do {
            let (data, response) = try await URLSession.shared.data(from: spriteSheetURL)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                didFail = true
                return
            }

            guard
                let source = CGImageSourceCreateWithData(data as CFData, nil),
                let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil),
                let cropped = sheet.cropping(to: CGRect(x: 0, y: 0, width: 192, height: 208))
            else {
                didFail = true
                return
            }

            thumbnail = cropped
        } catch {
            didFail = true
        }
    }
}
