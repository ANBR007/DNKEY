# dnkey

> Memória permanente deste projeto. Criado automaticamente em 2026-09-09 10:53.
> Edite livremente o que está acima do bloco SESSOES — só o bloco é reescrito sozinho.

## Projeto

- **Git**: branch `main` · remote `https://github.com/ANBR007/DNKEY.git`
- **Pastas**: Resources Scripts Sources dist

## Objetivo

_(a preencher — o que este projeto precisa entregar)_

## Decisões e convenções

_(a preencher — escolhas que não devem ser refeitas)_
<!-- SESSOES:INICIO -->

## Histórico de sessões
<!-- Reescrito automaticamente. Últimas 5 sessões. Não edite aqui. -->

### Sessão 013db8ff — atualizada em 2026-09-09 10:53 · branch `main`

**O que foi pedido:**
- continue mexendo no app
- tudo que nao for para o usuario ter acesso como claude.md essas coisas tire da pasta e coloque separado

**Arquivos alterados:**
- `Scripts/build_app.sh`
- `Sources/DNKEY/ForceSensor.swift`

**Comandos relevantes:**
- `pgrep -lf DNKEY; echo "---crash logs---"; ls -t ~/Library/Logs/DiagnosticReports/DNKEY* 2>/dev/null | head -3; echo "---`
- `pkill -f "dist/DNKEY.app/Contents/MacOS/DNKEY"; cat /tmp/claude-501/-Users-andreluizcampostoledo/013db8ff-0124-44b2-aeb0`
- `python3 -c " import json,sys p='/Users/andreluizcampostoledo/Library/Logs/DiagnosticReports/DNKEY-2026-09-09-101053.ips'`
- `python3 -c " import re d=open('/Applications/DNKEY.app/Contents/MacOS/DNKEY','rb').read() out=set() for m in re.finditer`
- `swift --version 2>&1 | head -3; echo "=== XCODE ==="; xcode-select -p; echo "=== APP RODANDO? ==="; pgrep -l DNKEY || ec`
- `timeout 60 find /Users/andreluizcampostoledo -type f \( -name "*.swift" -o -name "Package.swift" \) -not -path "*/Librar`

**Onde parou:**

> Para subir, com a sua escolha de deixar privado primeiro:
> ```
> ! gh auth login
> ! gh repo edit ANBR007/DNKEY --visibility private --accept-visibility-change-consequences
> ! git -C ~/Desktop/dnkey push -u origin main
> ! gh release create v0.2.0 ~/Desktop/dnkey/dist/DNKEY-0.2.0.zip --repo ANBR007/DNKEY --title "DNKEY 0.2.0"
> ```
> Se preferir, faça só o `gh auth login` e eu rodo o resto. Uma coisa que ficou pendente da mensagem anterior: o `/Applications/DNKEY.app` ainda é a **v0.1.0** (Sonoma-only, arm64) — quer que eu troque 


<!-- SESSOES:FIM -->
