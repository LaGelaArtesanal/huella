import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CallService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isVideoCall = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Control de descripción remota y candidatos pendientes
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  StreamSubscription<DocumentSnapshot>? _answerSubscription;
  StreamSubscription<QuerySnapshot>? _candidatesSubscription;

  MediaStream? get localStream => _localStream;
  Function(MediaStream?)? onRemoteStreamReceived;

  Future<void> initialize({bool isVideoCall = true}) async {
    _isVideoCall = isVideoCall;
    print('⚙️ [WEBRTC] Inicializando con isVideoCall: $isVideoCall');

    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideoCall
          ? {
        'mandatory': {'minWidth': '640', 'minHeight': '480', 'minFrameRate': '30'},
        'facingMode': 'user',
      }
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      print('✅ [WEBRTC] Stream local obtenido exitosamente');
    } catch (e) {
      print('❌ [WEBRTC] Error al obtener cámara/micrófono: $e');
      rethrow;
    }

    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        // ⚠️ TURN gratuito de prueba (OpenRelay). En redes móviles con NAT
        // simétrico el STUN no basta. Para producción, usa tu propio servidor
        // TURN (ej. coturn) o un servicio como Metered/Twilio/Xirsys.
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      print('📥 [WEBRTC] Track remoto recibido!');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStreamReceived?.call(_remoteStream);
      }
    };

    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('🧊 [WEBRTC] Estado ICE: $state');
    };
  }

  // ============================================================
  // ✅ INTERCAMBIO DE CANDIDATOS ICE (esto es lo que faltaba)
  // ============================================================

  /// Sube los candidatos locales a Firestore conforme se descubren.
  void _setupLocalIceCandidateUpload(String callId, String collectionName) {
    final candidatesCol = _firestore
        .collection('calls')
        .doc(callId)
        .collection(collectionName);

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      candidatesCol.add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'timestamp': FieldValue.serverTimestamp(),
      });
    };
  }

  /// Escucha los candidatos del otro participante y los agrega.
  void _listenToRemoteCandidates(String callId, String collectionName) {
    _candidatesSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .collection(collectionName)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          if (_remoteDescriptionSet) {
            _peerConnection?.addCandidate(candidate);
          } else {
            // Guardar hasta que la descripción remota esté lista
            _pendingRemoteCandidates.add(candidate);
          }
        }
      }
    });
  }

  Future<void> _setRemoteDescriptionSafely(RTCSessionDescription desc) async {
    if (_remoteDescriptionSet) return;
    await _peerConnection!.setRemoteDescription(desc);
    _remoteDescriptionSet = true;

    // Vaciar candidatos que llegaron antes de la descripción remota
    for (var c in _pendingRemoteCandidates) {
      await _peerConnection?.addCandidate(c);
    }
    _pendingRemoteCandidates.clear();
  }

  // ============================================================
  // LLAMANTE
  // ============================================================

  Future<void> createOffer(String callId, String currentUserId) async {
    print('📤 [CALLER] Creando oferta para: $callId');

    // ✅ Subir mis candidatos y escuchar los del receptor
    _setupLocalIceCandidateUpload(callId, 'callerCandidates');
    _listenToRemoteCandidates(callId, 'calleeCandidates');

    final RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await _firestore.collection('calls').doc(callId).set({
      'offer': offer.toMap(),
      'status': 'offering',
    }, SetOptions(merge: true));

    print('👂 [CALLER] Escuchando respuesta en Firestore...');
    _answerSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        if (data['status'] == 'connected' && data['answer'] != null && !_remoteDescriptionSet) {
          print('✅ [CALLER] ¡Respuesta recibida! Conectando stream remoto...');
          final answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
          _setRemoteDescriptionSafely(answer);
        }
      }
    });
  }

  // ============================================================
  // RECEPTOR
  // ============================================================

  Future<void> answerCall(String callId, String currentUserId) async {
    print('📥 [RECEIVER] answerCall iniciado para: $callId');

    final doc = await _firestore.collection('calls').doc(callId).get();
    if (!doc.exists) {
      print('❌ [RECEIVER] El documento de la llamada NO existe en Firestore.');
      return;
    }

    final data = doc.data()!;
    if (data['offer'] == null) {
      print('❌ [RECEIVER] No hay oferta (offer) en el documento.');
      return;
    }

    // ✅ Subir mis candidatos y escuchar los del llamante
    _setupLocalIceCandidateUpload(callId, 'calleeCandidates');
    _listenToRemoteCandidates(callId, 'callerCandidates');

    print('📥 [RECEIVER] Estableciendo descripción remota (offer)...');
    final offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
    await _setRemoteDescriptionSafely(offer);

    print('📥 [RECEIVER] Creando respuesta (answer)...');
    final RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    print('📤 [RECEIVER] Guardando respuesta en Firestore...');
    await _firestore.collection('calls').doc(callId).set({
      'answer': answer.toMap(),
      'status': 'connected',
    }, SetOptions(merge: true));

    print('✅ [RECEIVER] Respuesta guardada exitosamente. Esperando conexión WebRTC...');
  }

  // ============================================================
  // CONTROLES Y LIMPIEZA
  // ============================================================

  void toggleVideo(bool enabled) {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) videoTrack.enabled = enabled;
  }

  void toggleAudio(bool enabled) {
    final audioTrack = _localStream?.getAudioTracks().firstOrNull;
    if (audioTrack != null) audioTrack.enabled = enabled;
  }

  /// Borra los candidatos ICE de ambas subcolecciones (mejor esfuerzo).
  Future<void> _cleanupCandidates(String callId) async {
    try {
      for (final col in ['callerCandidates', 'calleeCandidates']) {
        final snapshot = await _firestore
            .collection('calls')
            .doc(callId)
            .collection(col)
            .get();
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      print('⚠️ No se pudieron limpiar los candidatos ICE: $e');
    }
  }

  Future<void> hangUp(String callId) async {
    await _answerSubscription?.cancel();
    await _candidatesSubscription?.cancel();
    _answerSubscription = null;
    _candidatesSubscription = null;

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _remoteStream?.dispose();
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _peerConnection = null;

    await _firestore.collection('calls').doc(callId).set({
      'status': 'ended',
    }, SetOptions(merge: true));

    await _cleanupCandidates(callId);
  }

  void dispose() {
    _answerSubscription?.cancel();
    _candidatesSubscription?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;
  }
}
