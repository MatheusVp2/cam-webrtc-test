"""Servidor WebSocket de sinalização (seção 4 da spec).

Uma mensagem JSON por frame de texto. O desktop é o servidor; o celular
conecta em ws://<ip-do-pc>:8765/ws.
"""

import json

import websockets
from websockets.asyncio.server import ServerConnection, serve

from config import PROTOCOL_VERSION, SERVER_NAME, WS_HOST, WS_PATH, WS_PORT
from output import PreviewWindow
from receiver import VideoReceiver


async def _enviar(ws: ServerConnection, mensagem: dict) -> None:
    print(f"[SIG] -> {mensagem.get('type')}")
    await ws.send(json.dumps(mensagem))


async def _tratar_conexao(ws: ServerConnection) -> None:
    """Ciclo de vida de um celular conectado."""
    caminho = ws.request.path
    origem = ws.remote_address[0] if ws.remote_address else "?"
    print(f"[SIG] conexão de {origem} em {caminho}")

    if caminho != WS_PATH:
        print(f"[SIG] caminho inesperado {caminho}, recusando")
        await ws.close(code=1008, reason="path desconhecido")
        return

    receiver: VideoReceiver | None = None

    try:
        async for bruto in ws:
            try:
                mensagem = json.loads(bruto)
            except json.JSONDecodeError:
                print(f"[SIG] mensagem não-JSON ignorada: {bruto!r:.120}")
                continue

            tipo = mensagem.get("type")
            print(f"[SIG] <- {tipo}")

            if tipo == "hello":
                if str(mensagem.get("version")) != PROTOCOL_VERSION:
                    print(
                        f"[SIG] versão incompatível: celular={mensagem.get('version')} "
                        f"desktop={PROTOCOL_VERSION}"
                    )
                    await _enviar(ws, {"type": "error", "reason": "version_mismatch"})
                    await ws.close(code=1002, reason="version_mismatch")
                    return

                print(f"[SIG] celular identificado: {mensagem.get('device')}")
                await _enviar(
                    ws,
                    {
                        "type": "welcome",
                        "server": SERVER_NAME,
                        "version": PROTOCOL_VERSION,
                    },
                )

            elif tipo == "offer":
                if receiver is not None:
                    # Renegociação não é suportada na etapa 1: derruba a antiga.
                    print("[SIG] offer nova chegou, descartando sessão anterior")
                    await receiver.fechar()

                receiver = VideoReceiver(PreviewWindow())
                sdp_answer = await receiver.tratar_offer(mensagem["sdp"])
                await _enviar(ws, {"type": "answer", "sdp": sdp_answer})

            elif tipo == "ice":
                if receiver is None:
                    print("[SIG] ice antes da offer, ignorando")
                    continue
                await receiver.adicionar_ice(mensagem)

            elif tipo == "bye":
                print("[SIG] celular pediu para encerrar")
                break

            else:
                print(f"[SIG] tipo desconhecido: {tipo!r}")

    except websockets.ConnectionClosed as erro:
        print(f"[SIG] conexão fechada: código={erro.code} motivo={erro.reason!r}")
    except Exception as erro:
        print(f"[SIG] erro inesperado na conexão: {erro!r}")
    finally:
        if receiver is not None:
            await receiver.fechar()
        print(f"[SIG] {origem} desconectado")


async def rodar_servidor() -> None:
    """Sobe o servidor e fica no ar até Ctrl+C."""
    async with serve(_tratar_conexao, WS_HOST, WS_PORT) as servidor:
        print(f"[SIG] escutando em ws://{WS_HOST}:{WS_PORT}{WS_PATH}")
        await servidor.serve_forever()
