# desk_edge_py

Ponta desktop do **trama-cam**. Recebe o vídeo do celular por WebRTC e mostra
numa janela do OpenCV.

Etapa 1 do roadmap (`docs/implementation-spec.md`): sem mDNS e sem câmera
virtual ainda — o IP é digitado à mão no celular.

## Rodar

```bash
uv run main.py
```

O terminal imprime o IP a digitar no app:

```
[SIG] no celular, digite: 192.168.100.213   (ws://192.168.100.213:8765/ws)
[SIG] escutando em ws://0.0.0.0:8765/ws
```

Ctrl+C encerra.

## Arquivos

| Arquivo | Papel |
|---|---|
| `config.py` | Porta, versão do protocolo, nomes. Nada de constante espalhada. |
| `signaling.py` | Servidor WebSocket e o protocolo JSON (hello/welcome/offer/answer/ice/bye). |
| `receiver.py` | `RTCPeerConnection` do aiortc: aplica a offer, devolve a answer, lê os frames. |
| `output.py` | Saída de vídeo. Hoje `cv2.imshow`; na etapa 2 vira `pyvirtualcam`. |
| `main.py` | Descobre o IP local e sobe o servidor. |

## Logs

Prefixo indica a origem: `[SIG]` sinalização, `[RTC]` WebRTC, `[CAM]` vídeo.

## Se não conectar

1. Celular e PC no **mesmo Wi-Fi**, de preferência 5GHz.
2. Firewall liberando a porta 8765 em redes privadas.
3. Roteador com isolamento de clientes bloqueia os dois de se enxergarem —
   teste no hotspot do celular para confirmar.
