import SwiftUI
import UIKit

/// Presents the singing screen using a UIKit hosting controller whose
/// supported orientations are explicit, rather than inheriting a transient
/// portrait-only mask from SwiftUI's fullScreenCover presentation host.
/// The controller exists only while the singing screen is visible.
@MainActor
struct SingingFullscreenPresentation: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let model: HostViewModel
    let backgroundsEnabled: Bool
    let selectedPreset: KantaBuiltInVisualPreset
    let camera: KantaCameraBackground
    let presentationGate: KantaPresentationGate
    let microphoneBusy: Bool

    func makeUIViewController(context: Context) -> SingingModalPresenter { SingingModalPresenter() }

    func updateUIViewController(_ presenter: SingingModalPresenter, context: Context) {
        presenter.configure(
            isPresented: isPresented,
            presentationGate: presentationGate,
            makePlayer: {
                let screen = FullscreenKaraokePlayerView(
                    model: model, backgroundsEnabled: backgroundsEnabled,
                    selectedPreset: selectedPreset,
                    onExit: {
                        presentationGate.beginDismissal(.fullscreen)
                        isPresented = false
                    },
                    camera: camera, presentationGate: presentationGate,
                    microphoneBusy: microphoneBusy
                )
                let controller = SingingRotationHostingController(rootView: screen)
                controller.modalPresentationStyle = .fullScreen
                return controller
            },
            onDismiss: { isPresented = false }
        )
    }
}

/// Keeps modal presentation ownership with UIKit. In screenshot mode the
/// Host can start with isPresented=true before the presenter has a window;
/// viewDidAppear finishes presenting once attached. The shared gate releases
/// fullscreen ownership only after UIKit's dismissal callback.
@MainActor
final class SingingModalPresenter: UIViewController {
    private var wantsPresentation = false
    private var makePlayer: (() -> UIViewController)?
    private var onDismiss: (() -> Void)?
    private weak var presentationGate: KantaPresentationGate?
    private var isTransitioning = false
    private var hasRequestedGate = false
    private var ownsGate = false
    private weak var ownedPlayer: UIViewController?

    override func loadView() {
        view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    func configure(
        isPresented: Bool, presentationGate: KantaPresentationGate,
        makePlayer: @escaping () -> UIViewController, onDismiss: @escaping () -> Void
    ) {
        wantsPresentation = isPresented
        self.presentationGate = presentationGate
        self.makePlayer = makePlayer
        self.onDismiss = onDismiss
        if isPresented { acquireGateIfNeeded() }
        else if ownsGate { presentationGate.beginDismissal(.fullscreen) }
        updatePresentation()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updatePresentation()
    }

    private func acquireGateIfNeeded() {
        guard !ownsGate, !hasRequestedGate, let presentationGate else { return }
        if presentationGate.owner == .fullscreen && !presentationGate.dismissing {
            ownsGate = true
            return
        }
        hasRequestedGate = true
        presentationGate.request(.fullscreen) { [weak self] in
            guard let self else { return }
            self.hasRequestedGate = false
            self.ownsGate = true
            self.updatePresentation()
        }
    }

    private func updatePresentation() {
        guard ownsGate, !isTransitioning, viewIfLoaded?.window != nil else { return }
        if wantsPresentation {
            guard ownedPlayer == nil, presentedViewController == nil, let makePlayer else { return }
            let player = makePlayer()
            ownedPlayer = player
            isTransitioning = true
            present(player, animated: false) { [weak self] in
                self?.isTransitioning = false
                self?.updatePresentation()
            }
        } else if let player = ownedPlayer {
            guard player.presentingViewController != nil else {
                ownedPlayer = nil
                finishDismissal()
                return
            }
            // Dismiss only the player created here, never an ancestor's controller.
            isTransitioning = true
            player.dismiss(animated: false) { [weak self] in
                guard let self else { return }
                self.ownedPlayer = nil
                self.isTransitioning = false
                self.finishDismissal()
            }
        } else {
            finishDismissal()
        }
    }

    private func finishDismissal() {
        guard ownsGate else { return }
        ownsGate = false
        hasRequestedGate = false
        onDismiss?()
        presentationGate?.completeDismissal(.fullscreen)
    }
}

@MainActor
private final class SingingRotationHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
    override var shouldAutorotate: Bool { true }
}
