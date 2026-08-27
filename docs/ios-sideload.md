# Rodar o app no iPhone sem Mac

Contexto: desenvolvimento em Linux, iPhone 15 Pro com iOS 26.6.

## O que o CI resolve e o que não resolve

`.github/workflows/ios.yml` compila o app num runner macOS do GitHub e gera
`trama-cam-unsigned.ipa`. Em repositório público esses minutos de macOS são
gratuitos.

O que ele **não** faz é assinar o app. Sem assinatura, o iPhone recusa a
instalação. Assinar exige uma chave da Apple, e é aí que estão as escolhas.

## Por que TrollStore não serve aqui

TrollStore assina permanentemente, sem Apple ID e sem expirar — mas depende de
uma falha do CoreTrust que a Apple corrigiu no iOS 17.0. Só funciona até
iOS 16.6.1 (e a 17.0 exata). iOS 26.6 está muito além disso.

## Caminho A — SideStore (grátis)

Assina com um Apple ID comum. Limitações que vêm da Apple, não da ferramenta:

- certificado válido por **7 dias** (o SideStore renova sozinho no aparelho,
  sem precisar do PC ligado, desde que o pareamento esteja configurado)
- no máximo **3 apps** sideloaded ao mesmo tempo
- 10 App IDs novos por semana
- **Modo de Desenvolvedor** precisa estar ligado no iPhone:
  Ajustes → Privacidade e Segurança → Modo de Desenvolvedor

Forma geral do processo:

1. Ligar o Modo de Desenvolvedor no iPhone.
2. Gerar um *pairing file* do aparelho pelo Linux. As ferramentas são as do
   `libimobiledevice` (`idevicepair`), com o iPhone no cabo USB e o "Confiar
   neste computador" aceito.
3. Instalar o próprio SideStore no aparelho.
4. Entrar com o Apple ID dentro do SideStore.
5. Baixar o `.ipa` do trama-cam pelo Safari e abrir no SideStore.

> **Confira a compatibilidade antes de investir tempo.** O procedimento de
> instalação do SideStore muda com frequência e o iOS 26 é recente. Siga a
> documentação oficial em <https://sidestore.io> para a versão atual, e
> verifique lá se o iOS 26.6 já é suportado — se ainda não for, o caminho B é
> a alternativa.

Dica: use uma **Apple ID separada**, não a sua principal. O SideStore precisa
da senha para gerar o certificado.

## Caminho B — Apple Developer Program (US$ 99/ano)

Sem gambiarra e sem os 7 dias. O mesmo workflow passa a assinar de verdade:

1. Certificado de distribuição e provisioning profile gerados no portal da
   Apple.
2. Guardados como secrets no repositório (`.p12` em base64 + senha).
3. O workflow importa os dois num keychain temporário e roda
   `flutter build ipa` (sem `--no-codesign`).
4. Distribuição por TestFlight (app dura 90 dias, atualização por push) ou
   ad-hoc com o UDID do aparelho registrado.

Se escolher esse caminho, eu monto os passos de assinatura no workflow.

## Caminho C — nem instalar app

`flutter_webrtc` funciona no Safari. Dava para rodar o build web e abrir pelo
navegador do iPhone, sem instalar nada. O porém é que o Safari só libera a
câmera em HTTPS, e página HTTPS não abre `ws://` — precisaria de certificado
local confiado no iPhone e de TLS no `desk_edge_py`.

Serve para testar rápido; não serve como produto, porque o encoder passa a ser
o do Safari e perdemos o controle de bitrate que a etapa 4 do roadmap pede.

## Baixar o .ipa

- **Artifact do workflow:** aba Actions → execução → seção Artifacts. Vem
  dentro de um `.zip`, exige estar logado no GitHub. Chato pelo iPhone.
- **Release:** empurre uma tag `v*` e o workflow anexa o `.ipa` direto na
  Release. Link público, baixa pelo Safari em um toque. É o caminho fácil.
