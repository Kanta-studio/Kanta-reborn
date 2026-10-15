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
            guard presentedViewController == nil, let makePlayer else { return }
            isTransitioning = true
            present(makePlayer(), animated: false) { [weak self] in
                self?.isTransitioning = false
                self?.updatePresentation()
            }
        } else if presentedViewController != nil {
            isTransitioning = true
            dismiss(animated: false) { [weak self] in
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

