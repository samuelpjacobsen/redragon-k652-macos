---
name: Relato de problema ou de outro teclado
about: Algo não funcionou, ou você testou num modelo ou firmware diferente
---

**Teclado**: modelo impresso embaixo do teclado (ex.: K652GG-RGB-PRO)
**Firmware**: o que aparece na aba Diagnóstico (ex.: 0x0104)
**Conexão**: cabo USB, Bluetooth ou 2.4G
**macOS**: versão

**O que você fez**

**O que esperava**

**O que aconteceu** (no app e nas luzes do teclado)

**Diagnóstico**

Pelo cabo, rode o comando abaixo e cole o conteúdo do arquivo. Ele só lê o teclado, não grava nada. O `open` faz o diagnóstico rodar como o app, com a permissão de Monitoramento de Entrada dele.

```sh
open -W -n -a "Teclado K652" --args --diagnostico ~/Desktop/k652-diagnostico.txt
```
