"""Configuração central do desk edge.

Nada de IP, porta, resolução ou fps espalhado pelo código — tudo mora aqui.
"""

# --- Protocolo de sinalização ---------------------------------------------
# Versão trocada no handshake hello/welcome. Se não bater, a conexão é recusada.
PROTOCOL_VERSION = "1"

# Nome que o desktop informa no welcome, só para o celular saber com quem falou.
SERVER_NAME = "tramacam-desktop"

# --- Servidor WebSocket ----------------------------------------------------
# 0.0.0.0 = escuta em todas as interfaces de rede (Wi-Fi, ethernet, USB tethering).
WS_HOST = "0.0.0.0"
WS_PORT = 8765
WS_PATH = "/ws"

# --- mDNS (etapa 3, ainda não usado) ---------------------------------------
MDNS_SERVICE_TYPE = "_tramacam._tcp.local."

# --- Saída de vídeo --------------------------------------------------------
PREVIEW_WINDOW_TITLE = "trama-cam preview"

# Quantos segundos sem frame antes de considerar a track travada e logar aviso.
FRAME_STALL_WARN_S = 2.0
