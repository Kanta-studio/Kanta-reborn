import GeloKaraokeCore
import LocalNetworkControl
import SwiftUI

@MainActor
struct RemoteView: View {
    @StateObject private var browser: BonjourHostBrowser
    @StateObject private var client: RemoteHostClient

    @State private var selectedHostID: String?
    @State private var pairingPIN = ""
    @State private var catalogQuery = ""

    init() {
        _browser = StateObject(
            wrappedValue: BonjourHostBrowser()
        )
        _client = StateObject(
            wrappedValue: RemoteHostClient()
        )
    }

    var body: some View {
        List {
            Section("Nearby hosts") {
                if browser.hosts.isEmpty {
                    emptyState
                } else {
                    ForEach(browser.hosts) { host in
                        Button {
                            selectedHostID = host.id
                            client.disconnect()
                            catalogQuery = ""
                        } label: {
                            HStack {
                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {
                                    Label(
                                        host.name,
                                        systemImage:
                                            "dot.radiowaves.left.and.right"
                                    )
                                    .font(.headline)

                                    if let interfaceName =
                                        host.interfaceName {
                                        Text(interfaceName)
                                            .font(.caption)
                                            .foregroundStyle(
                                                .secondary
                                            )
                                    }
                                }

                                Spacer()

                                if selectedHostID == host.id {
                                    Image(
                                        systemName:
                                            "checkmark.circle.fill"
                                    )
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 3)
                        .accessibilityHint(
                            "Select this host for PIN pairing."
                        )
                        .accessibilityValue(
                            selectedHostID == host.id
                                ? "Selected"
                                : "Not selected"
                        )
                    }
                }
            }

            if let selectedHost {
                Section("Pair with " + selectedHost.name) {
                    TextField(
                        "6-digit PIN",
                        text: $pairingPIN
                    )
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onChange(of: pairingPIN) {
                        pairingPIN = String(
                            pairingPIN
                                .filter(\.isNumber)
                                .prefix(PairingCode.digitCount)
                        )
                    }

                    if isPaired {
                        LabeledContent(
                            "Status",
                            value: "Paired"
                        )

                        Button(
                            "Disconnect",
                            role: .destructive
                        ) {
                            client.disconnect()
                        }
                    } else {
                        Button("Connect") {
                            client.connect(
                                to: selectedHost,
                                pairingCode: pairingPIN
                            )
                        }
                        .disabled(
                            pairingPIN.count
                                != PairingCode.digitCount
                        )

                        LabeledContent(
                            "Status",
                            value: clientStatusText
                        )
                    }

                    if let lastError = client.lastError {
                        Text(lastError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if isPaired {
                Section("Songs on Host") {
                    TextField(
                        "Search title, artist, or code",
                        text: $catalogQuery
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    if client.isSearching {
                        HStack {
                            ProgressView()
                            Text("Searching host library…")
                        }
                    } else if client.catalogSongs.isEmpty {
                        Text("No matching songs")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(client.catalogSongs) { song in
                            HStack {
                                VStack(
                                    alignment: .leading,
                                    spacing: 3
                                ) {
                                    Text(song.title)
                                    if let artist = song.artist,
                                       !artist.isEmpty {
                                        Text(artist)
                                            .font(.caption)
                                            .foregroundStyle(
                                                .secondary
                                            )
                                    }
                                }

                                Spacer()

                                Button {
                                    client.enqueue(song)
                                } label: {
                                    Label(
                                        "Reserve",
                                        systemImage: "plus.circle"
                                    )
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel(
                                    "Reserve " + song.title
                                )
                            }
                        }
                    }
                }

                Section("Now Playing") {
                    if let song = client.snapshot.nowPlaying {
                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {
                            Text(song.title)
                                .font(.headline)
                            Text(
                                timeText(
                                    position:
                                        client.snapshot
                                            .positionMilliseconds,
                                    duration:
                                        client.snapshot
                                            .durationMilliseconds
                                )
                            )
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Nothing playing")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button {
                            client.send(.previous)
                        } label: {
                            Image(systemName: "backward.fill")
                        }
                        .accessibilityLabel("Previous song")

                        Spacer()

                        Button {
                            client.send(
                                client.snapshot.transport
                                    == .playing
                                ? .pause
                                : .play
                            )
                        } label: {
                            Image(
                                systemName:
                                    client.snapshot.transport
                                        == .playing
                                    ? "pause.fill"
                                    : "play.fill"
                            )
                            .font(.title2)
                        }
                        .accessibilityLabel(
                            client.snapshot.transport == .playing
                                ? "Pause"
                                : "Play"
                        )

                        Spacer()

                        Button {
                            client.send(.next)
                        } label: {
                            Image(systemName: "forward.fill")
                        }
                        .accessibilityLabel("Next song")
                    }
                    .buttonStyle(.borderless)
                }

                Section("Playback") {
                    LabeledContent(
                        "Volume",
                        value:
                            String(
                                Int(
                                    client.snapshot.volume * 100
                                )
                            ) + "%"
                    )

                    Slider(
                        value: Binding(
                            get: {
                                Double(client.snapshot.volume)
                            },
                            set: { value in
                                client.send(
                                    .setVolume(Float(value))
                                )
                            }
                        ),
                        in: 0...1
                    )
                    .accessibilityLabel("Playback volume")
                    .accessibilityValue(
                        String(
                            Int(client.snapshot.volume * 100)
                        ) + " percent"
                    )

                    HStack {
                        Button("Pitch −") {
                            client.send(
                                .setPitch(
                                    semitones: max(
                                        -12,
                                        client.snapshot
                                            .pitchSemitones - 1
                                    )
                                )
                            )
                        }
                        Spacer()
                        Text(
                            String(
                                client.snapshot.pitchSemitones
                            ) + " st"
                        )
                        .monospacedDigit()
                        Spacer()
                        Button("Pitch +") {
                            client.send(
                                .setPitch(
                                    semitones: min(
                                        12,
                                        client.snapshot
                                            .pitchSemitones + 1
                                    )
                                )
                            )
                        }
                    }

                    HStack {
                        Button("Tempo −") {
                            client.send(
                                .setTempo(
                                    ratio: max(
                                        0.5,
                                        client.snapshot
                                            .tempoRatio - 0.05
                                    )
                                )
                            )
                        }
                        Spacer()
                        Text(
                            String(
                                format: "%.2fx",
                                client.snapshot.tempoRatio
                            )
                        )
                        .monospacedDigit()
                        Spacer()
                        Button("Tempo +") {
                            client.send(
                                .setTempo(
                                    ratio: min(
                                        2.0,
                                        client.snapshot
                                            .tempoRatio + 0.05
                                    )
                                )
                            )
                        }
                    }
                }

                Section(
                    "Queue (" +
                    String(client.snapshot.queue.count) +
                    ")"
                ) {
                    if client.snapshot.queue.isEmpty {
                        Text("Queue is empty")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(client.snapshot.queue) { item in
                            Text(item.song.title)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        client.send(
                                            .removeQueueItem(
                                                item.id
                                            )
                                        )
                                    } label: {
                                        Label(
                                            "Remove",
                                            systemImage: "trash"
                                        )
                                    }
                                }
                        }
                    }
                }
            }

            Section("Network policy") {
                Text(
                    "Discovery, PIN pairing, remote search, and " +
                    "controls stay on the local network. KANTA " +
                    "Karaoke does not require a cloud account or " +
                    "Internet connection."
                )
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(KantaTerminology.control)
        .task {
            browser.start()
        }
        .onChange(of: catalogQuery) {
            if isPaired {
                client.search(catalogQuery)
            }
        }
        .onChange(of: client.status) {
            if isPaired {
                client.search(catalogQuery)
            }
        }
        .onDisappear {
            client.disconnect()
            browser.stop()
        }
    }

    private var selectedHost: DiscoveredKaraokeHost? {
        guard let selectedHostID else { return nil }
        return browser.hosts.first {
            $0.id == selectedHostID
        }
    }

    private var isPaired: Bool {
        if case .paired = client.status {
            return true
        }
        return false
    }

    private var clientStatusText: String {
        switch client.status {
        case .idle:
            return "Not connected"
        case .connecting:
            return "Connecting"
        case .pairing:
            return "Pairing"
        case .paired:
            return "Paired"
        case .failed:
            return "Connection failed"
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch browser.status {
        case .idle, .searching:
            HStack {
                ProgressView()
                Text("Searching local network…")
            }

        case .ready:
            ContentUnavailableView(
                "No KANTA hosts found",
                systemImage:
                    "dot.radiowaves.left.and.right",
                description: Text(
                    "Open KANTA on another device and start a Host session " +
                    "on the same local network."
                )
            )

        case let .failed(message):
            ContentUnavailableView(
                "Local discovery unavailable",
                systemImage: "wifi.exclamationmark",
                description: Text(message)
            )
        }
    }

    private func timeText(
        position: Int64,
        duration: Int64?
    ) -> String {
        let current = format(milliseconds: position)
        guard let duration else { return current }
        return current + " / " + format(milliseconds: duration)
    }

    private func format(milliseconds: Int64) -> String {
        let totalSeconds = max(0, milliseconds) / 1_000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(
            format: "%d:%02d",
            minutes,
            seconds
        )
    }
}

