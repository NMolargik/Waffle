//
//  AppError.swift
//  WaffleCore
//
//  A user-presentable error. Presentation (alerts/toasts) lives in the design system's
//  ErrorHandler; this is just the value.
//

import Foundation

public struct AppError: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let isRecoverable: Bool

    public init(title: String, message: String, isRecoverable: Bool = true) {
        self.title = title
        self.message = message
        self.isRecoverable = isRecoverable
    }

    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
}
