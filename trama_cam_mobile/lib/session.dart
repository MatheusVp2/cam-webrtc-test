/// Orquestra a sessão inteira: permissão → câmera → WebSocket → WebRTC.
///
/// A tela só observa este objeto e desenha o estado; toda a lógica mora aqui.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config.dart';
import 'log.dart';
import 'signaling.dart';
import 'webrtc_sender.dart';

/// Estados possíveis, na ordem em que acontecem.
enum EstadoDaSessao {
  desconectado,
  pedindoPermissao,
  conectando,
  negociando,
  aoVivo,
  erro;

  String get rotulo => switch (this) {
    EstadoDaSessao.desconectado => 'Desconectado',
    EstadoDaSessao.pedindoPermissao => 'Pedindo permissão',
    EstadoDaSessao.conectando => 'Conectando',
    EstadoDaSessao.negociando => 'Negociando vídeo',
    EstadoDaSessao.aoVivo => 'Ao vivo',
    EstadoDaSessao.erro => 'Erro',
  };
}

class CamSession extends ChangeNotifier {
  final SignalingClient _sinalizacao = SignalingClient();
  final WebRtcSender _envio = WebRtcSender();

  /// Renderer do preview local. Precisa de `inicializar()` antes de usar.
  final RTCVideoRenderer previewLocal = RTCVideoRenderer();

  EstadoDaSessao _estado = EstadoDaSessao.desconectado;
  EstadoDaSessao get estado => _estado;

  String? _mensagemDeErro;
  String? get mensagemDeErro => _mensagemDeErro;

  bool get ocupado =>
      _estado != EstadoDaSessao.desconectado && _estado != EstadoDaSessao.erro;

  Future<void> inicializar() async {
    await previewLocal.initialize();
  }

  void _mudarEstado(EstadoDaSessao novo, {String? erro}) {
    _estado = novo;
    _mensagemDeErro = erro;
    notifyListeners();
  }

  /// Fluxo completo de conexão. Qualquer falha cai em [_falhar].
  Future<void> conectar(String host) async {
    if (ocupado) return;

    try {
      _mudarEstado(EstadoDaSessao.pedindoPermissao);
      if (!await _garantirPermissaoDeCamera()) {
        _falhar('Permissão de câmera negada. Libere nas configurações do app.');
        return;
      }

      // A câmera sobe antes do WebSocket para o preview já aparecer enquanto a
      // conexão é negociada.
      final stream = await _envio.ligarCamera();
      previewLocal.srcObject = stream;
      notifyListeners();

      _mudarEstado(EstadoDaSessao.conectando);
      await _sinalizacao.conectar(
        host,
        aoReceber: _tratarMensagem,
        aoFechar: _tratarFechamento,
      );

      _sinalizacao.enviarHello(_nomeDoAparelho());
    } on SocketException catch (erro) {
      _falhar('Não achei o PC em $host. Confira o IP e o Wi-Fi. (${erro.osError?.message ?? erro.message})');
    } catch (erro) {
      _falhar('Falha ao conectar: $erro');
    }
  }

  Future<void> desconectar({String? erro}) async {
    if (_sinalizacao.conectado) {
      _sinalizacao.enviarBye();
    }
    await _sinalizacao.fechar();
    await _envio.descartar();
    previewLocal.srcObject = null;

    if (erro != null) {
      _mudarEstado(EstadoDaSessao.erro, erro: erro);
    } else {
      _mudarEstado(EstadoDaSessao.desconectado);
    }
  }

  Future<void> _tratarMensagem(Map<String, dynamic> mensagem) async {
    switch (mensagem['type']) {
      case 'welcome':
        logar('[SIG] PC respondeu: ${mensagem['server']}');
        await _negociar();

      case 'answer':
        _mudarEstado(EstadoDaSessao.negociando);
        await _envio.aplicarAnswer(mensagem['sdp'] as String);

      case 'ice':
        await _envio.adicionarIce(mensagem);

      case 'error':
        _falhar('O PC recusou: ${mensagem['reason']}');
        await desconectar(erro: 'O PC recusou: ${mensagem['reason']}');

      case 'bye':
        await desconectar();

      default:
        logar('[SIG] tipo desconhecido: ${mensagem['type']}');
    }
  }

  Future<void> _negociar() async {
    _mudarEstado(EstadoDaSessao.negociando);
    final sdp = await _envio.criarOffer(
      aoGerarCandidate: (candidate) => _sinalizacao.enviarIce(
        candidate: candidate.candidate!,
        sdpMid: candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex,
      ),
      aoMudarEstado: _tratarEstadoDaConexao,
    );
    _sinalizacao.enviarOffer(sdp);
  }

  void _tratarEstadoDaConexao(RTCPeerConnectionState estado) {
    switch (estado) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _mudarEstado(EstadoDaSessao.aoVivo);
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        // Não desconecta sozinho: na etapa 3 isso vira gatilho de reconexão.
        _mudarEstado(
          EstadoDaSessao.erro,
          erro: 'A conexão de vídeo falhou. Confira se os dois estão no mesmo Wi-Fi.',
        );
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        if (_estado == EstadoDaSessao.aoVivo) {
          _mudarEstado(EstadoDaSessao.conectando);
        }
      default:
        break;
    }
  }

  void _tratarFechamento(Object? erro) {
    if (_estado == EstadoDaSessao.desconectado) return;
    desconectar(
      erro: erro == null ? null : 'A conexão com o PC caiu: $erro',
    );
  }

  void _falhar(String mensagem) {
    logar('[SIG] $mensagem');
    _mudarEstado(EstadoDaSessao.erro, erro: mensagem);
  }

  Future<bool> _garantirPermissaoDeCamera() async {
    final status = await Permission.camera.request();
    logar('[CAM] permissão de câmera: $status');
    return status.isGranted || status.isLimited;
  }

  String _nomeDoAparelho() {
    // Nome simples, só para aparecer no log do PC. Nada de dependência extra
    // só para descobrir o modelo do aparelho.
    return '${AppConfig.clientName} ${Platform.operatingSystem}';
  }

  @override
  void dispose() {
    _sinalizacao.fechar();
    _envio.descartar();
    previewLocal.dispose();
    super.dispose();
  }
}
