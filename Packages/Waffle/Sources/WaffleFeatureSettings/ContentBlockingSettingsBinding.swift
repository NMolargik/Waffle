//
//  ContentBlockingSettingsBinding.swift
//  WaffleFeatureSettings
//
//  What the settings sheet needs from content blocking, as plain values and closures so
//  the Settings module doesn't depend on the Grid feature. Composition builds it.
//

import SwiftUI

public struct ContentBlockingSettingsBinding {
    public let isEnabled: Binding<Bool>
    public let exceptionHosts: [String]
    public let removeException: (String) -> Void
    public let listTitles: [String]

    public init(
        isEnabled: Binding<Bool>,
        exceptionHosts: [String],
        removeException: @escaping (String) -> Void,
        listTitles: [String]
    ) {
        self.isEnabled = isEnabled
        self.exceptionHosts = exceptionHosts
        self.removeException = removeException
        self.listTitles = listTitles
    }
}
