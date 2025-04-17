import UIKit

/// UIKit helper that pops a modal allowing the user to
/// object or allow an opposing‑counsel question during trial.
final class CrossExamUI {

    static let shared = CrossExamUI()
    private init() {}

    private var current: (String, (Bool,String)->Void)?

    /// Present objection dialog.
    func present(question: String,
                 completion: @escaping (Bool, String) -> Void)
    {
        current = (question, completion)

        DispatchQueue.main.async {
            guard let win = UIApplication.shared.windows.first else { return }
            win.rootViewController?.present(self.makeVC(question), animated: true)
        }
    }

    // MARK: – private
    private func makeVC(_ q: String) -> UIViewController {
        let vc = UIAlertController(title: "Opponent Question",
                                   message: q,
                                   preferredStyle: .alert)
        vc.addTextField { $0.placeholder = "Objection reason (optional)" }

        vc.addAction(UIAlertAction(title: "Object", style: .destructive) { _ in
            let reason = vc.textFields?.first?.text ?? "Objection"
            self.finish(allowed: false, reason: reason)
        })

        vc.addAction(UIAlertAction(title: "Allow", style: .default) { _ in
            self.finish(allowed: true, reason: "")
        })

        return vc
    }

    private func finish(allowed: Bool, reason: String) {
        guard let c = current else { return }
        current = nil
        c.1(allowed, reason)
    }
}
