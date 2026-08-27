/// Configuração central do app.
///
/// Nada de IP, porta, resolução ou fps espalhado pelo código — tudo mora aqui.
library;

class AppConfig {
  const AppConfig._();

  // --- Protocolo de sinalização --------------------------------------------
  /// Versão trocada no handshake hello/welcome. Precisa bater com o desktop.
  static const String protocolVersion = '1';

  /// Nome que o app manda no hello, só para aparecer no log do PC.
  static const String clientName = 'trama-cam';

  // --- Servidor -------------------------------------------------------------
  static const int signalingPort = 8765;
  static const String signalingPath = '/ws';

  /// Monta a URL do WebSocket a partir do IP digitado pelo usuário.
  static Uri signalingUri(String host) =>
      Uri.parse('ws://$host:$signalingPort$signalingPath');

  // --- mDNS (etapa 3, ainda não usado) --------------------------------------
  static const String mdnsServiceType = '_tramacam._tcp';

  // --- Captura de vídeo ------------------------------------------------------
  /// Resolução e fps pedidos à câmera. São "ideal", não obrigatórios: se o
  /// aparelho não suportar, ele escolhe o mais próximo em vez de falhar.
  static const int larguraIdeal = 1280;
  static const int alturaIdeal = 720;
  static const int fpsIdeal = 30;

  /// 'user' = câmera frontal, 'environment' = traseira.
  static const String cameraPadrao = 'user';

  static Map<String, dynamic> get restricoesDeMidia => {
    'audio': false,
    'video': {
      'facingMode': cameraPadrao,
      'width': {'ideal': larguraIdeal},
      'height': {'ideal': alturaIdeal},
      'frameRate': {'ideal': fpsIdeal},
    },
  };

  /// Sem STUN/TURN: celular e PC estão na mesma LAN, então os host candidates
  /// do ICE já se acham sozinhos.
  static const Map<String, dynamic> configuracaoWebRtc = {
    'iceServers': <Map<String, dynamic>>[],
  };
}
