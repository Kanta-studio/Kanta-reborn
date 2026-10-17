import Combine
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
            makePlayer: { [weak presenter] in
                let screen = FullscreenKaraokePlayerView(
                    model: model, backgroundsEnabled: backgroundsEnabled,
                    selectedPreset: selectedPreset,
                    onExit: {
                        isPresented = false
                        presenter?.requestDismissal()
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
    private var gateObservation: AnyCancellable?
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
        if self.presentationGate !== presentationGate {
            gateObservation = presentationGate.objectWillChange.sink { [weak self] in
                Task { @MainActor in
                    self?.updatePresentation()
                }
            }
        }
        self.presentationGate = presentationGate
        self.makePlayer = makePlayer
        self.onDismiss = onDismiss
        if isPresented { acquireGateIfNeeded() }
        else {
            // A queued acquisition must not present a player after its intent was cancelled.
            if ownsGate { presentationGate.beginDismissal(.fullscreen) }
        }
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
            if !self.wantsPresentation {
                self.presentationGate?.beginDismissal(.fullscreen)
            }
            self.updatePresentation()
        }
    }

    func requestDismissal() {
        wantsPresentation = false
        presentationGate?.beginDismissal(.fullscreen)
        updatePresentation()
    }

    private func updatePresentation() {
        guard ownsGate, !isTransitioning else { return }
        if wantsPresentation {
            // The presenter must be attached only to start presentation. UIKit
            // removes a full-screen presenter's view from the window while its
            // child is visible; that must not prevent Exit from dismissing it.
            guard viewIfLoaded?.window != nil,
                  ownedPlayer == nil, presentedViewController == nil,
                  let makePlayer else { return }
            let player = makePlayer()
            ownedPlayer = player
            isTransitioning = true
            present(player, animated: false) { [weak self] in
                self?.isTransitioning = false
                self?.updatePresentation()
            }
        } else if let player = ownedPlayer {
            // A Search or Queue sheet belongs to the fullscreen player. Let its
            // onDismiss callback restore fullscreen ownership before tearing down
            // the player that presents it.
            // Fullscreen may own a child Search/Queue sheet when Exit is tapped.
            // The child's dismissal callback can restore the parent gate later,
            // but it must not block UIKit from dismissing the player now.
            // Dismissing the player also dismisses any child presentation.
            if presentationGate?.owner == .fullscreen,
               presentationGate?.dismissing != true {
                presentationGate?.beginDismissal(.fullscreen)
            }
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
        // Release ownership before publishing the dismissed binding. The next
        // SwiftUI update may immediately request Search on the underlying stage.
        presentationGate?.completeDismissal(.fullscreen)
        onDismiss?()
    }
}

@MainActor
private final class SingingRotationHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
    override var shouldAutorotate: Bool { true }
}
