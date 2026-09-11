#!/bin/bash
# Compila e instala o DNKEY em /Applications, substituindo a versão anterior.
set -euo pipefail

cd "$(dirname "$0")/.."
DEST="/Applications/DNKEY.app"

./Scripts/build_app.sh

echo "==> Instalando em $DEST"

if pgrep -f "DNKEY.app/Contents/MacOS/DNKEY" > /dev/null 2>&1; then
    echo "    fechando a versão que está rodando"
    pkill -f "DNKEY.app/Contents/MacOS/DNKEY" || true
    sleep 1
fi

if [ -e "$DEST" ]; then
    ANTIGA="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || echo '?')"
    echo "    substituindo a versão $ANTIGA já instalada"
    rm -rf "$DEST"
fi

cp -R dist/DNKEY.app "$DEST"

# Sem isso o macOS trata o app como baixado da internet e bloqueia a primeira abertura.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

NOVA="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist")"
echo
echo "DNKEY $NOVA instalado. Abrindo…"
open "$DEST"
echo
echo "Se for a primeira instalação, conceda a permissão em"
echo "Ajustes do Sistema › Privacidade e Segurança › Acessibilidade."
