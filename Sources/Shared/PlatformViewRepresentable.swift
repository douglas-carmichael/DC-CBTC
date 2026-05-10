import SwiftUI

#if os(macOS)
import AppKit
public typealias PlatformViewRepresentable = NSViewRepresentable
public typealias PlatformViewType = NSView

public protocol CrossPlatformViewRepresentable: NSViewRepresentable {
    associatedtype CustomViewType: NSView
    func makePlatformView(context: Context) -> CustomViewType
    func updatePlatformView(_ view: CustomViewType, context: Context)
}

public extension CrossPlatformViewRepresentable {
    func makeNSView(context: Context) -> CustomViewType {
        makePlatformView(context: context)
    }
    func updateNSView(_ nsView: CustomViewType, context: Context) {
        updatePlatformView(nsView, context: context)
    }
}

#else
import UIKit
public typealias PlatformViewRepresentable = UIViewRepresentable
public typealias PlatformViewType = UIView

public protocol CrossPlatformViewRepresentable: UIViewRepresentable {
    associatedtype CustomViewType: UIView
    func makePlatformView(context: Context) -> CustomViewType
    func updatePlatformView(_ view: CustomViewType, context: Context)
}

public extension CrossPlatformViewRepresentable {
    func makeUIView(context: Context) -> CustomViewType {
        makePlatformView(context: context)
    }
    func updateUIView(_ uiView: CustomViewType, context: Context) {
        updatePlatformView(uiView, context: context)
    }
}
#endif
