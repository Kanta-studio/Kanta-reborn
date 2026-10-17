import SwiftUI
import UIKit

@MainActor
struct FullscreenKaraokePlayerView: View {
    @ObservedObject var model: HostViewModel
    let backgroundsEnabled: Bool
    let selectedPreset: KantaBuiltInVisualPreset
    let onExit: () -> Void
    @ObservedObject var camera: KantaCameraBackground
    @ObservedObject var presentationGate: KantaPresentationGate
    var microphoneBusy = false
    @State private var singerName = ""

    @State private var windowScene: UIWindowScene?
    @State private var requestedLandscape = false
    @State private var didAppear = false
    @State private var screenshotRotationAttempted = false
    @State private var rotationError = ""
    @State private var showingRotationError = false

    var body: some View {
        KantaMainPlayerView(
            model: model, camera: camera, presentationGate: presentationGate,
            backgroundsEnabled: backgroundsEnabled,
            selectedPreset: selectedPreset,
            singerName: $singerName,
            microphoneBusy: microphoneBusy,
            onControls: onExit, onMore: onExit
        )
        .overlay(alignment: .topTrailing) {
            HStack {
                orientationButton(isLandscape: windowScene?.interfaceOrientation.isLandscape == true)
                exitButton
            }
            .padding(.top, 58).padding(.trailing, 12)
        }
        .background(.black)
        .background(
            SingingWindowSceneReader { scene in
                // UIKit may attach this probe before the fullscreen
                // presentation finishes. Only request rotation after appear.
                guard let scene else { return }
                windowScene = scene
                scheduleScreenshotOrientationIfNeeded()
            }
        )
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            didAppear = true
            scheduleScreenshotOrientationIfNeeded()
        }
        .onDisappear {
            didAppear = false
            // Only undo rotation that this player explicitly requested.
            // Physical rotation remains under the user's control.
            if requestedLandscape, let windowScene {
                windowScene.requestGeometryUpdate(
                    .iOS(interfaceOrientations: .portrait)
                ) { _ in }
            }
        }
        .alert("Unable to change orientation", isPresented: $showingRotationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rotationError)
        }
    }

    private func orientationButton(isLandscape: Bool) -> some View {
        Button {
            requestOrientation(
                isLandscape ? .portrait : .landscape,
                wantsLandscape: !isLandscape
            )
        } label: {
            Text(isLandscape ? "Portrait" : "Landscape")
                .font(.caption.weight(.bold))
                .frame(width: 94, height: 44)
                .background(.black.opacity(0.58), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isLandscape
                ? "Switch to portrait singing mode"
                : "Switch to landscape singing mode"
        )
    }

    private var exitButton: some View {
        Button {
            onExit()
        } label: {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.50), in: Circle())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Exit fullscreen player")
        .accessibilityIdentifier("fullscreen.exit")
    }

    private func requestOrientation(
        _ orientation: UIInterfaceOrientationMask,
        wantsLandscape: Bool
    ) {
        guard let windowScene else {
            rotationError = "The singing window is not ready to rotate yet."
            showingRotationError = true
            return
        }

        let previousRequest = requestedLandscape
        requestedLandscape = wantsLandscape
        // SwiftUI hosts the fullscreen player inside a UIKit controller. Ask
        // UIKit to reevaluate the active controller's supported orientations
        // before requesting scene geometry.
        if let root = windowScene.windows.first(where: { $0.isKeyWindow })?
            .rootViewController {
            root.setNeedsUpdateOfSupportedInterfaceOrientations()
            var presented: UIViewController? = root
            while let next = presented?.presentedViewController {
                next.setNeedsUpdateOfSupportedInterfaceOrientations()
                presented = next
            }
        }
        windowScene.requestGeometryUpdate(
            .iOS(interfaceOrientations: orientation)
        ) { error in
            Task { @MainActor in
                requestedLandscape = previousRequest
                if UIDevice.current.userInterfaceIdiom == .pad,
                   (error as NSError).code == 101 {
                    rotationError =
                        "iPadOS windowing does not allow KANTA to rotate " +
                        "this window automatically. Rotate the iPad or " +
                        "resize the app window to a wider layout instead."
                } else {
                    rotationError = error.localizedDescription
                }
                showingRotationError = true
            }
        }
    }

    private func scheduleScreenshotOrientationIfNeeded() {
        guard didAppear, windowScene != nil, !screenshotRotationAttempted,
              ProcessInfo.processInfo.environment[
                  "KANTA_SCREENSHOT_LANDSCAPE"
              ] == "1" else { return }
        screenshotRotationAttempted = true
        Task { @MainActor in
            // Allow the fullScreenCover's presenting transition to complete.
            try? await Task.sleep(for: .milliseconds(400))
            guard didAppear else { return }
            requestOrientation(.landscape, wantsLandscape: true)
            try? await Task.sleep(for: .milliseconds(800))
            writeScreenshotOrientationDiagnostics()
        }
    }

    private func writeScreenshotOrientationDiagnostics() {
        guard ProcessInfo.processInfo.environment[
            "KANTA_SCREENSHOT_LANDSCAPE"
        ] == "1", let windowScene else { return }
        let geometry = windowScene.effectiveGeometry
        let orientation = geometry.interfaceOrientation
        let proof: [String: Any] = [
            "interfaceOrientation": orientation.rawValue,
            "isLandscape": orientation.isLandscape,
            "requestedLandscape": requestedLandscape,
            "windowSize": [
                windowScene.coordinateSpace.bounds.width,
                windowScene.coordinateSpace.bounds.height
            ],
            "rotationError": rotationError
        ]
        guard let bytes = try? JSONSerialization.data(
            withJSONObject: proof, options: .prettyPrinted
        ), let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return }
        try? bytes.write(
            to: documents.appendingPathComponent(
                "KANTA-Simulator-Orientation.json"
            ),
            options: .atomic
        )
    }


}

/// Resolves the exact UIWindowScene hosting this player, including iPad's
/// multi-window environment, rather than rotating an unrelated foreground scene.
@MainActor
private struct SingingWindowSceneReader: UIViewRepresentable {
    let onSceneChange: (UIWindowScene?) -> Void

    func makeUIView(context: Context) -> SingingWindowProbeView {
        let view = SingingWindowProbeView()
        view.onSceneChange = onSceneChange
        return view
    }

    func updateUIView(_ view: SingingWindowProbeView, context: Context) {
        view.onSceneChange = onSceneChange
    }
}

@MainActor
private final class SingingWindowProbeView: UIView {
    var onSceneChange: ((UIWindowScene?) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        let scene = window?.windowScene
        Task { @MainActor [weak self] in
            self?.onSceneChange?(scene)
        }
    }
}

