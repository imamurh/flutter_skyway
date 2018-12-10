import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_skyway/flutter_skyway.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  State<StatefulWidget> createState() => new _HomeState();
}

class _HomeState extends State<HomePage> {
  final String apiKey = 'YOUR_API_KEY';
  final String domain = 'localhost';
  String status = '';
  bool isConnecting = false;
  SkywayPeer peer;
  List<String> peers;

  bool get isConnected {
    return peer != null;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SkyWay Plugin Example App'),
        ),
        body: Center(
          child: ListView(
              padding: EdgeInsets.all(12.0),
              children: <Widget>[
                    Padding(padding: EdgeInsets.all(8.0)),
                    Text(
                      '$status',
                      style: TextStyle(fontSize: 16.0),
                      textAlign: TextAlign.center,
                    ),
                    isConnected
                        ? Text(
                            'Your peer ID: ${peer.peerId}',
                            style: TextStyle(fontSize: 16.0),
                            textAlign: TextAlign.center,
                          )
                        : null,
                    Padding(padding: EdgeInsets.all(8.0)),
                    isConnecting
                        ? Center(
                            child: SizedBox(
                              child: CircularProgressIndicator(),
                              width: 30.0,
                              height: 30.0,
                            ),
                          )
                        : !isConnected
                            ? FlatButton(
                                child: Text(
                                  'Connect',
                                  style: TextStyle(
                                      color: Colors.blue, fontSize: 16.0),
                                  textAlign: TextAlign.center,
                                ),
                                onPressed: _connect)
                            : FlatButton(
                                child: Text(
                                  'Disconnect',
                                  style: TextStyle(
                                      color: Colors.blue, fontSize: 16.0),
                                  textAlign: TextAlign.center,
                                ),
                                onPressed: _disconnect),
                    isConnected
                        ? FlatButton(
                            child: Text(
                              'Refresh',
                              style:
                                  TextStyle(color: Colors.blue, fontSize: 16.0),
                              textAlign: TextAlign.center,
                            ),
                            onPressed: _fetchAllPeers)
                        : null,
                    Padding(padding: EdgeInsets.all(8.0)),
                    isConnected && Platform.isIOS
                        ? Column(
                            children: <Widget>[
                              SizedBox(
                                child: UiKitView(
                                  viewType: 'flutter_skyway/video_view',
                                  onPlatformViewCreated: (id) {
                                    print('UiKitView created: id = $id');
                                  },
                                ),
                                width: 320.0,
                                height: 240.0,
                              ),
                            ],
                          )
                        : null,
                    Padding(padding: EdgeInsets.all(8.0)),
                  ].where((c) => c != null).toList() +
                  _buildPeers()),
        ),
      ),
    );
  }

  List<Widget> _buildPeers() {
    return peers != null
        ? peers.isNotEmpty
            ? peers.map((peerId) {
                return Center(
                  child: SizedBox(
                    width: 320.0,
                    child: Card(
                      color: Color.fromARGB(255, 240, 240, 240),
                      margin: EdgeInsets.all(12.0),
                      child: Container(
                        padding: EdgeInsets.fromLTRB(8.0, 20.0, 8.0, 0.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '$peerId',
                              style: TextStyle(fontSize: 16.0),
                            ),
                            FlatButton(
                              child: Text(
                                'Call',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  color: Colors.blue,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              onPressed: () {
                                _call(peerId);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList()
            : [
                Text(
                  'Other peer does not exist.',
                  textAlign: TextAlign.center,
                )
              ]
        : [];
  }

  Future<void> _connect() async {
    if (isConnecting) {
      return;
    }
    setState(() {
      this.isConnecting = true;
      this.status = 'Connecting...';
    });

    String status;
    SkywayPeer peer;

    try {
      status = 'Connected!';
      peer = await Skyway.connect(apiKey, domain);
      peer.onReceiveCall = _onReceiveCall;
    } on PlatformException catch (e) {
      print(e);
      status = 'Failed to connect.';
    }

    setState(() {
      this.isConnecting = false;
      this.status = status;
      this.peer = peer;
      _fetchAllPeers();
    });
  }

  Future<void> _disconnect() async {
    if (this.peer != null) {
      await this.peer.destroy();
    }
    setState(() {
      this.status = 'Disconnected.';
      this.peer = null;
      this.peers = null;
    });
  }

  Future<void> _fetchAllPeers() async {
    if (!isConnected) {
      return;
    }

    List<String> peers;
    try {
      peers = await peer.listAllPeers();
      peers = peers.where((peerId) => peerId != peer.peerId).toList();
    } on PlatformException catch (e) {
      print(e);
    }

    setState(() {
      this.peers = peers;
    });
  }

  void _call(String targetPeerId) {
    print("call to $targetPeerId");
    this.peer.call(targetPeerId);
  }

  void _onReceiveCall(String remotePeerId) {
    print('remotePeerId: $remotePeerId');
    showDialog(
      context: context,
      builder: (BuildContext context) => new AlertDialog(
            title: new Text('Received a call from $remotePeerId'),
            actions: <Widget>[
              new FlatButton(
                  child: const Text('Reject'),
                  onPressed: () {
                    Navigator.pop(context, 0);
                  }),
              new FlatButton(
                  child: const Text('Accept'),
                  onPressed: () {
                    Navigator.pop(context, 1);
                  })
            ],
          ),
    ).then<void>((value) {
      switch (value) {
        case 0:
          peer.reject(remotePeerId);
          break;
        case 1:
          peer.accept(remotePeerId);
          break;
        default:
      }
    });
  }
}
