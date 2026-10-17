import LocalNetworkControl
import SwiftUI

@MainActor
struct EncryptedCompanionView: View {
    @StateObject private var client = EncryptedCompanionClient()
    @Environment(\.scenePhase) private var scenePhase
    @State private var address = ""
    @State private var code = ""
    @State private var query = ""
    @State private var singer = ""
    @FocusState private var editingCode: Bool

    var body: some View {
        List {
            Section("Pair with Android") {
                TextField("Host IPv4 address", text: $address)
                    .accessibilityIdentifier("companion.address")
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .disabled(client.paired || client.busy)
                SecureField("32-character pairing code", text: $code)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($editingCode).submitLabel(.done)
                    .onSubmit { editingCode = false }
                    .privacySensitive().accessibilityIdentifier("companion.code")
                    .disabled(client.paired || client.busy)
                if client.paired || client.busy {
                    Button("Disconnect", role: .destructive) { stop() }
                } else {
                    Button("Connect") {
                        guard scenePhase == .active else { return }
                        client.connect(address: address, code: code)
                        code = ""
                    }
                    .accessibilityIdentifier("companion.connect")
                    .disabled(!validPairingInput)
                }
                Text(client.status).font(.footnote)
                Text("On Android 0.10 or later, open Control → Companion control and start hosting. Keep both apps on the same trusted Wi-Fi.")
                    .font(.footnote)
                Text("Enter the Android host's private IPv4 address and full 32-character hexadecimal pairing code.")
                    .font(.footnote)
            }
            if client.paired {
                Section("Now playing") {
                    Text(client.snapshot?.current ?? "Loading host")
                    HStack {
                        Button(client.snapshot?.playing == true ? "Pause" : "Play") {
                            client.send(action: client.snapshot?.playing == true ? "pause" : "play")
                        }
                        Spacer()
                        Button("Next") { client.send(action: "next") }
                    }.disabled(client.busy || client.snapshot == nil)
                }
                Section("Reserve a song") {
                    TextField("Singer name (optional)", text: $singer)
                    TextField("Title, artist or code", text: $query)
                        .autocorrectionDisabled()
                        .onSubmit { search() }
                    Button("Search") { search() }.disabled(client.busy)
                    Text("Shows up to 10 matches. Refine your search for more.").font(.caption)
                    ForEach(client.snapshot?.songs ?? []) { song in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(song.title)
                                Text([song.artist, song.code].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption)
                            }
                            Spacer()
                            Button("Reserve") { client.send(action: "reserve", argument: song.id, singer: singer) }
                                .disabled(client.busy)
                                .accessibilityLabel("Reserve " + song.title)
                        }
                    }
                }
                Section("Up next · first 10 reservations") {
                    ForEach(client.snapshot?.queue ?? []) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                if !item.singer.isEmpty { Text(item.singer).font(.caption) }
                            }
                            Spacer()
                            Button("Cancel", role: .destructive) {
                                client.send(action: "cancel", argument: item.id)
                            }.disabled(client.busy)
                        }
                    }
                }
            }
            Section("Experimental connection") {
                Text("Encrypted iPhone/iPad control of an Android host only. iPhone hosting uses the separate legacy remote and is not compatible. Sessions expire after 10 minutes and stop when this screen closes or the app leaves the foreground. No microphone, camera, media files or full song catalog is shared. No automatic reconnect. Do not forward the host port to the internet. Physical-device interoperability and independent security review remain pending.")
                    .font(.footnote)
            }
        }
        .buttonStyle(.bordered)
        .navigationTitle("Encrypted companion")
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: scenePhase) {
            if scenePhase != .active { stop() }
        }
        .onDisappear { stop() }
    }
    private var validPairingInput: Bool {
        guard (try? CompanionProtocol.privateAddress(address)) != nil,
              code.utf8.count == 32 else { return false }
        return code.utf8.allSatisfy {
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }
    }

    private func stop() { client.disconnect(); code = "" }
    private func search() { client.send(action: "search", argument: query) }
}
