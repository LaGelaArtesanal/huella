import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  Function(MediaStream)? onRemoteStreamReceived;
  Function(RTCIceCandidate)? onIceCandidateReceived;

  Future<void> initialize() async {
    localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    peerConnection = await createPeerConnection(_iceServers);

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    peerConnection?.onIceCandidate = (candidate) {
      if (candidate != null) onIceCandidateReceived?.call(candidate);
    };

    peerConnection?.onAddStream = (stream) {
      remoteStream = stream;
      onRemoteStreamReceived?.call(stream);
    };
  }

  Future<void> createOffer(String callId, String callerId) async {
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    await _firestore.collection('calls').doc(callId).set({
      'callerId': callerId,
      'offer': offer.toMap(),
      'status': 'offering',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> answerCall(String callId, String calleeId) async {
    final doc = await _firestore.collection('calls').doc(callId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    RTCSessionDescription offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
    await peerConnection!.setRemoteDescription(offer);

    RTCSessionDescription answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    await _firestore.collection('calls').doc(callId).update({
      'calleeId': calleeId,
      'answer': answer.toMap(),
      'status': 'connected',
    });
  }

  Future<void> acceptOffer(String callId) async {
    final doc = await _firestore.collection('calls').doc(callId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    if (data['answer'] != null) {
      RTCSessionDescription answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
      await peerConnection!.setRemoteDescription(answer);
    }
  }

  Future<void> hangUp(String callId) async {
    await peerConnection?.close();
    await _firestore.collection('calls').doc(callId).delete();
    localStream?.dispose();
    remoteStream?.dispose();
  }

  void dispose() {
    peerConnection?.close();
    localStream?.dispose();
    remoteStream?.dispose();
  }
}