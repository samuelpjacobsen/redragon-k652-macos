# Teclado K652 no Mac

App macOS (SwiftUI + IOKit HID) que configura o Redragon K652 RGB PRO. Protocolo obtido por engenharia reversa do `KeyboardDrv.exe`; evidências em `pesquisa/PROTOCOLO.md`.

## Stack

- Swift 6 toolchain, modo de linguagem Swift 5, macOS 14+. SwiftPM, sem Xcode (só Command Line Tools).
- `K652Kit` (biblioteca: protocolo e formatos), `K652App` (SwiftUI), `k652ctl` (CLI).

## Comandos

```sh
swift build
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
./scripts/build-app.sh --install
```

Sem o `-plugin-path` o `swift test` falha com "plugin for module 'TestingMacros' not found".

## Convenções

- Interface e mensagens de erro em pt-BR.
- Não use `@State`: no SDK do macOS 27 ele também é uma macro, e o plugin dela só vem com o Xcode. Use `@ViewState` (`Sources/K652App/ViewState.swift`).
- Toda gravação é ler, modificar e gravar: preserve os bytes desconhecidos do bloco.
- Nunca grave sem `looksLikeK652` (identificação + assinatura `5A A5`), a não ser com liberação explícita do usuário. O VID/PID é compartilhado com outros teclados SinoWealth.
- Pelo Bluetooth (`000E:3412`, "BT 5.0KB") não existe canal de configuração. Não tente mandar reports para ele; a aba Teclas usa `hidutil` UserKeyMapping (`HostKeyRemap`).
- Byte, offset e endereço novos precisam citar a função do driver de onde vieram (ex.: `FUN_0040d240`).
- Testes em Swift Testing (`@Test`), em Arrange-Act-Assert, sobre os codificadores de bloco.
