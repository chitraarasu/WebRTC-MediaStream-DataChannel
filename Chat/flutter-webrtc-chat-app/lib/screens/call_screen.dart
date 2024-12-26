import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signalling.service.dart';

class ChatScreen extends StatefulWidget {
  final String callerId, calleeId;
  final dynamic offer;

  const ChatScreen({
    super.key,
    this.offer,
    required this.callerId,
    required this.calleeId,
  });

  @override
  State<ChatScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<ChatScreen> {
  final socket = SignallingService.instance.socket;
  RTCPeerConnection? _rtcPeerConnection;
  RTCDataChannel? _dataChannel;
  List<RTCIceCandidate> rtcIceCadidates = [];
  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;

  final _messageController = TextEditingController();
  final List<String> _messages = [];

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    _setupPeerConnection();
  }

  Future<void> _setupPeerConnection() async {
    _rtcPeerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302'
          ]
        }
      ]
    });

    /// Create data channel or any webrtc related things before doing connection.
    await _createDataChannel();

    if (widget.offer != null) {
      // listen for Remote IceCandidate
      socket!.on("IceCandidate", (data) {
        String candidate = data["iceCandidate"]["candidate"];
        String sdpMid = data["iceCandidate"]["id"];
        int sdpMLineIndex = data["iceCandidate"]["label"];

        // add iceCandidate
        _rtcPeerConnection!.addCandidate(RTCIceCandidate(
          candidate,
          sdpMid,
          sdpMLineIndex,
        ));
      });

      // set SDP offer as remoteDescription for peerConnection
      await _rtcPeerConnection!.setRemoteDescription(
        RTCSessionDescription(widget.offer["sdp"], widget.offer["type"]),
      );
      RTCSessionDescription answer = await _rtcPeerConnection!.createAnswer();
      _rtcPeerConnection!.setLocalDescription(answer);


      // send SDP answer to remote peer over signalling
      socket!.emit("answerCall", {
        "callerId": widget.callerId,
        "sdpAnswer": answer.toMap(),
      });
    } else {
      _rtcPeerConnection!.onIceCandidate =
          (RTCIceCandidate candidate) => rtcIceCadidates.add(candidate);

      socket!.on("callAnswered", (data) async {
        // set SDP answer as remoteDescription for peerConnection
        await _rtcPeerConnection!.setRemoteDescription(
          RTCSessionDescription(
            data["sdpAnswer"]["sdp"],
            data["sdpAnswer"]["type"],
          ),
        );

        // send iceCandidate generated to remote peer over signalling
        for (RTCIceCandidate candidate in rtcIceCadidates) {
          socket!.emit("IceCandidate", {
            "calleeId": widget.calleeId,
            "iceCandidate": {
              "id": candidate.sdpMid,
              "label": candidate.sdpMLineIndex,
              "candidate": candidate.candidate
            }
          });
        }
      });


      // create SDP Offer
      RTCSessionDescription offer = await _rtcPeerConnection!.createOffer();

      // set SDP offer as localDescription for peerConnection
      await _rtcPeerConnection!.setLocalDescription(offer);


      // make a call to remote peer over signalling
      socket!.emit('makeCall', {
        "calleeId": widget.calleeId,
        "sdpOffer": offer.toMap(),
      });
    }
  }



  @override
  void dispose() {
    _rtcPeerConnection?.dispose();
    super.dispose();
  }

  _createDataChannel() async {
    if (widget.offer == null) {
      // Caller creates the data channel
      RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
        ..maxRetransmits = 30;
      _dataChannel = await _rtcPeerConnection!.createDataChannel("chat", dataChannelDict);

      print(_dataChannel);

      _addDataChannel(_dataChannel!);

      print("Data channel created by caller.");
    }

    // Listener for incoming data channels
    _rtcPeerConnection!.onDataChannel = (RTCDataChannel channel) {
      print("Data channel received.");
      _dataChannel = channel;

      _addDataChannel(channel);
    };
  }


  void _addDataChannel(RTCDataChannel channel) {
    channel.onDataChannelState = (e) {
      print("Channel Data $e");
    };
    channel.onMessage = (RTCDataChannelMessage message) {
      print("Received message: ${message.text}");
      setState(() {
        _messages.add("Remote: ${message.text}");
      });
    };
  }



  void _sendMessage(String message) {
    if (_dataChannel != null) {
      _dataChannel!.send(RTCDataChannelMessage(message));
      setState(() {
        _messages.add("You: $message");
      });
    } else {
      print("Data channel is not ready.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("P2P Chat")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(_messages[index]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(labelText: "Type a message"),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    if (_messageController.text.isNotEmpty) {
                      _sendMessage(_messageController.text);
                      _messageController.clear();
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    _createDataChannel();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
