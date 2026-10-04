//
//  HostedStashedViews.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

#if canImport(AppKit)
import AppKit
import Foundation
import SwiftStash
@testable import SwiftStashUI
import Combine
import SwiftUI

/// Records what a hosted `@Stashed` rendered, and hands out its binding.
@MainActor
final class StashedProbe {
    private(set) var renderedValues: [Int] = []
    private var binding: Binding<Int>?
    /// The rendered wrapper's published values, to await a delivery before rendering again.
    private(set) var values: AnyPublisher<Int, Never>?

    var renderedValue: Int? { renderedValues.last }

    func record(_ value: Int, binding: Binding<Int>, values: AnyPublisher<Int, Never>) {
        renderedValues.append(value)
        self.binding = binding
        self.values = values
    }

    /// Writes through the projected `Binding`, as a control in the view would.
    func write(_ value: Int) {
        binding?.wrappedValue = value
    }
}

/// A view with one `@Stashed` Int, reporting every render to its probe.
struct StashedProbeView: View {
    @Stashed private var value: Int
    private let probe: StashedProbe

    init(key: String, store: UserDefaults? = nil, probe: StashedProbe) {
        _value = Stashed(key: key, defaultValue: 0, store: store)
        self.probe = probe
    }

    init(scopedKey: TestScopedKey, probe: StashedProbe) {
        _value = Stashed(key: scopedKey, defaultValue: 0)
        self.probe = probe
    }

    var body: some View {
        probe.record(value, binding: $value, values: _value.currentValues)
        return Text("\(value)")
    }
}

/// Hosts a SwiftUI view in an `NSHostingView` and renders it synchronously.
@MainActor
final class HostedView<Content: View> {
    private let hostingView: NSHostingView<Content>

    init(_ rootView: Content) {
        hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        render()
    }

    /// Replaces the root view, as a parent re-render with new inputs would.
    func update(_ rootView: Content) {
        hostingView.rootView = rootView
        render()
    }

    /// Renders the view if anything invalidated it since the last render.
    func render() {
        hostingView.layoutSubtreeIfNeeded()
    }
}
#endif
