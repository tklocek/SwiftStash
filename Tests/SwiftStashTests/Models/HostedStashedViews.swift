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
import SwiftStashUI
import SwiftUI

/// Records what a hosted `@Stashed` rendered, and hands out its binding.
@MainActor
final class StashedProbe {
    private(set) var renderedValue: Int?
    private(set) var renderCount = 0
    private var binding: Binding<Int>?

    func record(_ value: Int, binding: Binding<Int>) {
        renderedValue = value
        renderCount += 1
        self.binding = binding
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
        probe.record(value, binding: $value)
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

    /// Yields the main actor so KVO deliveries (hopped onto it in a `Task`) and the
    /// debounced notification can reach the view, then renders.
    func settle() async {
        try? await Task.sleep(nanoseconds: 50_000_000)
        render()
    }

    /// Lets pending invalidations (bindings, debounced notifications) reach the view.
    func render() {
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        hostingView.layoutSubtreeIfNeeded()
    }
}
#endif
