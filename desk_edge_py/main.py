"""Ponto de entrada do desk edge do trama-cam.

Etapa 1: sobe o servidor de sinalização, recebe o vídeo do celular por WebRTC
e mostra numa janela do OpenCV. Sem mDNS e sem câmera virtual ainda.

Uso:  uv run main.py
"""

import asyncio
import socket

from config import WS_PATH, WS_PORT
from signaling import rodar_servidor


def _ips_locais() -> list[str]:
    """Descobre os IPs desta máquina na LAN, para o usuário digitar no celular.

    O truque do socket UDP não envia pacote nenhum: só pergunta ao sistema
    operacional qual interface seria usada para falar com a internet, o que na
    prática entrega o IP da rede Wi-Fi/cabeada em uso.
    """
    ips: list[str] = []
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            ips.append(s.getsockname()[0])
    except OSError as erro:
        print(f"[SIG] não consegui descobrir o IP principal: {erro}")

    # Complementa com o que o hostname resolve, para casos de várias interfaces.
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            ip = info[4][0]
            if not ip.startswith("127.") and ip not in ips:
                ips.append(ip)
    except socket.gaierror as erro:
        print(f"[SIG] não consegui resolver o hostname: {erro}")

    return ips


async def _principal() -> None:
    print("=== trama-cam desk edge — etapa 1 ===")
    for ip in _ips_locais():
        print(f"[SIG] no celular, digite: {ip}   (ws://{ip}:{WS_PORT}{WS_PATH})")
    print("[SIG] Ctrl+C para sair\n")

    await rodar_servidor()


def main() -> None:
    try:
        asyncio.run(_principal())
    except KeyboardInterrupt:
        print("\n[SIG] encerrado pelo usuário")


if __name__ == "__main__":
    main()
