import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'api_service.dart';
import 'debug_logger.dart';
import '../di/service_locator.dart';

/// Manages the WebRTC peer connection that carries live two-way audio between the
/// elder (this device) and the caller (via the edge device).
///
/// Edge is the offerer: after the user answers, it produces an SDP offer that the
/// fraud service stores. We poll for that offer, answer it, and post the answer back
/// through the fraud service, which relays it to edge. Media then flows P2P.
class WebRtcCallService {
  WebRtcCallService._();
  static final WebRtcCallService I = WebRtcCallService._();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  bool _connecting = false;
  // Set by close() to abort an in-flight connect() (e.g. hangup during the
  // offer-poll window, before _pc/_localStream exist).
  bool _cancelled = false;

  bool get isActive => _pc != null;

  // Public STUN only for now (matches edge ICE_SERVERS). No TURN.
  static const Map<String, dynamic> _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  /// Fetch edge's offer (poll with short retry), answer it, and connect.
  Future<void> connect() async {
    if (_connecting || _pc != null) return;
    _connecting = true;
    _cancelled = false;
    try {
      final api = sl<ApiService>();

      // 1. Edge produces the offer asynchronously after `direct_call`; poll for it.
      String? offerSdp;
      for (var attempt = 0; attempt < 20; attempt++) {
        if (_cancelled) return;
        offerSdp = await api.getWebrtcOffer();
        if (offerSdp != null && offerSdp.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (_cancelled) return;
      if (offerSdp == null || offerSdp.isEmpty) {
        DebugLogger.I.log('[WebRTC] No offer after retries; aborting handoff');
        return;
      }

      // 2. Capture the elder's microphone. Assign instance fields as soon as each
      // resource exists so a concurrent close() (hangup mid-setup) can tear it down.
      _localStream = await navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': false});
      if (_cancelled) return await close();

      // 3. Build the peer connection and attach the mic track.
      _pc = await createPeerConnection(_config);
      if (_cancelled) return await close();
      final pc = _pc!;
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
      pc.onTrack = (event) {
        // Remote (caller) audio is rendered automatically by the audio engine.
        DebugLogger.I.log('[WebRTC] Remote track received: ${event.track.kind}');
      };
      pc.onConnectionState = (state) {
        DebugLogger.I.log('[WebRTC] Connection state: $state');
      };

      // 4. Answer the offer, wait for ICE gathering (non-trickle), post the answer.
      await pc.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));
      if (_cancelled) return await close();
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      final gathered = await _gatheredLocalDescription(pc);
      if (_cancelled) return await close();

      // Route the caller's audio out the loudspeaker.
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {}

      await api.postWebrtcAnswer(gathered?.sdp ?? answer.sdp ?? '');
      DebugLogger.I.log('[WebRTC] Answer posted; connection establishing');
    } catch (e) {
      DebugLogger.I.log('[WebRTC] connect failed: $e');
      await close();
    } finally {
      _connecting = false;
    }
  }

  /// Wait until ICE gathering completes so the answer SDP carries all candidates.
  Future<RTCSessionDescription?> _gatheredLocalDescription(
      RTCPeerConnection pc) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return pc.getLocalDescription();
    }
    final completer = Completer<void>();
    pc.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };
    // Cap the wait so a stalled gather doesn't block the handoff.
    final timeout = Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;
    timeout.cancel();
    return pc.getLocalDescription();
  }

  /// Enable/disable the local mic track (mute).
  void setMuted(bool muted) {
    for (final t in _localStream?.getAudioTracks() ?? const []) {
      t.enabled = !muted;
    }
  }

  Future<void> setSpeaker(bool on) async {
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (_) {}
  }

  /// Tear down the peer connection and release the microphone. Always flags
  /// cancellation so an in-flight connect() aborts even if nothing exists yet.
  Future<void> close() async {
    _cancelled = true;
    if (_pc == null && _localStream == null) return;
    try {
      for (final t in _localStream?.getTracks() ?? const []) {
        await t.stop();
      }
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    DebugLogger.I.log('[WebRTC] Peer connection closed');
  }
}
