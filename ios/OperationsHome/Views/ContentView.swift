import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var router: NFCDeepLinkRouter
    @StateObject private var session = SessionStore()
    @StateObject private var sync = SyncEngine()

    var body: some View {
        Group {
            if session.token == nil {
                LoginView(session: session, context: context)
            } else {
                HomeView(session: session, sync: sync, router: router)
            }
        }
        .background(KeyboardDismissOnTapInstaller())
        .onOpenURL { router.handle($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            router.handle(url)
        }
        .task {
            await NotificationScheduler().requestAuthorization()
        }
        .task(id: session.token) {
            await session.refreshUser()
        }
    }
}

private struct KeyboardDismissOnTapInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardDismissTapView {
        KeyboardDismissTapView()
    }

    func updateUIView(_ uiView: KeyboardDismissTapView, context: Context) {}

    static func dismantleUIView(_ uiView: KeyboardDismissTapView, coordinator: ()) {
        uiView.removeDismissGesture()
    }
}

private final class KeyboardDismissTapView: UIView, UIGestureRecognizerDelegate {
    private lazy var dismissGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        gesture.cancelsTouchesInView = false
        gesture.delegate = self
        return gesture
    }()

    override func didMoveToWindow() {
        super.didMoveToWindow()

        guard let window, dismissGesture.view !== window else { return }
        dismissGesture.view?.removeGestureRecognizer(dismissGesture)
        window.addGestureRecognizer(dismissGesture)
    }

    func removeDismissGesture() {
        dismissGesture.view?.removeGestureRecognizer(dismissGesture)
    }

    @objc private func dismissKeyboard() {
        window?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let currentView = view {
            if currentView is UITextField || currentView is UITextView {
                return false
            }
            view = currentView.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
