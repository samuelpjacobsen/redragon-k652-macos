# Como contribuir

Relatos de outros modelos e firmwares ajudam tanto quanto código. Se o app não reconhecer o seu teclado, ou se algo acender diferente do esperado, abra uma issue com o modelo "Relato de problema ou de outro teclado". O diagnóstico que ele pede só lê o teclado.

## Compilar e testar

```sh
swift build
swift test
./scripts/build-app.sh --install
```

Com só o Command Line Tools, sem Xcode, o `swift test` não acha o plugin de macros do Swift Testing. Passe o caminho dele:

```sh
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

## Convenções

- Interface, mensagens de erro e documentação em pt-BR.
- Não use `@State` direto: no SDK do macOS 27 ele é uma macro cujo plugin só vem com o Xcode. Use `@ViewState` (`Sources/K652App/Support/ViewState.swift`).
- Um tipo público por arquivo, na pasta da sua responsabilidade (veja a estrutura no README).
- Toda gravação lê o bloco, troca só os campos conhecidos e grava de volta. Bytes desconhecidos voltam como vieram.
- Nunca grave sem `looksLikeK652` (identificação e assinatura `5A A5`).
- Byte, offset ou endereço novo cita a função do driver de onde veio (ex.: `FUN_0040d240`) e entra no `docs/PROTOCOLO.md`, marcado como **não testado** até ser conferido num teclado.
- Testes em Swift Testing (`@Test`), no formato Arrange-Act-Assert, com nomes que descrevem o comportamento. Correção de bug começa por um teste que reproduz a falha.
- Commits no formato `tipo: descrição` (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`).

## Engenharia reversa

O protocolo veio do `KeyboardDrv.exe` do instalador oficial (V1.6.6), decompilado com [REA](https://github.com/morluto/rea) sobre o Ghidra. Não inclua no repositório o instalador, o executável, arquivos extraídos dele nem código decompilado. Descreva o comportamento e cite o endereço da função.
