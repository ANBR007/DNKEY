#!/bin/bash
# Gera dist/DNKEY.app — binário universal (arm64 + x86_64) para macOS 13 Ventura ou superior,
# e falha o build se alguma dessas garantias se perder.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/dist/DNKEY.app"
BINARY="$APP/Contents/MacOS/DNKEY"
MIN_MACOS="13.0"
VERSION="$(sed -n 's/^VERSION=//p' VERSION 2>/dev/null || echo "0.2.0")"

fail() { echo "ERRO: $1" >&2; exit 1; }

echo "==> Compilando universal (arm64 + x86_64), alvo macOS ${MIN_MACOS}"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/DNKEY"

echo "==> Montando o bundle"
# Saída de build descartável: só a pasta dist/ deste projeto é recriada.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$BINARY"
cp -R "$ROOT/Resources/SoundPacks" "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>DNKEY</string>
    <key>CFBundleDisplayName</key><string>DNKEY</string>
    <key>CFBundleExecutable</key><string>DNKEY</string>
    <key>CFBundleIdentifier</key><string>com.anbr007.dnkey</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>${MIN_MACOS}</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 André Luiz Campos Toledo. MIT License.</string>
</dict>
</plist>
PLIST

echo "==> Assinando (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "==> Verificando compatibilidade"

# 1. As duas arquiteturas. Ventura ainda roda em Mac Intel, então x86_64 não é opcional.
ARCHS="$(lipo -archs "$BINARY")"
[[ "$ARCHS" == *arm64* ]]  || fail "fatia arm64 ausente (tem: $ARCHS)"
[[ "$ARCHS" == *x86_64* ]] || fail "fatia x86_64 ausente (tem: $ARCHS) — Ventura roda em Mac Intel"

# 2. Deployment target em cada fatia. Se subir para 14.0, o app some para quem está no Ventura.
for a in arm64 x86_64; do
    MINOS="$(otool -arch "$a" -l "$BINARY" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}')"
    [ "$MINOS" = "$MIN_MACOS" ] || fail "fatia $a compilada para macOS $MINOS, esperado $MIN_MACOS"
done

# 3. O Info.plist precisa concordar com o binário.
PLIST_MIN="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
[ "$PLIST_MIN" = "$MIN_MACOS" ] || fail "Info.plist diz $PLIST_MIN, binário diz $MIN_MACOS"

# 4. Dylib sem weak-link precisa existir no Ventura, senão o app nem abre lá. As conhecidas
#    estão nesta lista; qualquer novidade vira aviso para conferir antes de publicar.
CONHECIDAS="Foundation|libobjc|libSystem|AVFAudio|AppKit|ApplicationServices|Combine|CoreFoundation|CoreGraphics|IOKit|SwiftUI|libswiftCore\.|libswiftCoreFoundation|libswiftDispatch|libswiftObjectiveC"
#    (-arch fixo: num binário universal o otool -L repete o caminho do próprio binário)
NOVAS="$(otool -arch arm64 -L "$BINARY" | tail -n +2 | grep -v 'weak)' | awk '{print $1}' | grep -vE "$CONHECIDAS" || true)"
if [ -n "$NOVAS" ]; then
    echo "AVISO: dylib linkada sem weak-link e fora da lista conhecida —"
    echo "$NOVAS" | sed 's/^/  /'
    echo "  confirme que existe no macOS ${MIN_MACOS} antes de publicar."
fi

echo "    arquiteturas: $ARCHS"
echo "    macOS mínimo: $MIN_MACOS (binário e Info.plist)"

echo "==> Compactando para a Release"
# Nome fixo de propósito: é o que faz a URL de download
# releases/latest/download/DNKEY.zip continuar valendo a cada versão.
( cd "$ROOT/dist" && ditto -c -k --keepParent DNKEY.app "DNKEY.zip" )

echo
echo "Pronto: $APP"
echo "Zip:    $ROOT/dist/DNKEY.zip (versão ${VERSION})"
