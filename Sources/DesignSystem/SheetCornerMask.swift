import SwiftUI
import UIKit

// MARK: - Public modifier

extension View {
    /// Applies an asymmetric corner mask to the sheet presentation, bypassing
    /// SwiftUI's `presentationCornerRadius` (which can only set one value for
    /// all four corners).
    ///
    /// Place this modifier on the sheet's root content view. It finds the UIKit
    /// container that wraps both the system background and the hosting
    /// controller's view, removes the system's `cornerRadius`, and replaces it
    /// with a `CAShapeLayer` mask that has independent top and bottom radii.
    func sheetCornerMask(
        top:    CGFloat = 16,
        bottom: CGFloat = UIScreen.main.displayCornerRadius
    ) -> some View {
        background(
            _SheetMaskInstaller(topRadius: top, bottomRadius: bottom)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
    }
}

// MARK: - UIViewRepresentable bridge

private struct _SheetMaskInstaller: UIViewRepresentable {
    let topRadius:    CGFloat
    let bottomRadius: CGFloat

    func makeUIView(context: Context) -> _MaskInstallerView {
        _MaskInstallerView(topRadius: topRadius, bottomRadius: bottomRadius)
    }

    func updateUIView(_ uiView: _MaskInstallerView, context: Context) {
        uiView.topRadius    = topRadius
        uiView.bottomRadius = bottomRadius
        uiView.reapplyMask()
    }
}

// MARK: - UIView that installs the CAShapeLayer mask

final class _MaskInstallerView: UIView {
    var topRadius:    CGFloat
    var bottomRadius: CGFloat

    private weak var targetView:      UIView?
    private var boundsObservation:    NSKeyValueObservation?

    init(topRadius: CGFloat, bottomRadius: CGFloat) {
        self.topRadius    = topRadius
        self.bottomRadius = bottomRadius
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        // Defer one run-loop so the sheet has been fully laid out.
        DispatchQueue.main.async { [weak self] in self?.installMask() }
    }

    func reapplyMask() {
        if let v = targetView { applyShape(to: v) }
    }

    // MARK: - Finding the target

    /// Traverses the responder chain to find the UIHostingController, then
    /// returns its view's superview — the UIKit sheet container that owns the
    /// system background layer AND the content view.  Masking *this* view
    /// clips everything (background + content) at once.
    private func findTarget() -> UIView? {
        var responder: UIResponder? = next
        while let r = responder {
            if let vc = r as? UIViewController {
                return vc.view.superview ?? vc.view
            }
            responder = r.next
        }
        return nil
    }

    // MARK: - Installing

    private func installMask() {
        guard let v = findTarget() else { return }
        targetView = v

        // Remove the system's uniform corner radius — we own the shape now.
        v.layer.cornerRadius  = 0
        v.layer.maskedCorners = []

        applyShape(to: v)

        // Re-apply whenever the container is resized (e.g. detent switch).
        boundsObservation = v.observe(\.bounds, options: [.new]) { [weak self] view, _ in
            DispatchQueue.main.async { self?.applyShape(to: view) }
        }
    }

    // MARK: - Drawing the mask path

    private func applyShape(to view: UIView) {
        let b  = view.bounds
        guard b.width > 0, b.height > 0 else { return }

        let tr = min(topRadius,    b.width / 2)
        let br = min(bottomRadius, b.width / 2)

        let path = UIBezierPath()
        // Start just right of the top-left arc
        path.move(to: CGPoint(x: tr, y: 0))
        // Top edge →
        path.addLine(to: CGPoint(x: b.width - tr, y: 0))
        // Top-right arc ↓
        path.addArc(withCenter: CGPoint(x: b.width - tr, y: tr),
                    radius: tr, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        // Right edge ↓
        path.addLine(to: CGPoint(x: b.width, y: b.height - br))
        // Bottom-right arc ←
        path.addArc(withCenter: CGPoint(x: b.width - br, y: b.height - br),
                    radius: br, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        // Bottom edge ←
        path.addLine(to: CGPoint(x: br, y: b.height))
        // Bottom-left arc ↑
        path.addArc(withCenter: CGPoint(x: br, y: b.height - br),
                    radius: br, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        // Left edge ↑
        path.addLine(to: CGPoint(x: 0, y: tr))
        // Top-left arc →
        path.addArc(withCenter: CGPoint(x: tr, y: tr),
                    radius: tr, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        path.close()

        let maskLayer       = CAShapeLayer()
        maskLayer.path      = path.cgPath
        view.layer.mask     = maskLayer
    }
}
