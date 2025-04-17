// CrossExamUI.swift
// CourtRoomSim

import UIKit

/// UIKit helper that pops an objection dialog during cross‑examination.
final class CrossExamUI {
    static let shared = CrossExamUI()
    private init() {}

    private var current: (question: String, completion: (Bool, String) -> Void)?

    /// Present the objection/allow UI for the given question.
    func present(question: String,
                 completion: @escaping (Bool, String) -> Void)
    {
        current = (question, completion)
        DispatchQueue.main.async {
            guard let top = CrossExamUI.topViewController() else { return }
            top.present(self.makeAlert(for: question), animated: true)
        }
    }

    // MARK: – Build the UIAlertController

    private func makeAlert(for q: String) -> UIViewController {
        let alert = UIAlertController(
            title: "Opponent Question",
            message: q,
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "Objection reason (optional)" }
        alert.addAction(.init(title: "Object", style: .destructive) { _ in
            let reason = alert.textFields?.first?.text ?? "Objection"
            self.finish(allowed: false, reason: reason)
        })
        alert.addAction(.init(title: "Allow", style: .default) { _ in
            self.finish(allowed: true, reason: "")
        })
        return alert
    }

    private func finish(allowed: Bool, reason: String) {
        guard let pair = current else { return }
        current = nil
        pair.completion(allowed, reason)
    }

    // MARK: – Find the topmost UIViewController

    private static func topViewController() -> UIViewController? {
        // Grab the current active scene's key window
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        for scene in scenes where scene.activationState == .foregroundActive {
            if let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                return traverse(from: root)
            }
        }
        return nil
    }

    private static func traverse(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return traverse(from: presented)
        }
        if let nav = vc as? UINavigationController, let top = nav.topViewController {
            return traverse(from: top)
        }
        if let tab = vc as? UITabBarController, let sel = tab.selectedViewController {
            return traverse(from: sel)
        }
        return vc
    }
}
