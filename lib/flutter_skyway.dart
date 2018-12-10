import 'dart:async';

import 'package:flutter/services.dart';

final MethodChannel _channel = const MethodChannel('flutter_skyway');

class Skyway {
  static Future<SkywayPeer> connect(String apiKey, String domain) async {
    final String peerId = await _channel.invokeMethod('connect', {
      'apiKey': apiKey,
      'domain': domain,
    });
    print('peerId: $peerId');
    return SkywayPeer(peerId: peerId)..initialize();
  }
}

typedef ReceiveCallCallback = void Function(String remotePeerId);

class SkywayPeer {
  final String peerId;
  SkywayPeer({this.peerId});

  ReceiveCallCallback onReceiveCall;

  StreamSubscription<dynamic> _eventSubscription;

  void initialize() {
    _eventSubscription = EventChannel('flutter_skyway/$peerId')
        .receiveBroadcastStream()
        .listen(_eventListener, onError: _errorListener);
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
  }

  void _eventListener(dynamic event) {
    final Map<dynamic, dynamic> map = event;
    switch (map['event']) {
      case 'onCall':
        print('onCall: $map');
        if (onReceiveCall != null) {
          onReceiveCall(map['from']);
        }
        break;
    }
  }

  void _errorListener(Object obj) {
    print('onError: $obj');
  }

  Future<void> destroy() async {
    _eventSubscription?.cancel();
    return await _channel.invokeMethod('destroy', {
      'peerId': peerId,
    });
  }

  Future<List<String>> listAllPeers() async {
    List<dynamic> peers = await _channel.invokeMethod('listAllPeers', {
      'peerId': peerId,
    });
    return peers.cast<String>();
  }

  Future<void> call(String targetPeerId) async {
    return await _channel.invokeMethod('call', {
      'peerId': peerId,
      'targetPeerId': targetPeerId,
    });
  }

  Future<void> accept(String remotePeerId) async {
    return await _channel.invokeMethod('accept', {
      'peerId': peerId,
      'remotePeerId': remotePeerId,
    });
  }

  Future<void> reject(String remotePeerId) async {
    return await _channel.invokeMethod('reject', {
      'peerId': peerId,
      'remotePeerId': remotePeerId,
    });
  }
}
