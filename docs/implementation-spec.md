# SPEC — App de Webcam via Celular (tipo Iriun)

> **Para o assistente:** este documento é a fonte da verdade do projeto. Leia inteiro antes de escrever código. Trabalhe **uma etapa por vez**, na ordem. Não implemente recursos de etapas futuras "por adiantamento". Ao terminar uma etapa, marque os checkboxes e pare para validação humana antes de seguir.

---

## 1. Objetivo

Transformar um celular (Android e iOS) em webcam sem fio para o PC. O vídeo do celular deve aparecer como uma câmera comum na lista de dispositivos do Google Meet, Zoom, OBS e Discord.

**Escopo:** rede local (LAN) apenas. Sem servidor na nuvem, sem contas, sem internet.

**Contexto do desenvolvedor:** iniciante em programação nativa (Kotlin/Swift/C++). Projeto pessoal de aprendizado. Priorize soluções que evitem código nativo; quando for inevitável, explique linha a linha.

**Não-objetivos (por enquanto):** driver de câmera virtual próprio, microfone virtual, funcionamento fora da LAN, publicação em loja.

---

## 2. Decisões técnicas já tomadas

Estas decisões estão fechadas. Não as reabra sem pedido explícito.

| Decisão | Escolha | Motivo |
|---|---|---|
| App móvel | Flutter (Dart) | Um código para Android + iOS |
| Pipeline de vídeo | `flutter_webrtc` | Traz encoder H.264 por hardware, controle de congestionamento e jitter buffer prontos. Sem isso seria preciso escrever platform channels para MediaCodec/VideoToolbox |
| Desktop | Python 3.11+ | Rapidez de iteração; `aiortc` + `pyvirtualcam` cobrem tudo |
| Câmera virtual | Câmera virtual do OBS (via `pyvirtualcam`) | Funciona nos 3 sistemas sem assinar driver. Driver próprio fica para muito depois |
| Sinalização | WebSocket + JSON, PC como servidor | Simples de depurar com logs |
| Descoberta | mDNS / Bonjour | Usuário não digita IP |
| STUN/TURN | **Nenhum** | Mesma LAN: os host candidates do ICE resolvem sozinhos |

---

## 3. Arquitetura

```
CELULAR (Flutter)                        PC (Python)
─────────────────                        ───────────
Câmera                                   Servidor WebSocket :8765
  ↓                                      Anúncio mDNS
Encoder H.264 (hardware)                   ↑
  ↓                                        │ 1. descobre e conecta
WebRTC PeerConnection  ──── SDP/ICE ───────┘
  ↓                                        
  └────────── vídeo H.264 (SRTP/UDP) ────→ aiortc
                                             ↓
                                           decodifica → frames RGB
                                             ↓
                                           pyvirtualcam
                                             ↓
                                           "OBS Virtual Camera"
                                             ↓
                                           Meet / Zoom / OBS
```

**Quem oferta:** o celular tem a mídia, então **o celular cria a offer** (transceiver `sendonly`) e o PC responde com a answer (`recvonly`).

---

## 4. Protocolo de sinalização

WebSocket em `ws://<ip-do-pc>:8765/ws`. Mensagens JSON, uma por frame de texto.

```jsonc
// celular → PC (primeira mensagem após conectar)
{ "type": "hello", "device": "Pixel 7", "version": "1" }

// PC → celular
{ "type": "welcome", "server": "camlink-desktop", "version": "1" }

// celular → PC
{ "type": "offer", "sdp": "v=0\r\n..." }

// PC → celular
{ "type": "answer", "sdp": "v=0\r\n..." }

// ambos os lados, quantas vezes for preciso
{ "type": "ice", "candidate": "candidate:...", "sdpMid": "0", "sdpMLineIndex": 0 }

// qualquer lado
{ "type": "bye" }
```

Se `version` não bater, o PC responde `{"type":"error","reason":"version_mismatch"}` e fecha.

**Serviço mDNS anunciado pelo PC:**
- tipo: `_camlink._tcp.local.`
- porta: `8765`
- TXT: `version=1`, `name=<hostname>`

---

## 5. Estrutura de pastas

```
camlink/
├── SPEC.md                  ← este arquivo
├── mobile/                  ← app Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── signaling.dart   ← WebSocket + protocolo JSON
│   │   ├── webrtc_sender.dart
│   │   ├── discovery.dart   ← mDNS (etapa 3)
│   │   └── ui/
│   └── pubspec.yaml
└── desktop/                 ← servidor Python
    ├── main.py
    ├── signaling.py
    ├── receiver.py          ← aiortc
    ├── output.py            ← janela OpenCV → depois pyvirtualcam
    ├── discovery.py         ← zeroconf (etapa 3)
    └── requirements.txt
```

---

## 6. Dependências

**mobile/pubspec.yaml**
```yaml
dependencies:
  flutter_webrtc:      # captura + encoder + transporte
  web_socket_channel:  # sinalização
  permission_handler:  # permissão de câmera
  multicast_dns:       # etapa 3
  shared_preferences:  # lembrar último PC (etapa 3)
```

**desktop/requirements.txt**
```
aiortc
websockets
opencv-python
numpy
pyvirtualcam    # etapa 2
zeroconf        # etapa 3
```

Use as versões estáveis mais recentes; não fixe versões antigas de memória.

---

## 7. Permissões de plataforma

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
```
`minSdkVersion` mínimo **23** (exigência do flutter_webrtc). Para tráfego em texto puro na LAN, habilite `usesCleartextTraffic` ou use um `network_security_config`.

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>Usar a câmera do celular como webcam do computador</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Encontrar seu computador na rede local</string>
<key>NSBonjourServices</key>
<array><string>_camlink._tcp</string></array>
```
Sem `NSBonjourServices` o mDNS falha silenciosamente no iOS 14+.

---

# 8. ROADMAP

## Etapa 1 — Ver a imagem no PC

**Meta:** o vídeo do celular aparece numa janela OpenCV no PC. IP digitado à mão. Nada de mDNS.

- [x] Criar projeto Flutter em `mobile/` e projeto Python em `desktop/`
- [x] Desktop: servidor WebSocket em `:8765` que loga toda mensagem recebida
- [x] Desktop: implementar o protocolo da seção 4 (hello/welcome/offer/answer/ice)
- [x] Desktop: `RTCPeerConnection` do aiortc recebendo track de vídeo
- [x] Desktop: loop que lê frames, converte para BGR e mostra em `cv2.imshow`
- [x] Mobile: tela com campo de texto para o IP do PC e botão "Conectar"
- [x] Mobile: pedir permissão de câmera antes de tudo
- [x] Mobile: `getUserMedia` com preview local na tela
- [x] Mobile: criar offer com transceiver de vídeo `sendonly`, trocar SDP e ICE
- [x] Mobile: indicador de estado da conexão na tela (desconectado / conectando / ao vivo)
- [ ] Testar com celular e PC no **mesmo Wi-Fi de 5GHz**

**Critério de aceite:** você se vê na janela do PC, sem travar, por 60 segundos seguidos.

> **Divergências desta implementação em relação à spec:**
> - Pastas: `trama_cam_mobile/` e `desk_edge_py/` no lugar de `mobile/` e `desktop/`.
> - Nome do protocolo: `tramacam` no lugar de `camlink` (serviço mDNS `_tramacam._tcp.local.`, servidor `tramacam-desktop`).
> - Python gerenciado com `uv` + `pyproject.toml` no lugar de `requirements.txt`.
> - O desktop **não envia** mensagens `ice`: o aiortc só devolve a answer depois de reunir todos os host candidates, então eles já vão dentro do SDP.
> - Arquivo extra no mobile: `lib/session.dart`, que orquestra permissão → câmera → WebSocket → WebRTC e deixa `main.dart` só com a tela.

---

## Etapa 2 — Virar webcam de verdade

**Meta:** o Google Meet lista a câmera e mostra a imagem do celular.

- [ ] Instalar o OBS Studio no PC (só para registrar a câmera virtual; não precisa abrir depois)
- [ ] Desktop: trocar `cv2.imshow` por `pyvirtualcam.Camera(width, height, fps)`
- [ ] Desktop: manter a janela OpenCV atrás de uma flag `--preview` para depuração
- [ ] Desktop: negociar resolução e fps a partir do primeiro frame recebido, não valores fixos
- [ ] Desktop: se nenhum frame chegar por 2 segundos, enviar frames pretos em vez de travar
- [ ] Testar em Google Meet, Zoom, OBS e Discord

**Critério de aceite:** entrar numa reunião do Meet, escolher "OBS Virtual Camera" e a outra pessoa te ver.

---

## Etapa 3 — Tirar o atrito

**Meta:** abrir o app e funcionar, sem digitar nada.

- [ ] Desktop: anunciar `_camlink._tcp.local.` na porta 8765 com `zeroconf`
- [ ] Mobile: buscar o serviço com `multicast_dns` e listar os PCs encontrados
- [ ] Mobile: conectar automaticamente se só houver um PC
- [ ] Mobile: salvar o último PC usado em `shared_preferences` e tentar primeiro nele
- [ ] Mobile: manter a entrada manual de IP como alternativa
- [ ] Mobile: reconectar sozinho quando a conexão cair (backoff: 1s, 2s, 4s, 8s, máx 8s)
- [ ] Mobile: botão de trocar câmera frontal/traseira sem derrubar a conexão
- [ ] Mobile: botão de lanterna
- [ ] Mobile: manter tela ligada e continuar transmitindo com a tela apagada
- [ ] Desktop: aceitar reconexão do mesmo celular sem precisar reiniciar

**Critério de aceite:** abrir o app, ele conectar sozinho em menos de 5 segundos, e sobreviver a você desligar e religar o Wi-Fi.

---

## Etapa 4 — Medir e melhorar

**Meta:** saber quanto tempo o frame demora e onde ele demora.

- [ ] Mobile: seletor de resolução (720p / 1080p) e fps (30 / 60)
- [ ] Mobile: fixar bitrate mínimo e máximo via `setParameters` no `RTCRtpSender`
- [ ] Mobile: passar constraints de resolução no `getUserMedia` para o WebRTC não degradar sozinho
- [ ] Mobile: mostrar bitrate real e fps na tela, lendo `getStats()`
- [ ] Desktop: medir e imprimir latência de decodificação e fps de saída
- [ ] Medir latência ponta a ponta: apontar o celular para um cronômetro na tela do PC e fotografar as duas
- [ ] Documentar os números medidos no final deste arquivo

**Meta de latência:** abaixo de 150ms. Referência: o Iriun fica entre 150 e 200ms.

---

## Etapa 5 — Diferenciais

**Meta:** fazer o que os concorrentes não fazem. Escolha um, não todos.

- [ ] Travar exposição, foco e balanço de branco (**exige platform channel** — Camera2 no Android, AVFoundation no iOS)
- [ ] Controle manual de ISO e velocidade do obturador
- [ ] Enquadramento automático seguindo a pessoa (MediaPipe ou ML Kit rodando no celular)
- [ ] Enviar áudio do microfone junto
- [ ] Modo USB via tethering USB (cria interface de rede; o código de LAN funciona sem mudança)
- [ ] Zoom por pinça
- [ ] Modo retrato / desfoque de fundo

---

## 9. Armadilhas conhecidas

**O WebRTC vai derrubar sua qualidade sozinho.** Ele foi feito para videochamada em rede ruim e reduz resolução quando suspeita de congestionamento. Combata com `setParameters` fixando bitrate e com constraints explícitas na captura. Não espere 1080p60 estável na primeira tentativa.

**Wi-Fi de 2.4GHz não aguenta.** Teste sempre em 5GHz. Se a imagem estiver travando, verifique isso antes de mexer no código.

**Isolamento de clientes no roteador.** Alguns roteadores (principalmente de operadora e redes de empresa) bloqueiam dispositivos de se enxergarem. Se o mDNS não achar nada e o IP manual também falhar, é isso. Teste no hotspot do celular para confirmar.

**iOS exige um Mac.** Compilar para iPhone precisa de Xcode. Sem Mac disponível, desenvolva Android-only — o código Dart fica praticamente todo reaproveitado.

**mDNS no iOS 14+** falha em silêncio sem `NSBonjourServices` e `NSLocalNetworkUsageDescription` no Info.plist.

**Firewall do Windows** vai perguntar sobre o Python na primeira execução. Autorize em redes privadas.

**A câmera virtual do OBS** só existe depois que o OBS Studio foi instalado e aberto ao menos uma vez.

---

## 10. Convenções

- Logs com prefixo de origem: `[SIG]` sinalização, `[RTC]` WebRTC, `[CAM]` saída de vídeo
- Todo erro de rede é tratado, nunca engolido em `except: pass`
- Comentários em português
- Nada de fixar IPs, resoluções ou fps em constantes espalhadas pelo código — centralize em um arquivo de config
- Ao concluir uma etapa, marque os checkboxes acima neste arquivo

---

## 11. Medições (preencher na etapa 4)

| Configuração | Latência | Bitrate | FPS real |
|---|---|---|---|
| 720p30 | | | |
| 1080p30 | | | |
| 1080p60 | | | |