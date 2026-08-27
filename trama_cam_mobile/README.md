# trama_cam_mobile

App Flutter do **trama-cam**: captura a câmera do celular e envia por WebRTC
para o PC.

Etapa 1 do roadmap (`docs/implementation-spec.md`): IP digitado à mão, preview
local na tela, indicador de estado. Sem mDNS ainda.

## Rodar

Com o celular ligado por USB (depuração USB ativa) e o `desk_edge_py` rodando
no PC:

```bash
flutter run
```

Digite no app o IP que o terminal do PC imprimiu e toque em **Conectar**.

## Arquivos

| Arquivo | Papel |
|---|---|
| `lib/config.dart` | Porta, versão do protocolo, resolução e fps pedidos à câmera. |
| `lib/log.dart` | `logar()` com prefixo de origem (`[SIG]`, `[RTC]`, `[CAM]`). |
| `lib/signaling.dart` | Cliente WebSocket e o protocolo JSON. Só transporte. |
| `lib/webrtc_sender.dart` | Câmera, `RTCPeerConnection`, offer `sendonly`. |
| `lib/session.dart` | Junta tudo: permissão → câmera → WebSocket → WebRTC. Guarda o estado. |
| `lib/main.dart` | A tela. |

## Notas de build (Android)

- `minSdk 23` no Gradle, mas o APK sai com **24**: o merge de manifests pega
  o maior valor entre o app e as bibliotecas, e o embedding do Flutter pede 24.
  Na prática o app roda em Android 7.0 ou mais novo.
- `compileSdk`/`targetSdk` fixados em **36**: o Flutter aponta para o
  `android-37` de preview, que o SDK local instala como `android-37.0` e o
  Gradle não encontra.
- `permission_handler` preso em **12.x**: a 13.x exige `compileSdk 37`.
- `usesCleartextTraffic="true"` no manifest — a sinalização é `ws://` na LAN,
  sem TLS, e o Android 9+ bloquearia por padrão.
