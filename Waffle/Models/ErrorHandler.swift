//
//  ErrorHandler.swift
//  Waffle
//
//  Created by Nick Molargik on 1/2/26.
//

import SwiftUI

/// Represents an error that can be displayed to the user
struct AppError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let isRecoverable: Bool

    init(title: String, message: String, isRecoverable: Bool = true) {
        self.title = title
        self.message = message
        self.isRecoverable = isRecoverable
    }

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
}

/// Observable error handler for surfacing errors to the UI
@Observable
@MainActor
final class ErrorHandler {
    private(set) var currentError: AppError?
    private(set) var toastMessage: String?

    private var toastDismissTask: Task<Void, Never>?

    /// Show an error alert to the user
    func show(error: AppError) {
        currentError = error
    }

    /// Show a quick toast message (auto-dismisses)
    func showToast(_ message: String, duration: TimeInterval = 3.0) {
        toastDismissTask?.cancel()
        toastMessage = message

        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }

    /// Dismiss the current error
    func dismiss() {
        currentError = nil
    }

    /// Dismiss the toast immediately
    func dismissToast() {
        toastDismissTask?.cancel()
        toastMessage = nil
    }

    // MARK: - Convenience Methods

    func showDataError(_ message: String) {
        show(error: AppError(
            title: "Data Error",
            message: message,
            isRecoverable: true
        ))
    }

    func showNetworkError(_ message: String) {
        show(error: AppError(
            title: "Network Error",
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

extension View {
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

extension View {
    func errorAlert(_ error: Binding<AppError?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}
