import Flutter
import UIKit
import SkyWay

class FlutterSkywayPlatformView: NSObject, FlutterPlatformView {
    let platformView: UIView
    init(_ platformView: UIView) {
        self.platformView = platformView
        super.init()
    }
    func view() -> UIView {
        return platformView
    }
}

public class SwiftFlutterSkywayPlugin: NSObject {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_skyway", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterSkywayPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(instance, withId: "flutter_skyway/video_view")
    }

    init(registrar: FlutterPluginRegistrar) {
        messenger = registrar.messenger()
        super.init()
    }

    private let messenger: FlutterBinaryMessenger
    private var peers = [String: FlutterSkywayPeer]()
    private let localView = UIView()
    private let remoteView = UIView()

    private func connect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let apiKey = args["apiKey"] as? String,
            let domain = args["domain"] as? String else {
                result(FlutterError(code: "InvalidArguments",
                                    message: "`apiKey` and `domain` must not be null.",
                                    details: nil))
                return
        }
        let option = SKWPeerOption()
        option.key = apiKey
        option.domain = domain
        guard let peer = SKWPeer(options: option) else {
            result(FlutterError(code: "Unknown", message: "Peer creation failed.", details: nil))
            return
        }
        let peerWrapper = FlutterSkywayPeer(peer: peer)
        let tmpId = String(format: "%x", arc4random_uniform(UInt32.max))
        peers[tmpId] = peerWrapper

        peerWrapper.connect { [weak self] (peerId, error) in
            guard let peerId = peerId else {
                self?.peers.removeValue(forKey: tmpId)
                result(error)
                return
            }
            if let peer = self?.peers.removeValue(forKey: tmpId) {
                self?.peers[peerId] = peer
                peer.eventChannel = self?.createEventChannel(peerId: peerId)
            }
            result(peerId)
        }
    }

    private func createEventChannel(peerId: String) -> FlutterEventChannel? {
        return FlutterEventChannel(name: "flutter_skyway/\(peerId)", binaryMessenger: self.messenger)
    }

    private func destroy(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let peerId = args["peerId"] as? String else {
                result(nil)
                return
        }
        if let peer = peers[peerId] {
            peer.destroy()
        }
        peers.removeValue(forKey: peerId)
        result(nil)
    }

    private func listAllPeers(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let peerId = args["peerId"] as? String,
            let peer = peers[peerId] else {
                result([String]())
                return
        }
        peer.listAllPeers { allPeers in
            result(allPeers)
        }
    }

    private func call(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let peerId = args["peerId"] as? String,
            let targetPeerId = args["targetPeerId"] as? String,
            let peer = peers[peerId] else {
                result(FlutterError(code: "InvalidArguments", message: nil, details: nil))
                return
        }
        peer.call(to: targetPeerId) { (error) in
            result(error)
        }
    }

    private func accept(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let peerId = args["peerId"] as? String,
            let remotePeerId = args["remotePeerId"] as? String,
            let peer = peers[peerId] else {
                result(FlutterError(code: "InvalidArguments", message: nil, details: nil))
                return
        }
        peer.accept(remotePeerId: remotePeerId) { (error) in
            result(error)
        }
    }

    private func reject(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let peerId = args["peerId"] as? String,
            let remotePeerId = args["remotePeerId"] as? String,
            let peer = peers[peerId] else {
                result(FlutterError(code: "InvalidArguments", message: nil, details: nil))
                return
        }
        peer.reject(remotePeerId: remotePeerId) { (error) in
            result(error)
        }
    }
}

extension SwiftFlutterSkywayPlugin: FlutterPlugin {
    enum Method: String {
        case connect
        case destroy
        case listAllPeers
        case call
        case accept
        case reject
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let method = Method.init(rawValue: call.method) else {
            result(FlutterMethodNotImplemented)
            return
        }
        switch method {
        case .connect:      connect(call, result: result)
        case .destroy:      destroy(call, result: result)
        case .listAllPeers: listAllPeers(call, result: result)
        case .call:         self.call(call, result: result)
        case .accept:       accept(call, result: result)
        case .reject:       reject(call, result: result)
        }
    }
}

extension SwiftFlutterSkywayPlugin: FlutterPlatformViewFactory {
    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        remoteView.frame = frame
        remoteView.backgroundColor = .black
        if let view = peers.first?.value.remoteStreamView {
            view.frame = remoteView.bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            remoteView.addSubview(view)
        }
        return FlutterSkywayPlatformView(remoteView)
    }
}
