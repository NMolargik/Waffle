//
//  Log.swift
//  Waffle
//
//  Per-category loggers for structured diagnostics.
//

import os

nonisolated enum Log {
    private static let subsystem = "com.molargiksoftware.Waffle"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let grid = Logger(subsystem: subsystem, category: "grid")
    static let library = Logger(subsystem: subsystem, category: "library")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let spotlight = Logger(subsystem: subsystem, category: "spotlight")
}
