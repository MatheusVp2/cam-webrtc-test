# Rodar o app no iPhone sem Mac

Contexto: desenvolvimento em Linux, iPhone 15 Pro com iOS 26.6.

## O que o CI resolve e o que não resolve

`.github/workflows/build.yml` compila o app num runner macOS do GitHub e gera
`trama-cam-unsigned.ipa`. Em repositório público esses minutos de macOS são
gratuitos.

O que ele **não** faz é assinar o app. Sem assinatura, o iPhone recusa a
instalação. Assinar exige uma chave da Apple, e é aí que estão as escolhas.

## Permissão de rede local

Na primeira conexão o iOS pergunta se o app pode acessar a rede local.
**Precisa aceitar** — sem isso o app não fala com o PC e nada funciona. Se
negar por engano: Ajustes → trama-cam → Rede Local.

## Por que TrollStore não serve aqui

TrollStore assina permanentemente, sem Apple ID e sem expirar — mas depende de
uma falha do CoreTrust que a Apple corrigiu no iOS 17.0. Só funciona até
iOS 16.6.1 (e a 17.0 exata). iOS 26.6 está muito além disso.

## Caminho A — SideStore (grátis)

Assina com um Apple ID comum. A documentação oficial cobre iOS 15.0 até 26.x,
então o iOS 26.6 está dentro.

Limitações que vêm da Apple, não da ferramenta:

- certificado válido por **7 dias** (o SideStore renova sozinho no aparelho)
- no máximo **3 apps** sideloaded ao mesmo tempo
- 10 App IDs novos por semana
- o iPhone precisa ter **código de acesso** configurado
- **Modo de Desenvolvedor** ligado, em Ajustes → Privacidade e Segurança
- tudo por **Wi-Fi**; rede móvel não serve

Use uma **Apple ID separada** da sua principal: o SideStore precisa da senha
para gerar o certificado.

### No computador (Ubuntu 24.04 x86_64)

```bash
sudo apt install usbmuxd
sudo systemctl enable --now usbmuxd
```

Baixe o **iloader** (`.deb` x86_64) em <https://docs.sidestore.io> e instale.
Ele é a ferramenta oficial do lado Linux; substituiu o AltServer e o
sideserver.

Com o iPhone no cabo USB e o "Confiar neste computador" aceito:

1. Abra o iloader.
2. Entre com o Apple ID (o campo diferencia maiúsculas de minúsculas).
3. Selecione o aparelho.
4. Escolha **Install SideStore (Stable)**.

### No iPhone

1. Instale o **LocalDevVPN** pela App Store. Ele é obrigatório e precisa estar
   **ligado** toda vez que você instalar, atualizar ou renovar um app.
2. Ajustes → Geral → VPN e Gerenciamento de Dispositivo → confie na sua Apple
   Account, em "App de Desenvolvedor".
3. Ajustes → Privacidade e Segurança → **Modo de Desenvolvedor** → ligar.
   Escolha "Permitir e Reiniciar" e digite o código depois do boot.
4. Abra o LocalDevVPN e conecte.
5. Abra o SideStore e entre com o **mesmo** Apple ID usado no iloader.
6. Em "My Apps", toque no contador **7 DAYS** para renovar e concluir a
   configuração.

### Instalar o trama-cam

Baixe o `.ipa` pelo Safari na Release do repositório e abra no SideStore. O
SideStore reescreve o bundle ID e assina na hora.

A cada 7 dias o certificado vence. Com o LocalDevVPN ligado, o SideStore
renova sozinho; se o app abrir e fechar na hora, é isso — abra o SideStore e
force a renovação em My Apps.

> Se o pareamento parar de funcionar depois de uma atualização ou restauração
> do iOS, é preciso gerar o pairing file de novo — veja o guia de pairing file
> na documentação do SideStore.

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
