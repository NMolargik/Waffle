//
//  Log.swift
//  WaffleCore
//
//  Per-category loggers for structured diagnostics. Never `print` — files calling
//  `Log` need their own `import os` (member-import visibility).
//

import os

nonisolated public enum Log {
    private static let subsystem = "com.molargiksoftware.Waffle"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let grid = Logger(subsystem: subsystem, category: "grid")
    public static let library = Logger(subsystem: subsystem, category: "library")
    public static let store = Logger(subsystem: subsystem, category: "store")
    public static let spotlight = Logger(subsystem: subsystem, category: "spotlight")
}
