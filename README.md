# Teclado K652 no Mac

App nativo para macOS que controla a iluminação e as teclas do **Redragon Azure (K652GG-RGB-PRO)**, no lugar do driver de Windows (`Redragon_K652-RGB-PRO_Setup_V1.6.6_20230324.exe`).

## Como usar

1. Abra **Teclado K652** em `/Applications`. O selo no canto inferior esquerdo mostra a conexão: verde pelo cabo, azul pelo Bluetooth.
2. Para mudar a iluminação ou gravar teclas no teclado, ligue **o cabo USB**. A configuração fica salva no teclado, e depois dá para voltar ao Bluetooth.
3. Pelo cabo, o app precisa da permissão de **Monitoramento de Entrada**. Ela é obrigatória porque o Azure põe os canais de configuração no mesmo dispositivo USB do teclado. Na primeira vez, o app mostra um aviso com o botão "Abrir Monitoramento de Entrada". Ligue "Teclado K652" na lista e, se o macOS pedir, reabra o app. Ele conecta sozinho quando a permissão sai.

### Pelo cabo e pelo Bluetooth

| | Cabo USB | Bluetooth |
|---|---|---|
| Efeitos, brilho, velocidade, paleta | grava no teclado | não (o teclado não recebe) |
| Cores por tecla e pré-visualização ao vivo | grava no teclado | não |
| Trocar teclas | grava no teclado (inclui atalhos com modificador e desativar) | feito pelo macOS, só neste Mac (tecla por tecla ou por mídia) |

Pelo Bluetooth, o K652 só transmite teclas, mídia e energia. O descritor HID que ele publica nessa conexão não tem nenhum canal de configuração, e o driver oficial de Windows também só configura pelo cabo (detalhes em [pesquisa/PROTOCOLO.md](pesquisa/PROTOCOLO.md#bluetooth)). Por isso, pelo Bluetooth a aba Teclas usa o remapeamento do próprio macOS (`hidutil`), aplicado só a esse teclado. O macOS esquece esse remapeamento quando o teclado reconecta, e o app reaplica sozinho enquanto estiver aberto. Para valer também depois de reiniciar, ligue "Abrir ao iniciar sessão" na aba Teclas.

Abas:

- **Iluminação**: 21 efeitos do driver original, mais Desligado. Brilho e velocidade de 0 a 4, direção, cores aleatórias e a paleta de 7 cores de cada efeito. "Aplicar no teclado" (⌘↩) grava na memória do teclado.
- **Cores por tecla**: pinte clicando ou arrastando sobre as teclas, em 5 grupos personalizados. "Pré-visualizar ao vivo" acende as cores no teclado sem gravar. "Gravar e ativar" grava o grupo e troca o modo para Personalizado.
- **Teclas**: troque o que cada tecla faz. Pelo cabo, por outra tecla (com Ctrl, Shift, Alt ou Win), uma tecla de mídia, ou desative a tecla; as alterações ficam pendentes (laranja) até você gravar. Pelo Bluetooth, a troca vale na hora. A tecla Fn não é remapeável.
- **Diagnóstico**: interfaces HID, firmware, resposta de identificação e o bloco de iluminação em hexadecimal.

O teclado não devolve a paleta nem as cores por tecla. O app guarda o que você escolheu, e as teclas trocadas pelo Bluetooth, em `~/Library/Application Support/Teclado K652/estado.json`.

Para abrir direto numa aba: `open -a "Teclado K652" --args --secao Teclas`.

### Linha de comando

O bundle traz `k652ctl`, útil para testar o protocolo:

```sh
"/Applications/Teclado K652.app/Contents/MacOS/k652ctl" info        # identificação e modo atual
"/Applications/Teclado K652.app/Contents/MacOS/k652ctl" dump-light  # bloco de iluminação em hex
"/Applications/Teclado K652.app/Contents/MacOS/k652ctl" live 00AAFF 5   # azul ao vivo por 5 s, sem gravar
"/Applications/Teclado K652.app/Contents/MacOS/k652ctl" mode 1 4 2  # modo Fixo, brilho 4, velocidade 2
"/Applications/Teclado K652.app/Contents/MacOS/k652ctl" mode 1 4 4 1  # Fixo azul (slot 1 da paleta padrão)
```

## Segurança

O VID/PID `258A:0049` é da SinoWealth e aparece em outros teclados com firmware diferente. O OpenRGB desativou o controlador Sinowealth depois de relatos de K617 que pararam de responder após uma gravação no formato errado. Por isso o app só grava quando as duas condições abaixo valem:

- a identificação (comando `0x81`) não contradiz o PSD do K652 (`02 00 00 00 01 AB`);
- o bloco de iluminação lido tem a assinatura `5A A5` que o driver original grava.

Se alguma falhar, os botões de gravar ficam desativados e a aba Diagnóstico explica. Dá para liberar lá ou com `--force` no `k652ctl`, mas só faça isso se o teclado for mesmo o K652 RGB PRO.

Toda gravação lê o bloco atual do teclado, troca só os campos conhecidos e devolve o resto como veio.

## Como funciona

O protocolo foi tirado do `KeyboardDrv.exe` do instalador oficial, extraído com `innoextract` e decompilado com [REA](https://github.com/morluto/rea) sobre o Ghidra. O detalhe, com os endereços das funções que serviram de evidência, está em [pesquisa/PROTOCOLO.md](pesquisa/PROTOCOLO.md).

Em resumo, o teclado fala por *feature reports* HID na interface vendor (`0xFF00`): o report 5 manda comandos, o report 6 leva blocos de 1 KB para ler e gravar a flash, e o report 8 recebe quadros de cor ao vivo. No Mac isso passa pelo IOKit (`IOHIDDeviceSetReport`/`GetReport`). Não precisa de driver nem de extensão de kernel.

Código:

- `Sources/K652Kit/`: protocolo, transporte HID, formatos dos blocos e layout das 84 teclas.
- `Sources/K652App/`: interface em SwiftUI.
- `Sources/k652ctl/`: linha de comando.
- `Tests/K652KitTests/`: testes dos formatos de bloco.

## Compilar

Funciona só com o Command Line Tools, sem Xcode:

```sh
./scripts/build-app.sh            # gera "Teclado K652.app" na pasta do projeto
./scripts/build-app.sh --install  # e copia para /Applications
```

A assinatura é ad-hoc, com o requisito preso ao identificador do app (`local.samuel.teclado-k652`), não ao hash do binário. Sem isso, o macOS liga a permissão de Monitoramento de Entrada a uma compilação específica, e a chave aparece ligada sem valer para o app novo (no log do `tccd`: "Failed to match existing code requirement"). Para limpar uma permissão presa: `tccutil reset ListenEvent local.samuel.teclado-k652`.

## Limitações

- Testado pelo cabo no Azure (firmware 0x0104) em 23/10/2026: leitura, gravação do brilho relida do teclado e quadro ao vivo. Ainda não testados no teclado: gravar teclas, gravar cores por tecla e o sentido da velocidade.
- Depois de algumas gravações de iluminação, o teclado se desconecta do USB por um instante e volta. O app reabre a conexão sozinho. Uma gravação feita pelo `k652ctl` só aparece no app depois de reabrir o app.
- Pelo cabo, as teclas com função Fn (F1–F12, 1–4, setas, Esc, Win, espaço e outras) ficam travadas na aba Teclas: trocar apagaria a função Fn.
- O `k652ctl` só fala com o teclado se o programa que o roda (Terminal, Warp…) tiver a permissão de Monitoramento de Entrada.
- Pelo Bluetooth, o remapeamento foi testado aplicando e lendo de volta o mapeamento do macOS (23/10/2026). Falta conferir, apertando as teclas, se a troca por tecla de mídia funciona.
- Pontos que o driver não deixa claros: o sentido da velocidade (0 pode ser a mais rápida), se o quadro ao vivo funciona em qualquer modo e se `00 00 00 00` na matriz de teclas desativa a tecla.
- Macros, que o driver grava nos endereços `0xDC`–`0xE8`, ficaram de fora.
- O modo "Perfect" existe no firmware, mas o driver o esconde nesse modelo. O app também esconde.
- O receptor 2.4G não foi testado. O driver oficial também não o reconhece.
