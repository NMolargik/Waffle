//
//  LibraryChangeCenterTests.swift
//  WaffleCoreTests
//
//  The change center must multicast (the old closure was single-subscriber: last writer
//  won) and buffer yields for observers that haven't resumed yet.
//

import Testing
import WaffleCore

@Suite("LibraryChangeCenter")
@MainActor
struct LibraryChangeCenterTests {

    @Test("notify multicasts to every active observer")
    func multicast() async {
        let center = LibraryChangeCenter()
        var first = center.changes().makeAsyncIterator()
        var second = center.changes().makeAsyncIterator()

        center.notify()

        #expect(await first.next() != nil)
        #expect(await second.next() != nil)
    }

    @Test("multiple notifies buffer and deliver in order")
    func buffering() async {
        let center = LibraryChangeCenter()
        var iterator = center.changes().makeAsyncIterator()

        center.notify()
        center.notify()

        #expect(await iterator.next() != nil)
        #expect(await iterator.next() != nil)
    }

    @Test("the observe use-case hands out streams from the center")
    func useCaseWrapsCenter() async {
        let center = LibraryChangeCenter()
        let observe: any ObserveLibraryChanges = ObserveLibraryChangesUseCase(center: center)
        var iterator = observe().makeAsyncIterator()

        center.notify()

        #expect(await iterator.next() != nil)
    }
}
