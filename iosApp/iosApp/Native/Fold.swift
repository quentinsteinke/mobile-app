import SwiftUI
import UIKit

/// How iPhone Duo is held, for the native screens.
enum FoldPosture {
    /// Flat open, folded shut, or a phone without a fold.
    case flat
    /// Partly open with a vertical fold, held like a book.
    case book
    /// Partly open with a horizontal fold, standing on its lower half.
    case tabletop
}

/// The fold of iPhone Duo where it crosses one view, in that view's coordinates.
struct FoldDivision: Equatable {
    var frame: CGRect

    var posture: FoldPosture { frame.height > frame.width ? .book : .tabletop }

    /// Whether the fold splits a view of [size] into two parts of at least [minimumPart].
    func splits(_ size: CGSize, minimumPart: CGFloat = 120) -> Bool {
        switch posture {
        case .book: frame.minX >= minimumPart && size.width - frame.maxX >= minimumPart
        case .tabletop: frame.minY >= minimumPart && size.height - frame.maxY >= minimumPart
        case .flat: false
        }
    }
}

/// Extra space on each side of the fold, so nothing sits on the hinge.
let foldGutter: CGFloat = 16

extension View {
    /// Reports the fold where it crosses this view, in this view's coordinates, or nil while no
    /// fold divides the display. The reserved-region API is in the iOS 27.1 SDK, so it compiles
    /// only with the Swift flag `IPHONE_DUO_SDK`; without it the display stays flat.
    func readsFold(into division: Binding<FoldDivision?>) -> some View {
        background(FoldProbe(division: division).allowsHitTesting(false))
    }
}

private struct FoldProbe: UIViewRepresentable {
    @Binding var division: FoldDivision?

    func makeUIView(context: Context) -> UIView {
        #if IPHONE_DUO_SDK
        if #available(iOS 27.1, *) { return FoldProbeView() }
        #endif
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        #if IPHONE_DUO_SDK
        if #available(iOS 27.1, *), let probe = uiView as? FoldProbeView {
            probe.onChange = { division = $0 }
        }
        #endif
    }
}

#if IPHONE_DUO_SDK
/// UIKit runs `updateConstraints()` again whenever a reserved region that it read changes, so
/// this reports every fold and unfold. A move or resize of the view runs a layout, which asks
/// for the constraints again.
@available(iOS 27.1, *)
private final class FoldProbeView: UIView {
    var onChange: ((FoldDivision?) -> Void)? {
        didSet { reported = .none; setNeedsUpdateConstraints() }
    }
    private var reported: FoldDivision??

    override class var requiresConstraintBasedLayout: Bool { true }

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsUpdateConstraints()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsUpdateConstraints()
    }

    override func updateConstraints() {
        // Inactive regions are read too, so UIKit also calls again when the fold becomes active.
        let region = reservedRegions(kind: .division, options: .includeInactive).first { $0.isActive }
        let division = region.map { FoldDivision(frame: $0.frame.intersection(bounds)) }
            .flatMap { $0.frame.isEmpty ? nil : $0 }
        if reported != .some(division) {
            reported = .some(division)
            // Not during the layout pass that SwiftUI may be running.
            DispatchQueue.main.async { [weak self] in self?.onChange?(division) }
        }
        super.updateConstraints()
    }
}
#endif

/// Two parts laid out around the fold: side by side and split at the fold in book posture,
/// above and below it in tabletop posture. Without a fold across this view, [fallback] decides:
/// side by side, with [firstWidth] for the first part (half if nil), or stacked.
struct FoldSplit<First: View, Second: View>: View {
    var fallback: Axis
    var firstWidth: CGFloat?
    @ViewBuilder var first: () -> First
    @ViewBuilder var second: () -> Second

    @State private var division: FoldDivision?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let division, division.splits(geometry.size) {
                    let frame = division.frame
                    if division.posture == .book {
                        HStack(spacing: 0) {
                            first().frame(width: max(0, frame.minX - foldGutter))
                            Color.clear.frame(width: frame.width + 2 * foldGutter)
                            second().frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 0) {
                            first().frame(height: max(0, frame.minY - foldGutter))
                            Color.clear.frame(height: frame.height + 2 * foldGutter)
                            second().frame(maxHeight: .infinity)
                        }
                    }
                } else if fallback == .horizontal {
                    HStack(spacing: 0) {
                        first().frame(width: firstWidth ?? geometry.size.width / 2)
                        second().frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        first()
                        second()
                    }
                }
            }
        }
        .readsFold(into: $division)
    }
}
