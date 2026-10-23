# Protocolo do Redragon K652 RGB PRO

Reconstruído do `KeyboardDrv.exe` (MFC, 32 bits) do instalador `Redragon_K652-RGB-PRO_Setup_V1.6.6_20230324.exe`, em 22–23/10/2026. Ferramentas: `innoextract` para abrir o instalador, [REA](https://github.com/morluto/rea) 6.7.0 com Ghidra 12.1.4 para decompilar, e `pefile`/`capstone` para conferir chamadas e constantes. Os endereços abaixo são do executável carregado na base `0x400000`.

O que ainda não foi conferido com o teclado ligado pelo cabo está marcado como **não testado**.

## Dispositivo

- USB `VID 0x258A`, `PID 0x0049` (`Cfg.ini`, linhas 26–27). O VID é da SinoWealth e aparece em outros teclados.
- O driver abre o HID por SetupAPI (`SetupDiGetClassDevsW`, `SetupDiEnumDeviceInterfaces`) e escolhe as coleções pela página `0xFF00`, uso 1, olhando o `FeatureReportByteLength` de `HidP_GetCaps` (filtro em `FUN_0040dc10` e `FUN_0040dd00`):

| Report | Tamanho (com o ID) | Uso |
|---|---|---|
| 5 | 6 bytes | comandos |
| 6 | `0x408` (1032) bytes | blocos de dados |
| 8 | `0x17E` (382) bytes | quadros de cor ao vivo |

- Chamadas HID: `HidD_SetFeature` (thunk `0x56652c`), `HidD_GetFeature` (`0x566532`), `HidD_GetAttributes` (`0x566538`).
- No macOS: `IOHIDDeviceSetReport`/`GetReport` com `kIOHIDReportTypeFeature`. O buffer inclui o ID no byte 0.

### O Azure no USB do Mac (23/10/2026)

O macOS mostra dois dispositivos `258A:0049`, "Gaming Keyboard", fabricante "BY Tech":

- um só com o teclado (página 1, uso 6), descritor de 67 bytes, sem feature report;
- um com seis coleções (System Control, Consumer, `0xFF00` uso 1, teclado NKRO, mouse), descritor de 251 bytes. É nele que estão os reports 5 (5 bytes + ID), 6 (`0x407` + ID) e 8 (`0x17D` + ID), iguais aos que o driver filtra.

Como os canais de configuração dividem o dispositivo com um teclado, o macOS exige **Monitoramento de Entrada**. Sem a permissão, `IOHIDDeviceOpen` devolve `0xE00002E2` (kIOReturnNotPermitted) e `IOHIDDeviceCopyMatchingElements` devolve uma lista vazia. O descritor bruto (`kIOHIDReportDescriptorKey`) continua legível. Por isso o app tira os tamanhos dos reports do descritor (`ReportDescriptor.swift`) e consegue dizer que falta a permissão, em vez de achar que o teclado não está lá.

## Leitura e gravação

**Leitura**: `SetFeature` no report 5 com `[05, cmd, endereço, 00, 00, 00]`. Depois de 20 ms, `GetFeature` no report 6. A resposta começa com `[06, cmd, ...]`, e os dados vêm a partir do byte 8. Para `0x83` o driver confere `resposta[1] == cmd`.

No Azure, a resposta ao `0x83` tem **262 bytes**, não os 1032 que o descritor declara; a do `0x84` vem completa. O macOS entrega o report com o ID no byte 0, só que mais curto. A primeira versão do app achava que faltava o ID, colocava outro `06` na frente e recusava a resposta.

**Gravação**: um único `SetFeature` no report 6:

```
[06, cmd, endereço, 00, marcador, 00, 00, 00] + dados a partir do byte 8
```

O marcador é `0x40` nos blocos grandes (`0x04`, `0x05`, `0x08`, `0x09`) e `0` no `0x03`. O driver tenta 3 vezes, com 200 ms entre tentativas, e espera 50 ms entre gravações.

Os endereços são páginas de 256 bytes da flash.

| Comando | Endereço | Conteúdo | Função no driver |
|---|---|---|---|
| `0x81` | — | identificação; resposta no report 5: `[05, 01, PSD...]` | `FUN_004454a0` |
| `0x83` / `0x03` | `0xB6` (ProAddr) | bloco de iluminação, 136 bytes | `FUN_004456d0` (ler), `FUN_004455d0` (gravar) |
| `0x84` / `0x04` | `0xD4` (KeyAddr) | matriz de teclas, 1024 bytes | `FUN_004458b0`, `FUN_004459d0` |
| `0x08` | `0xB8` (RgbTabAddr) | paleta de cada efeito | `FUN_00445af0` |
| `0x09` | `0xBC` e `0xC0` (GameAddr) | cores por tecla, dois pedaços de 1024 bytes | `FUN_00445800` |
| `0x05` | `0xDC`, `0xE0`, `0xE4`, `0xE8` | macros (o app não usa) | `FUN_00445bd0` |

PSD esperado do K652: `02 00 00 00 01 AB` (`Cfg.ini`, linha 35).

## Bloco de iluminação (136 bytes)

Montado em `FUN_0040d240` e sincronizado em `FUN_0040d3b0` (ApplySetting). O driver lê o bloco, troca estes campos e grava de volta. O resto volta como veio.

| Byte | Valor |
|---|---|
| 0 | zerado antes de gravar |
| 12 | 1 quando o modo é Personalizado (índice 20 da interface, `GaoshouIndex=20`) |
| 13 | modo de hardware: 0 desligado, 1–21 |
| 14 | `0x20` + grupo personalizado (0–4) |
| 28, 29 | `FF FF` |
| 30 + 2k | cor do modo k (k = 0–21, modo de hardware k+1). Nibble baixo: índice da paleta 0–6, ou 7 para aleatório. Nibble alto: direção (0 ou 8), só nos modos com direção |
| 31 + 2k | `(velocidade << 4) \| brilho`, os dois de 0 a 4 (`SpeedHW`/`LightHW=0,1,2,3,4`) |
| 70, 71 | assinatura `5A A5`, escrita depois do laço (sobrepõe os bytes do modo 21) |

Os 22 modos e as capacidades de cada um (velocidade, brilho, direção, aleatório, cor) vêm de `text.xml` e da tabela LedOpt. `LedMask=0x80000` esconde o índice 19 ("Perfect") neste modelo.

**Não testado**: o sentido da velocidade (0 pode ser a mais rápida ou a mais lenta).

## Paleta (`0x08`)

`FUN_00445af0` monta `[08, addr, 00, 40, 00, 00, 00]` + 21 bytes zerados, depois 21 bytes para cada modo k = 0–21. Total: 483 bytes de dados. Em `FUN_0040d3b0`, cada modo leva 7 cores com R, G e B intercalados (`cor·3 + RGBIndex`, com `RGBIndex=0,1,2`). As cores do driver são `R,G,B` no Cfg.ini, guardadas como COLORREF (byte 0 = R).

## Cores por tecla (`0x09`)

5 grupos × 3 planos (R, G, B) × `0x7E` bytes. Índice: `(3·grupo + canal)·0x7E + posição`. Total: 1890 bytes, divididos em dois pedaços de 1024 gravados em `0xBC` e `0xC0`.

A posição **não é o LED**. Cada entrada `[KEY]` do `Cfg.ini` tem 9 campos: retângulo (4), tipo, VK, um byte extra, LED e posição. `FUN_0043eed0` guarda o campo 7 (LED, `coluna·6 + linha`, validado com "Wrong matrix index value!") em `DAT_005dcd94` e o campo 8 em `DAT_005dcdcc`. `FUN_0040d3b0` grava a cor da tecla em `plano·0x7E + DAT_005dcdcc`, ou seja, pelo campo 8, que segue `linha·21 + coluna` (0–119). O quadro ao vivo (`FUN_00446910`) e a matriz de teclas usam o LED.

Até 23/10/2026 o app indexava os planos pelo LED: o ao vivo saía certo e as cores salvas caíam em teclas trocadas.

## Quadro ao vivo (report 8)

`[08, 0A, 7A, 01]` + 126 × RGB intercalado (`FUN_004453b0`, `FUN_00446910`, modo música). Não grava na flash. O mesmo formato aparece no plugin SignalRGB `XC_Store_is67.js` ([NollieL/SignalRgb_CN_Key](https://github.com/NollieL/SignalRgb_CN_Key)) para o mesmo VID/PID.

**Não testado**: se o teclado aceita o quadro em qualquer modo ou só num modo específico.

## Matriz de teclas (`0x84`/`0x04`)

132 entradas de 4 bytes, mais as camadas Fn em `0x210` e `0x2D0`. Codificação em `FUN_0040ce80` e `FUN_0040c2a0`.

A posição de cada tecla na matriz é a **mesma do LED** (coluna × 6 + linha), não o último campo do `[KEY]` do `Cfg.ini`. Na matriz lida do Azure em 23/10/2026, pela ordem dos LEDs, 52 teclas têm o próprio uso HID e 31 têm entrada de função Fn; pelo campo do `Cfg.ini`, só 1 batia.

| Ação | Bytes |
|---|---|
| tecla comum | `00 00 modificadores uso` |
| modificador sozinho | `06 00 00 E0..E7` |
| mídia (página Consumer) | `04 00 usoAlto usoBaixo` (ex.: `0x0183` → `04 00 01 83`) |
| tecla com função Fn | `02 00 00 nn`, com `nn` indexando a tabela da camada Fn. No Azure: Esc, F1–F12 (`00`–`0B`), 1–4 (`20`–`23`), Tab, O, P, G, End, PgUp, PgDn, Shift direito, Win, espaço e setas |
| macro | byte 3 = buffer − 1 |
| desativada | `00 00 00 00` (**não testado**) |

Antes de gravar, o app confere que pelo menos 75% das teclas estão no lugar (com o uso padrão ou com função Fn); uma matriz lida na ordem errada quase não tem acertos. As teclas com função Fn não são trocadas pelo cabo: a entrada nova apagaria o índice da função, sem como restaurar.

## Testado no Azure (23/10/2026)

Firmware `0x0104`, pelo cabo:

- identificação `0x81`: `05 01 02 00 00 00` (o report 5 só tem 6 bytes; o primeiro byte do PSD, `02`, bate);
- leitura do bloco de iluminação: `FF FF` nos bytes 28–29 e `5A A5` nos bytes 70–71, como em `FUN_0040d240`;
- gravação: brilho do modo 3 de 3 para 4 (byte 35: `13` → `14`), relido do teclado, e de volta para 3;
- quadro ao vivo (report 8): 30 quadros aceitos;
- **o teclado pode sair do USB e voltar cerca de 1 s depois de uma gravação de iluminação** (kernel: `terminateDevice … hardware connection lost`, seguido de `enumerated 0x258a/0049/0104`). A conexão antiga passa a responder `0x10000003` (MACH_SEND_INVALID_DEST). O transporte reabre e repete a operação, e o app reabre a conexão a cada aviso de reconexão. Não acontece sempre: gravar Fixo por cima de Fixo, trocando só a cor (13:09, slot 5 → 1), não reiniciou o USB (o `sessionID` da enumeração continuou o das 13:02). Por isso o app não percebe uma gravação feita por fora (`k652ctl`) e só a mostra quando é reaberto;
- Fixo com o slot 1 da paleta padrão (`00 00 FF`) gravado e relido: byte 30 = `01`, byte 31 = `44`;
- **não testado**: gravação da matriz de teclas, das cores por tecla (`0x09`) com a posição do campo 8 e o sentido da velocidade.

## Segurança

O OpenRGB desativou o controlador Sinowealth depois de relatos de K617 (mesmo VID/PID) que pararam de responder após gravações. O app só grava quando a identificação não contradiz o PSD do K652 e o bloco de iluminação lido tem a assinatura `5A A5`.

## Bluetooth

Verificado em 23/10/2026, com o K652 pareado num Mac (macOS 27):

- O macOS vê o teclado como "BT 5.0KB", fabricante BEKEN, `VID 0x000E`, `PID 0x3412`, transporte Bluetooth Low Energy.
- O descritor HID dessa conexão tem 153 bytes e quatro coleções: teclado (report 1, com o report de saída dos LEDs de Caps/Num Lock), teclado NKRO (report 2, 160 bits), Consumer (report 3) e System Control (report 4). Não tem feature report nem a página `0xFF00`.
- O `KeyboardDrv.exe` não tem referência a Bluetooth, GATT, dongle ou 2.4G. Ele só procura `258A:0049`.

Conclusão: por Bluetooth não há canal para iluminação nem para a matriz de teclas. O que fica gravado pelo cabo continua valendo no Bluetooth, porque está na flash do teclado.

Não foi verificado se o módulo BEKEN publica algum serviço GATT próprio além do HID: o CoreBluetooth exige uma permissão de Bluetooth que um binário de linha de comando não tem. Mesmo que exista, não há protocolo conhecido para ele, e o driver oficial não o usa.

Para trocar teclas pelo Bluetooth, o app usa o remapeamento do macOS, aplicado só a esse teclado:

```sh
hidutil property --matching '{"VendorID":14,"ProductID":13330}' \
  --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":30064771144,"HIDKeyboardModifierMappingDst":51539607757}]}'
```

Origem e destino são `(página << 32) | uso`: `0x7` para teclado, `0xC` para Consumer. O exemplo troca Pause (`0x700000048`) por Tocar/Pausar (`0xC000000CD`). Funciona sem root. Foi testado aplicando e lendo de volta com `--get UserKeyMapping`.
