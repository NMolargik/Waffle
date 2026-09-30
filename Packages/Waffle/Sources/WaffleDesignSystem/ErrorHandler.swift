//
//  ErrorHandler.swift
//  WaffleDesignSystem
//
//  Observable error/toast presentation for the UI. Repositories throw typed errors;
//  view models catch them and surface here — the data layer never touches this.
//

import SwiftUI
import WaffleCore

@Observable
@MainActor
public final class ErrorHandler {
    public private(set) var currentError: AppError?
    public private(set) var toastMessage: String?

    private var toastDismissTask: Task<Void, Never>?

    public init() {}

    /// Show an error alert to the user
    public func show(error: AppError) {
        currentError = error
    }

    /// Show a quick toast message (auto-dismisses)
    public func showToast(_ message: String, duration: TimeInterval = 3.0) {
        toastDismissTask?.cancel()
        toastMessage = message

        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }

    /// Dismiss the current error
    public func dismiss() {
        currentError = nil
    }

    /// Dismiss the toast immediately
    public func dismissToast() {
        toastDismissTask?.cancel()
        toastMessage = nil
    }

    // MARK: - Convenience

    public func showDataError(_ message: String) {
        show(error: AppError(
            title: String(localized: "Data Error"),
            message: message,
            isRecoverable: true
        ))
    }

    /// Surfaces a typed persistence failure as a data-error alert.
    public func showPersistenceError(_ error: PersistenceError) {
        showDataError(error.localizedDescription)
    }

    public func showNetworkError(_ message: String) {
        show(error: AppError(
            title: String(localized: "Network Error"),
            message: message,
            isRecoverable: true
        ))
    }
}

// MARK: - Toast View Modifier

struct ToastModifier: ViewModifier {
    let message: String?
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.waffleTertiary.opacity(0.9))
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    )
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture {
                        onDismiss()
                    }
            }
        }
        .animation(.spring(response: 0.3), value: message)
    }
}

public extension View {
    func toast(message: String?, onDismiss: @escaping () -> Void) -> some View {
        modifier(ToastModifier(message: message, onDismiss: onDismiss))
    }
}

// MARK: - Error Alert Modifier

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppError?

    func body(content: Content) -> some View {
        content.alert(
            error?.title ?? "Error",
            isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            ),
            presenting: error
        ) { _ in
            Button("OK", role: .cancel) {
                error = nil
            }
        } message: { error in
            Text(error.message)
        }
    }
}

public extension View {
    func errorAlert(_ error: Binding<AppError?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}
