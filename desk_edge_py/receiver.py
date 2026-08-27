"""Ponta WebRTC do desktop: recebe a track de vídeo do celular.

O celular é quem tem a mídia, então ele cria a offer (`sendonly`) e nós
respondemos com a answer (`recvonly`). Aqui só reagimos.
"""

import asyncio

from aiortc import RTCIceCandidate, RTCPeerConnection, RTCSessionDescription
from aiortc.mediastreams import MediaStreamError
from aiortc.sdp import candidate_from_sdp

from output import PreviewWindow


class VideoReceiver:
    """Uma sessão WebRTC com um celular. Vive enquanto o WebSocket viver."""

    def __init__(self, saida: PreviewWindow) -> None:
        self._saida = saida
        self._pc = RTCPeerConnection()
        self._tarefa_frames: asyncio.Task | None = None
        self._registrar_eventos()

    def _registrar_eventos(self) -> None:
        @self._pc.on("connectionstatechange")
        async def _() -> None:
            print(f"[RTC] estado da conexão: {self._pc.connectionState}")

        @self._pc.on("iceconnectionstatechange")
        async def _() -> None:
            print(f"[RTC] estado do ICE: {self._pc.iceConnectionState}")

        @self._pc.on("track")
        def _(track) -> None:
            print(f"[RTC] track recebida: {track.kind}")
            if track.kind != "video":
                return
            self._tarefa_frames = asyncio.ensure_future(self._bombear_frames(track))

            @track.on("ended")
            async def _() -> None:
                print("[RTC] track encerrada pelo celular")

    async def _bombear_frames(self, track) -> None:
        """Lê frames da track até ela acabar e joga na saída de vídeo."""
        print("[RTC] começando a ler frames")
        try:
            while True:
                frame = await track.recv()
                # `frame` é um av.VideoFrame já decodificado (YUV). Converter para
                # BGR aqui é o formato que o OpenCV — e depois o pyvirtualcam —
                # esperam.
                self._saida.show(frame.to_ndarray(format="bgr24"))
        except MediaStreamError:
            # Fim normal: o celular parou de enviar ou a conexão caiu.
            print("[RTC] fluxo de frames terminou")
        except asyncio.CancelledError:
            raise
        except Exception as erro:
            print(f"[RTC] erro lendo frames: {erro!r}")
        finally:
            self._saida.close()

    async def tratar_offer(self, sdp: str) -> str:
        """Aplica a offer do celular e devolve o SDP da answer."""
        await self._pc.setRemoteDescription(RTCSessionDescription(sdp=sdp, type="offer"))

        answer = await self._pc.createAnswer()
        # setLocalDescription só retorna depois que o aiortc já reuniu todos os
        # host candidates, então a answer já sai completa. Por isso não
        # precisamos enviar mensagens "ice" do PC para o celular.
        await self._pc.setLocalDescription(answer)
        print("[RTC] answer pronta")
        return self._pc.localDescription.sdp

    async def adicionar_ice(self, mensagem: dict) -> None:
        """Adiciona um candidate ICE trickled pelo celular."""
        texto = mensagem.get("candidate")
        if not texto:
            # Candidate vazio = "acabaram os meus candidates". Nada a fazer.
            print("[RTC] fim dos candidates do celular")
            return

        candidate: RTCIceCandidate = candidate_from_sdp(texto.removeprefix("candidate:"))
        candidate.sdpMid = mensagem.get("sdpMid")
        candidate.sdpMLineIndex = mensagem.get("sdpMLineIndex")
        await self._pc.addIceCandidate(candidate)
        print(f"[RTC] candidate adicionado: {texto[:60]}...")

    async def fechar(self) -> None:
        if self._tarefa_frames and not self._tarefa_frames.done():
            self._tarefa_frames.cancel()
            try:
                await self._tarefa_frames
            except asyncio.CancelledError:
                pass
        await self._pc.close()
        self._saida.close()
        print("[RTC] peer connection fechada")
