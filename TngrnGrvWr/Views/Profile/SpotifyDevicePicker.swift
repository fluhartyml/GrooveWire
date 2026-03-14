import SwiftUI

struct SpotifyDevicePicker: View {
    @Environment(SpotifyService.self) private var spotifyService

    var body: some View {
        Section("Play On") {
            if spotifyService.availableDevices.isEmpty {
                Text("No devices found. Open Spotify on any device to use it as a speaker.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Refresh Devices") {
                    Task { try? await spotifyService.fetchDevices() }
                }
            } else {
                ForEach(spotifyService.availableDevices) { device in
                    Button {
                        spotifyService.selectedDeviceID = device.id
                    } label: {
                        HStack {
                            Image(systemName: device.icon)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(device.name)
                                Text(device.type)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if spotifyService.selectedDeviceID == device.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Button("Refresh") {
                    Task { try? await spotifyService.fetchDevices() }
                }
                .font(.caption)
            }
        }
    }
}
