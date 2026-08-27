/// Log simples com prefixo de origem (convenção da spec):
/// `[SIG]` sinalização, `[RTC]` WebRTC, `[CAM]` câmera/saída de vídeo.
///
/// Usa `debugPrint` em vez de `print` porque ele não corta linhas longas no
/// meio quando o Android joga fora parte do buffer de log.
library;

import 'package:flutter/foundation.dart';

void logar(String mensagem) => debugPrint(mensagem);
