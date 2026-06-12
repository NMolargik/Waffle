//
//  KeyValueStoring.swift
//  Waffle
//
//  Seam over UserDefaults so persistence can be faked in tests.
//

import Foundation

/// Abstraction over UserDefaults-style key/value storage.
///
/// Declared with UserDefaults' exact method signatures so UserDefaults
/// conforms for free.
protocol KeyValueStoring: AnyObject {
    func data(forKey defaultName: String) -> Data?
    func string(forKey defaultName: String) -> String?
    func bool(forKey defaultName: String) -> Bool
    func integer(forKey defaultName: String) -> Int
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: KeyValueStoring {}
