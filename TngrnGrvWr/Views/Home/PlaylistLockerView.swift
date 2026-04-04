import SwiftUI

struct PlaylistLockerView: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(PlaylistLockerService.self) private var lockerService
    @Environment(\.themeColor) private var themeColor
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var fileToDelete: LockerFile?

    var body: some View {
        List {
            // MARK: - Backup Actions
            Section {
                Button {
                    Task { await backupAppleMusic() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                            .foregroundStyle(.mint)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Backup Apple Music")
                                .font(.subheadline.weight(.medium))
                            Text("Save all playlists to iCloud Drive")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.down.doc")
                            .foregroundStyle(themeColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled(lockerService.isBackingUp || !appleMusicService.isConnected)

                Button {
                    Task { await backupSpotify() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Backup Spotify")
                                .font(.subheadline.weight(.medium))
                            Text("Save all playlists to iCloud Drive")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.down.doc")
                            .foregroundStyle(themeColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled(lockerService.isBackingUp || !spotifyService.isConnected)
            } header: {
                Text("Backup")
            } footer: {
                if lockerService.isBackingUp {
                    Text(lockerService.backupProgress)
                        .font(.caption2)
                        .foregroundStyle(themeColor)
                }
            }

            // MARK: - Locker Contents
            Section {
                if lockerService.lockerFiles.isEmpty {
                    ContentUnavailableView(
                        "Locker is Empty",
                        systemImage: "lock.open",
                        description: Text("Back up your playlists to see them here.")
                    )
                } else {
                    ForEach(lockerService.lockerFiles) { file in
                        HStack(spacing: 10) {
                            lockerIcon(for: file.source)
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text(file.source.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("·")
                                        .foregroundStyle(.tertiary)
                                    Text(file.formattedSize)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("·")
                                        .foregroundStyle(.tertiary)
                                    Text(file.createdAt, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                fileToDelete = file
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Playlist Locker")
                    Spacer()
                    Text("\(lockerService.lockerFiles.count) playlists")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - iCloud Info
            Section {
                if let lockerURL = lockerService.lockerURL {
                    HStack(spacing: 10) {
                        Image(systemName: "icloud")
                            .foregroundStyle(themeColor)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud Drive")
                                .font(.subheadline.weight(.medium))
                            Text(lockerURL.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.icloud")
                            .foregroundStyle(.red)
                            .frame(width: 20)
                        Text("iCloud Drive not available")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Storage")
            }
        }
        .navigationTitle("Playlist Locker")
        .onAppear { lockerService.scanLocker() }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Delete Playlist?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    lockerService.deleteFile(file)
                }
                fileToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
        } message: {
            Text("This will remove \"\(fileToDelete?.name ?? "")\" from your locker.")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func lockerIcon(for source: StreamingService) -> some View {
        switch source {
        case .spotify:
            Image("LockerIconSpotify")
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .appleMusic:
            Image("LockerIconAppleMusic")
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .none:
            Image(systemName: "music.note.list")
                .font(.title3)
                .foregroundStyle(themeColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.1))
        }
    }

    private func backupAppleMusic() async {
        do {
            try await lockerService.backupAppleMusic(service: appleMusicService)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func backupSpotify() async {
        do {
            try await lockerService.backupSpotify(service: spotifyService)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        PlaylistLockerView()
    }
}
