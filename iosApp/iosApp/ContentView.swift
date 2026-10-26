import UIKit
import SwiftUI
import ComposeApp

struct ComposeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = MainViewControllerKt.MainViewController()
        FoldStateBridge.attach(to: controller.view)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        ComposeView()
                .ignoresSafeArea(.keyboard) // Compose has own keyboard handler
                .ignoresSafeArea(.container) // Extend to screen edges (removes white areas)
    }
}

/// Reports the fold of iPhone Duo to Kotlin (`FoldStateSource`, read as `LocalFoldState`).
///
/// The reserved-region and hinge APIs are in the iOS 27.1 SDK. Build with the Swift flag
/// `IPHONE_DUO_SDK` (Active Compilation Conditions) to compile them; without it, as on the
/// iOS 26 SDK of CI, this does nothing, and Compose sees a flat display. On the 27.1 SDK the
/// calls still check `#available`, so the app runs on older iOS versions.
enum FoldStateBridge {
    static func attach(to host: UIView) {
        #if IPHONE_DUO_SDK
        if #available(iOS 27.1, *) {
            let tracker = DivisionTrackingView()
            tracker.translatesAutoresizingMaskIntoConstraints = false
            tracker.isUserInteractionEnabled = false
            host.addSubview(tracker)
            NSLayoutConstraint.activate([
                tracker.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                tracker.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                tracker.topAnchor.constraint(equalTo: host.topAnchor),
                tracker.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            ])
            tracker.setNeedsUpdateConstraints()

            host.addInteraction(UIHingeInteraction { _, update in
                KmpHelper.shared.reportHinge(status: update.hinge.map { hingeStatus($0.status) })
            })
        }
        #endif
    }

    #if IPHONE_DUO_SDK
    @available(iOS 27.1, *)
    private static func hingeStatus(_ status: UIHinge.Status) -> HingeStatus {
        switch status {
        case .closed: return .closed
        case .partiallyOpen: return .partiallyOpen
        case .fullyOpen: return .fullyOpen
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
    #endif
}

#if IPHONE_DUO_SDK
/// A transparent view over the whole Compose host view, so its coordinates are the Compose window
/// coordinates (1 pt = 1 dp). UIKit runs `updateConstraints()` again whenever a reserved region
/// that it read changes, so this reports every fold and unfold.
@available(iOS 27.1, *)
private final class DivisionTrackingView: UIView {
    override class var requiresConstraintBasedLayout: Bool { true }

    override func updateConstraints() {
        // Inactive regions are read too, so UIKit also calls again when the fold becomes active.
        let division = reservedRegions(kind: .division, options: .includeInactive).first { $0.isActive }
        if let frame = division?.frame {
            KmpHelper.shared.reportFoldDivision(
                left: Double(frame.minX),
                top: Double(frame.minY),
                width: Double(frame.width),
                height: Double(frame.height)
            )
        } else {
            KmpHelper.shared.clearFoldDivision()
        }
        super.updateConstraints()
    }
}
#endif
