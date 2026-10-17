import LibraryStorage
import SwiftUI

@MainActor
struct ICloudBackupView: View {
    @ObservedObject private var coordinator:
        ICloudSyncCoordinator
    private let registry: LibrarySourceRegistry?

    @Environment(\.dismiss) private var dismiss
    @State private var sources: [LibrarySourceRecord] = []
    @State private var selected:
        Set<ICloudBackupCategory> = [.settings]
    @State private var showingDeleteConfirmation = false

    init(services: AppServices) {
        coordinator = services.cloudSync
        registry = services.registry
    }

    var body: some View {
        NavigationStack {
            List {
                accountSection
                selectionSection
                summarySection
                actionSection
                privacySection
            }
            .kantaListSurface()
            .navigationTitle("iCloud Save")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                sources = await registry?.all() ?? []
                await coordinator.refresh(
                    sources: sources
                )
            }
            .alert(
                "iCloud",
                isPresented: errorBinding
            ) {
                Button("OK", role: .cancel) {
                    coordinator.errorMessage = nil
                }
            } message: {
                Text(coordinator.errorMessage ?? "")
            }
            .confirmationDialog(
                "Delete KANTA iCloud Backup?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete KANTA iCloud Backup", role: .destructive) {
                    Task { await coordinator.deleteKantaICloudBackup() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This deletes KANTA's saved settings and files from " +
                    "KANTA's private iCloud Save area. It does not delete " +
                    "your original Files/iCloud folders. Deletion may take " +
                    "time to propagate to other devices."
                )
            }
        }
        .tint(GeloVisualStyle.accent)
    }

    private var accountSection: some View {
        Section("Apple Account") {
            HStack(spacing: 12) {
                Image(
                    systemName:
                        coordinator.accountState == .available
                        ? "icloud.fill"
                        : "icloud.slash"
                )
                .font(.title2)
                .foregroundStyle(
                    coordinator.accountState == .available
                        ? GeloVisualStyle.accent
                        : .secondary
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(coordinator.accountState.title)
                        .font(.headline)
                    Text(accountHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var selectionSection: some View {
        Section {
            ForEach(ICloudBackupCategory.allCases) {
                category in
                Toggle(
                    isOn: binding(for: category)
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: category.systemImage)
                            .frame(width: 28)
                            .foregroundStyle(
                                GeloVisualStyle.accent
                            )

                        VStack(
                            alignment: .leading,
                            spacing: 3
                        ) {
                            Text(category.title)
                                .font(.headline)

                            Text(category.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(
                                sizeText(
                                    coordinator.estimate
                                        .bytes(for: category)
                                )
                            )
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Choose what KANTA saves")
        } footer: {
            Text(
                "Large categories are off by default. KANTA does not " +
                "automatically upload your full karaoke library."
            )
        }
    }

    private var summarySection: some View {
        Section("Estimated iCloud Use") {
            LabeledContent(
                "Selected",
                value: sizeText(
                    coordinator.estimate.totalBytes(
                        for: selected
                    )
                )
            )

            Text(
                "This is the estimated size of the selected KANTA data, " +
                "not your remaining iCloud quota. iOS does not expose " +
                "a general remaining-storage meter to KANTA."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                Task {
                    await coordinator.backupSelected(
                        selected,
                        sources: sources
                    )
                }
            } label: {
                HStack {
                    if coordinator.isWorking {
                        ProgressView()
                    } else {
                        Image(systemName: "icloud.and.arrow.up")
                    }
                    Text(
                        coordinator.isWorking
                            ? "Saving…"
                            : "Save Selected to iCloud"
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                coordinator.isWorking
                || selected.isEmpty
                || coordinator.accountState != .available
            )

            Button("Restore Settings from iCloud") {
                coordinator.restoreSettingsFromICloud()
            }
            .disabled(
                coordinator.isWorking
                || coordinator.accountState != .available
            )

            Button("Delete KANTA iCloud Backup", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .disabled(
                coordinator.isWorking
                || coordinator.accountState != .available
            )

            if let result = coordinator.lastResult {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        "Prepared for iCloud",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)

                    Text(
                        "\(result.copiedFileCount) files • " +
                        sizeText(result.copiedBytes) +
                        (result.settingsSaved
                            ? " • settings submitted"
                            : "")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text("iOS completes upload when connectivity and iCloud storage allow.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let deletionMessage = coordinator.deletionMessage {
                Label(deletionMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var privacySection: some View {
        Section("How iCloud works in KANTA") {
            Label(
                "No separate KANTA password is used. The app uses the " +
                "Apple Account already signed in on this device.",
                systemImage: "person.crop.circle.badge.checkmark"
            )

            Label(
                "Settings use Apple's iCloud key-value store. Selected " +
                "files are copied into KANTA's private iCloud Drive " +
                "container at original quality.",
                systemImage: "lock.icloud"
            )

            Label(
                "Songs, SoundFonts, images, and videos are never " +
                "compressed, transcoded, resized, or uploaded unless " +
                "you explicitly include their category.",
                systemImage: "checkmark.shield"
            )

            Label(
                "Delete KANTA iCloud Backup removes only KANTA's " +
                "private iCloud Save files and settings. Your original " +
                "library folders are never deleted by that action.",
                systemImage: "trash.slash"
            )
        }
        .font(.footnote)
    }

    private var accountHelpText: String {
        switch coordinator.accountState {
        case .available:
            "KANTA can use the iCloud account already signed in on this device."
        case .unavailable:
            "Sign in to iCloud in iOS Settings, then return to KANTA."
        case .checking:
            "KANTA is checking the device iCloud account."
        }
    }

    private func binding(
        for category: ICloudBackupCategory
    ) -> Binding<Bool> {
        Binding(
            get: {
                selected.contains(category)
            },
            set: { enabled in
                if enabled {
                    selected.insert(category)
                } else {
                    selected.remove(category)
                }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: {
                coordinator.errorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    coordinator.errorMessage = nil
                }
            }
        )
    }

    private func sizeText(_ bytes: Int64) -> String {
        if bytes <= 0 {
            return "0 KB"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [
            .useKB,
            .useMB,
            .useGB,
            .useTB
        ]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}


