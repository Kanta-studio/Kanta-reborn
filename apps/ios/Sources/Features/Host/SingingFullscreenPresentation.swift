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

    func makeUIViewController(context: Context) -> SingingModalPresenter {
        SingingModalPresenter()
    }

    func updateUIViewController(
        _ presenter: SingingModalPresenter,
        context: Context
    ) {
        presenter.configure(
            isPresented: isPresented,
            makePlayer: {
                let screen = FullscreenKaraokePlayerView(
                    model: model,
                    backgroundsEnabled: backgroundsEnabled,
                    selectedPreset: selectedPreset,
                    onExit: { isPresented = false },
                    camera: camera,
                    presentationGate: presentationGate,
                    microphoneBusy: microphoneBusy
                )
                let controller = SingingRotationHostingController(rootView: screen)
                controller.modalPresentationStyle = .fullScreen
                return controller
            }
        )
    }
}

/// Keeps modal presentation ownership with UIKit. In screenshot mode the
/// Host can start with isPresented=true before the presenter has a window;
/// viewDidAppear will finish presenting it once attached.
@MainActor
final class SingingModalPresenter: UIViewController {
    private var wantsPresentation = false
    private var makePlayer: (() -> UIViewController)?
    private var isTransitioning = false
    private weak var ownedPlayer: UIViewController?

    override func loadView() {
        view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    func configure(
        isPresented: Bool,
        makePlayer: @escaping () -> UIViewController
    ) {
        wantsPresentation = isPresented
        self.makePlayer = makePlayer
        updatePresentation()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updatePresentation()
    }

    private func updatePresentation() {
        guard !isTransitioning, viewIfLoaded?.window != nil else { return }

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
                return
            }
            // UIKit can report an ancestor's modal here. Dismiss only the player we created.
            isTransitioning = true
            player.dismiss(animated: false) { [weak self] in
                self?.ownedPlayer = nil
                self?.isTransitioning = false
            }
        }
    }
}

/// The topmost fullscreen UIViewController (not a child/background probe)
/// declares both iPhone landscape directions, allowing UIKit to approve
/// UIWindowScene.requestGeometryUpdate consistently. iPad supports all four.
@MainActor
private final class SingingRotationHostingController<Content: View>:
    UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    override var shouldAutorotate: Bool { true }
}

