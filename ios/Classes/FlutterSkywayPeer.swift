import Flutter
import UIKit
import SkyWay

final class FlutterSkywayPeer: NSObject {

    private let peer: SKWPeer
    init(peer: SKWPeer) {
        self.peer = peer
        super.init()
    }

    var eventChannel: FlutterEventChannel? {
        didSet {
            oldValue?.setStreamHandler(nil)
            eventChannel?.setStreamHandler(self)
        }
    }
    var eventSink: FlutterEventSink?

    private var mediaConnection: SKWMediaConnection?
    private var localStream: SKWMediaStream?
    private var remoteStream: SKWMediaStream?

    let localStreamView = SKWVideo()
    let remoteStreamView = SKWVideo()

    var identity: String? {
        return peer.identity
    }

    func connect(completion: @escaping (String?, FlutterError?) -> Void) {
        peer.on(.PEER_EVENT_ERROR) { (error) in
            if let error = error as? SKWPeerError {
                completion(nil, FlutterError(code: "SKWPeerError", message: error.message, details: nil))
            }
        }
        peer.on(.PEER_EVENT_OPEN) { (peerId) in
            if let peerId = peerId as? String {
                completion(peerId, nil)
            }
        }
        peer.on(.PEER_EVENT_CALL) { [weak self] (connection) in
            if let connection = connection as? SKWMediaConnection {
                self?.onCall(mediaConnection: connection)
            }
        }
    }

    func destroy() {
        mediaConnection?.close()
        peer.destroy()
        localStreamView.removeFromSuperview()
        remoteStreamView.removeFromSuperview()
    }

    func listAllPeers(completion: @escaping ([String]) -> Void) {
        peer.listAllPeers { allPeers in
            completion((allPeers as? [String]) ?? [String]())
        }
    }

    func call(to targetPeerId: String, completion: @escaping (FlutterError?) -> Void) {
        guard mediaConnection == nil else {
            completion(FlutterError(code: "InvalidState", message: nil, details: nil))
            return
        }
        createLocalStream()
        let option = SKWCallOption()
        guard let mediaConnection = peer.call(withId: targetPeerId, stream: self.localStream, options: option) else {
            completion(FlutterError(code: "PeerError", message: "failed to call :\(targetPeerId)", details: nil))
            return
        }
        setUpMediaConnectionCallbacks(mediaConnection: mediaConnection)
        self.mediaConnection = mediaConnection
    }

    func accept(remotePeerId: String, completion: @escaping (FlutterError?) -> Void) {
        guard let mediaConnection = mediaConnection,
            mediaConnection.peer == remotePeerId else {
                completion(FlutterError(code: "InvalidState", message: nil, details: nil))
                return
        }
        createLocalStream()
        setUpMediaConnectionCallbacks(mediaConnection: mediaConnection)
        mediaConnection.answer(self.localStream)
    }

    func reject(remotePeerId: String, completion: @escaping (FlutterError?) -> Void) {
        if mediaConnection?.peer == remotePeerId {
            mediaConnection?.close()
        }
        mediaConnection = nil
    }

    // MARK: -

    private func createLocalStream() {
        SKWNavigator.initialize(peer)
        let constraints = SKWMediaConstraints()
        guard let localStream = SKWNavigator.getUserMedia(constraints) else { return }

        localStream.addVideoRenderer(localStreamView, track: 0)
        self.localStream = localStream
    }

    private func setUpMediaConnectionCallbacks(mediaConnection: SKWMediaConnection) {
        mediaConnection.on(.MEDIACONNECTION_EVENT_STREAM) { [weak self] remoteStream in
            if let remoteStream = remoteStream as? SKWMediaStream {
                DispatchQueue.main.async {
                    self?.setUpRemoteStream(remoteStream)
                }
            }
        }
        mediaConnection.on(.MEDIACONNECTION_EVENT_CLOSE) { [weak self] (remoteStream) in
            if let remoteStream = remoteStream as? SKWMediaStream {
                DispatchQueue.main.async {
                    self?.tearDownRemoteStream(remoteStream)
                }
            }
        }
    }

    private func setUpRemoteStream(_ remoteStream: SKWMediaStream) {
        remoteStream.addVideoRenderer(remoteStreamView, track: 0)
        self.remoteStream = remoteStream
    }

    private func tearDownRemoteStream(_ remoteStream: SKWMediaStream) {
        remoteStream.removeVideoRenderer(remoteStreamView, track: 0)
        self.remoteStream = nil
    }

    private func onCall(mediaConnection: SKWMediaConnection) {
        guard self.mediaConnection == nil,
            let from = mediaConnection.peer else {
            mediaConnection.close()
            return
        }
        self.mediaConnection = mediaConnection
        eventSink?(["event": "onCall", "from": from])
    }
}

extension FlutterSkywayPeer: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
