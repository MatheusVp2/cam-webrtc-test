"""Saída de vídeo: por enquanto só uma janela do OpenCV.

Na etapa 2 esta classe passa a escrever na câmera virtual do OBS via
pyvirtualcam; a interface (`show` / `close`) fica igual para o resto do
código não precisar mudar.
"""

import time

import cv2
import numpy as np

from config import FRAME_STALL_WARN_S, PREVIEW_WINDOW_TITLE


class PreviewWindow:
    """Mostra frames BGR numa janela do OpenCV e conta fps."""

    def __init__(self, title: str = PREVIEW_WINDOW_TITLE) -> None:
        self._title = title
        self._aberta = False
        self._frames = 0
        self._t_ultimo_frame = 0.0
        self._t_ultimo_log = 0.0

    def show(self, frame_bgr: np.ndarray) -> None:
        """Desenha um frame. Precisa rodar sempre na mesma thread.

        O OpenCV exige que `imshow` e `waitKey` sejam chamados na thread que
        criou a janela; como toda a leitura de frames acontece na thread do
        asyncio, isso é respeitado naturalmente.
        """
        agora = time.monotonic()

        # Avisa quando o vídeo trava — ajuda a distinguir "Wi-Fi ruim" de "bug".
        if self._t_ultimo_frame and agora - self._t_ultimo_frame > FRAME_STALL_WARN_S:
            print(
                f"[CAM] vídeo parado por {agora - self._t_ultimo_frame:.1f}s, voltou agora"
            )
        self._t_ultimo_frame = agora

        if not self._aberta:
            altura, largura = frame_bgr.shape[:2]
            cv2.namedWindow(self._title, cv2.WINDOW_NORMAL)
            cv2.resizeWindow(self._title, largura, altura)
            self._aberta = True
            self._t_ultimo_log = agora
            print(f"[CAM] janela aberta em {largura}x{altura}")

        cv2.imshow(self._title, frame_bgr)
        # waitKey é o que efetivamente redesenha a janela; 1ms é o mínimo útil.
        cv2.waitKey(1)

        self._frames += 1
        if agora - self._t_ultimo_log >= 5.0:
            fps = self._frames / (agora - self._t_ultimo_log)
            altura, largura = frame_bgr.shape[:2]
            print(f"[CAM] {largura}x{altura} @ {fps:.1f} fps")
            self._frames = 0
            self._t_ultimo_log = agora

    def close(self) -> None:
        if self._aberta:
            cv2.destroyWindow(self._title)
            # No Linux a janela só some de fato depois de mais um waitKey.
            cv2.waitKey(1)
            self._aberta = False
            print("[CAM] janela fechada")
