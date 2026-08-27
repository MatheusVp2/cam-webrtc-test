/// Cliente WebSocket de sinalização (seção 4 da spec).
///
/// Esta classe só cuida do transporte: conectar, mandar JSON e entregar o JSON
/// que chega. Quem decide o que fazer com cada mensagem é a [CamSession].
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'log.dart';

typedef AoReceberMensagem = void Function(Map<String, dynamic> mensagem);
typedef AoFechar = void Function(Object? erro);

class SignalingClient {
  WebSocketChannel? _canal;
  StreamSubscription<dynamic>? _inscricao;

  bool get conectado => _canal != null;

  /// Abre a conexão com o PC. Lança exceção se não conseguir.
  Future<void> conectar(
    String host, {
    required AoReceberMensagem aoReceber,
    required AoFechar aoFechar,
  }) async {
    final uri = AppConfig.signalingUri(host);
    logar('[SIG] conectando em $uri');

    final canal = WebSocketChannel.connect(uri);
    // `ready` completa quando o handshake HTTP→WebSocket termina. Sem esse
    // await, um IP errado só estouraria depois, dentro do stream.
    await canal.ready;
    _canal = canal;
    logar('[SIG] conectado');

    _inscricao = canal.stream.listen(
      (bruto) {
        try {
          final decodificado = jsonDecode(bruto as String);
          if (decodificado is! Map<String, dynamic>) {
            logar('[SIG] mensagem não é um objeto JSON, ignorando: $bruto');
            return;
          }
          logar('[SIG] <- ${decodificado['type']}');
          aoReceber(decodificado);
        } on FormatException catch (erro) {
          logar('[SIG] JSON inválido, ignorando: $erro');
        }
      },
      onError: (Object erro) {
        logar('[SIG] erro no socket: $erro');
        aoFechar(erro);
      },
      onDone: () {
        logar('[SIG] socket fechado pelo PC');
        aoFechar(null);
      },
      cancelOnError: true,
    );
  }

  void enviar(Map<String, dynamic> mensagem) {
    final canal = _canal;
    if (canal == null) {
      logar('[SIG] tentou enviar ${mensagem['type']} sem conexão, ignorando');
      return;
    }
    logar('[SIG] -> ${mensagem['type']}');
    canal.sink.add(jsonEncode(mensagem));
  }

  void enviarHello(String nomeDoAparelho) => enviar({
    'type': 'hello',
    'device': nomeDoAparelho,
    'version': AppConfig.protocolVersion,
  });

  void enviarOffer(String sdp) => enviar({'type': 'offer', 'sdp': sdp});

  void enviarIce({
    required String candidate,
    required String? sdpMid,
    required int? sdpMLineIndex,
  }) => enviar({
    'type': 'ice',
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  });

  void enviarBye() => enviar({'type': 'bye'});

  Future<void> fechar() async {
    await _inscricao?.cancel();
    _inscricao = null;
    await _canal?.sink.close();
    _canal = null;
    logar('[SIG] conexão encerrada');
  }
}
