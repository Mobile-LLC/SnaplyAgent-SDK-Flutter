//
//  SnaplyAgentPlugin.swift
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import Flutter
import SnaplyAgent
import UIKit

/// Bridges the Dart API to the native SDK and hands the Flutter view over to it as a hosted view.
public class SnaplyAgentPlugin: NSObject, FlutterPlugin, SnaplyHostedView {
    private let channel: FlutterMethodChannel
    private weak var registrar: FlutterPluginRegistrar?
    private weak var flutterView: UIView?

    public var controlMode: SnaplyHostedControlMode { .exclusive }

    private init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
        self.channel = channel
        self.registrar = registrar
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "snaply_agent", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(SnaplyAgentPlugin(channel: channel, registrar: registrar), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        MainActor.assumeIsolated {
            switch call.method {
            case "configure":
                configure(arguments, result: result)
            case "identify":
                Snaply.identify(
                    id: arguments["id"] as? String ?? "",
                    name: arguments["name"] as? String,
                    phone: arguments["phone"] as? String,
                    identitySignature: arguments["identitySignature"] as? String
                )
                result(nil)
            case "reset":
                Snaply.reset()
                result(nil)
            case "supportCode":
                result(Snaply.supportCode())
            case "showSupportCode":
                Snaply.showSupportCode()
                result(nil)
            case "stop":
                Snaply.stop()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    @MainActor
    private func configure(_ arguments: [String: Any], result: @escaping FlutterResult) {
        var environment = SnaplyEnvironment.live
        if let custom = arguments["environment"] as? String {
            guard let url = URL(string: custom) else {
                return result(FlutterError(code: "insecure_environment", message: "environment is not a URL.", details: 0))
            }
            environment = .custom(url)
        }
        Snaply.on(callbacks)
        handOver(locateFlutterView())
        Snaply.configure(
            key: arguments["key"] as? String ?? "",
            environment: environment,
            user: (arguments["userId"] as? String).map { SnaplyUser(id: $0, name: arguments["userName"] as? String) },
            collectVendorId: arguments["collectVendorId"] as? Bool ?? true,
            language: arguments["language"] as? String ?? "en"
        ) { error in
            DispatchQueue.main.async {
                guard let error else { return result(nil) }
                let snaply = error as? SnaplyError
                result(FlutterError(code: snaply?.code ?? "error", message: snaply?.message ?? error.localizedDescription, details: snaply?.status ?? 0))
            }
        }
    }

    @MainActor
    private func handOver(_ view: UIView?) {
        guard view !== flutterView else { return }
        if let previous = flutterView { Snaply.registerHostedView(previous, host: nil) }
        flutterView = view
        if let view { Snaply.registerHostedView(view, host: self) }
    }

    @MainActor
    private func locateFlutterView() -> UIView? {
        if let view = registrar?.viewController?.view { return view }
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        for window in windows {
            var controller = window.rootViewController
            while let current = controller {
                if let flutter = current as? FlutterViewController { return flutter.view }
                if let child = current.children.first(where: { $0 is FlutterViewController }) { return child.view }
                controller = current.presentedViewController
            }
        }
        return nil
    }

    @MainActor
    public func snapshot(_ request: SnaplyHostedSnapshotRequest, completion: @escaping (SnaplyHostedSnapshot?) -> Void) {
        if flutterView == nil { handOver(locateFlutterView()) }
        let rules = request.rules.map { rule -> [String: Any?] in
            ["kind": rule.kind == SnaplyRedactionRule.kindIdentifier ? "id" : "text", "value": rule.value, "label": rule.label]
        }
        channel.invokeMethod("snapshot", arguments: ["width": request.width, "height": request.height, "rules": rules]) { frame in
            completion(Self.decode(frame))
        }
    }

    private static func decode(_ frame: Any?) -> SnaplyHostedSnapshot? {
        guard let map = frame as? [String: Any],
              let width = map["width"] as? Int, let height = map["height"] as? Int, width > 0, height > 0,
              let pixels = (map["pixels"] as? FlutterStandardTypedData)?.data, pixels.count == width * height * 4,
              let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(
                  width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              ) else { return nil }
        let hidden = (map["hidden"] as? FlutterStandardTypedData)?.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) } ?? []
        let labels = map["labels"] as? [Any?] ?? []
        let redactions = (0..<hidden.count / 4).map { index in
            SnaplyHostedRedaction(
                bounds: CGRect(x: hidden[index * 4], y: hidden[index * 4 + 1], width: hidden[index * 4 + 2] - hidden[index * 4], height: hidden[index * 4 + 3] - hidden[index * 4 + 1]),
                label: index < labels.count ? labels[index] as? String : nil
            )
        }
        return SnaplyHostedSnapshot(image: image, redactions: redactions)
    }

    @MainActor
    public func control(_ input: SnaplyHostedInput) -> Bool {
        let action: String
        switch input.action {
        case .tap: action = "tap"
        case .scroll: action = "scroll"
        case .type: action = "type"
        case .key: action = "key"
        }
        channel.invokeMethod("control", arguments: [
            "action": action, "x": Double(input.point.x), "y": Double(input.point.y),
            "dx": Double(input.delta.x), "dy": Double(input.delta.y), "text": input.text, "key": input.key,
        ] as [String: Any?])
        return true
    }

    private var callbacks: SnaplyCallbacks {
        SnaplyCallbacks(
            onRequestShown: { [weak self] in self?.emit("requestShown") },
            onAllowed: { [weak self] capture in self?.emit("allowed", ["captureId": capture.captureId, "imageUrl": capture.imageUrl]) },
            onDenied: { [weak self] in self?.emit("denied") },
            onExpired: { [weak self] in self?.emit("expired") },
            onError: { [weak self] error in
                let snaply = error as? SnaplyError
                self?.emit("error", ["code": snaply?.code ?? "error", "message": snaply?.message ?? error.localizedDescription, "status": snaply?.status ?? 0])
            },
            onRemoteControl: { [weak self] active in self?.emit("remoteControl", ["active": active]) },
            onLiveEnded: { [weak self] session in self?.emit("liveEnded", ["sessionId": session.sessionId]) }
        )
    }

    private func emit(_ name: String, _ fields: [String: Any] = [:]) {
        channel.invokeMethod("event", arguments: fields.merging(["name": name]) { _, new in new })
    }
}
