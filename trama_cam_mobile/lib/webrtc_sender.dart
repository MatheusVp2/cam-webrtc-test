/// Ponta WebRTC do celular: captura a câmera e envia o vídeo para o PC.
///
/// O celular é quem tem a mídia, então é ele quem cria a offer, com um
/// transceiver de vídeo `sendonly`. O PC só responde a answer.
library;

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'config.dart';
import 'log.dart';

typedef AoGerarCandidate = void Function(RTCIceCandidate candidate);
typedef AoMudarEstado = void Function(RTCPeerConnectionState estado);

class WebRtcSender {
  RTCPeerConnection? _pc;
  MediaStream? _streamLocal;

  /// Stream da câmera, para mostrar no preview da tela.
  MediaStream? get streamLocal => _streamLocal;

  /// Liga a câmera. Precisa da permissão já concedida.
  Future<MediaStream> ligarCamera() async {
    logar('[RTC] pedindo a câmera ao sistema');
    final stream = await navigator.mediaDevices.getUserMedia(
      AppConfig.restricoesDeMidia,
    );
    _streamLocal = stream;

    final trilha = stream.getVideoTracks().first;
    logar('[RTC] câmera ligada: ${trilha.label}');
    return stream;
  }

  /// Cria a PeerConnection, anexa o vídeo e devolve o SDP da offer.
  Future<String> criarOffer({
    required AoGerarCandidate aoGerarCandidate,
    required AoMudarEstado aoMudarEstado,
  }) async {
    final stream = _streamLocal;
    if (stream == null) {
      throw StateError('criarOffer chamado antes de ligarCamera');
    }

    final pc = await createPeerConnection(AppConfig.configuracaoWebRtc);
    _pc = pc;

    pc.onIceCandidate = (candidate) {
      // Um candidate vazio significa "acabaram os meus endereços"; o PC não
      // precisa dele porque a answer dele já vem completa.
      if (candidate.candidate == null || candidate.candidate!.isEmpty) {
        logar('[RTC] fim dos candidates locais');
        return;
      }
      aoGerarCandidate(candidate);
    };

    pc.onConnectionState = (estado) {
      logar('[RTC] estado da conexão: $estado');
      aoMudarEstado(estado);
    };

    pc.onIceConnectionState = (estado) {
      logar('[RTC] estado do ICE: $estado');
    };

    // sendonly: só mandamos vídeo, nunca recebemos. Isso evita que o WebRTC
    // negocie uma trilha de volta que ninguém usaria.
    await pc.addTransceiver(
      track: stream.getVideoTracks().first,
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(
        direction: TransceiverDirection.SendOnly,
        streams: [stream],
      ),
    );

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    logar('[RTC] offer criada');

    // Lê de volta do peer connection: o SDP local pode ter sido ajustado.
    final local = await pc.getLocalDescription();
    return local!.sdp!;
  }

  /// Aplica a answer que veio do PC. A partir daqui o ICE começa a valer.
  Future<void> aplicarAnswer(String sdp) async {
    final pc = _pc;
    if (pc == null) {
      logar('[RTC] answer chegou sem peer connection, ignorando');
      return;
    }
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    logar('[RTC] answer aplicada');
  }

  /// Adiciona um candidate ICE mandado pelo PC (hoje o PC não manda nenhum,
  /// porque a answer dele já sai com todos dentro).
  Future<void> adicionarIce(Map<String, dynamic> mensagem) async {
    final pc = _pc;
    if (pc == null) return;
    await pc.addCandidate(
      RTCIceCandidate(
        mensagem['candidate'] as String?,
        mensagem['sdpMid'] as String?,
        mensagem['sdpMLineIndex'] as int?,
      ),
    );
    logar('[RTC] candidate do PC adicionado');
  }

  /// Derruba a conexão mas **mantém a câmera ligada**, para o preview local
  /// continuar aparecendo e uma reconexão não precisar reabrir a câmera.
  Future<void> pararEnvio() async {
    await _pc?.close();
    _pc = null;
    logar('[RTC] peer connection fechada');
  }

  /// Desliga tudo, inclusive a câmera.
  Future<void> descartar() async {
    await pararEnvio();
    final stream = _streamLocal;
    if (stream != null) {
      for (final trilha in stream.getTracks()) {
        await trilha.stop();
      }
      await stream.dispose();
      _streamLocal = null;
      logar('[RTC] câmera desligada');
    }
  }
}
