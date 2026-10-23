#!/bin/zsh
# Gera "Teclado K652.app" na raiz do projeto e, com --install, copia para /Applications.
set -euo pipefail

ROOT="${0:A:h:h}"
APP_NAME="Teclado K652"
BUNDLE_ID="local.samuel.teclado-k652"
VERSION="1.0.0"
APP="$ROOT/$APP_NAME.app"
BUILD="$ROOT/.build"
ICON_WORK="$BUILD/icon"

cd "$ROOT"
swift build -c release --product K652App
swift build -c release --product k652ctl
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP" "$ICON_WORK"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICON_WORK/AppIcon.iconset"
cp "$BIN/K652App" "$APP/Contents/MacOS/K652App"
cp "$BIN/k652ctl" "$APP/Contents/MacOS/k652ctl"

swift scripts/make-icon.swift "$ICON_WORK/icon_1024.png"
for px in 16 32 128 256 512; do
  sips -z $px $px "$ICON_WORK/icon_1024.png" --out "$ICON_WORK/AppIcon.iconset/icon_${px}x${px}.png" >/dev/null
  sips -z $((px * 2)) $((px * 2)) "$ICON_WORK/icon_1024.png" --out "$ICON_WORK/AppIcon.iconset/icon_${px}x${px}@2x.png" >/dev/null
done
iconutil -c icns "$ICON_WORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>K652App</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Uso pessoal. Protocolo obtido por engenharia reversa do driver Redragon.</string>
</dict>
</plist>
PLIST

# Assinatura ad-hoc com requisito pelo identificador: sem ele, o macOS amarra a permissão de
# Monitoramento de Entrada ao cdhash, que muda a cada compilação, e a permissão se perde.
codesign --force --sign - --identifier "$BUNDLE_ID.ctl" "$APP/Contents/MacOS/k652ctl"
codesign --force --sign - --identifier "$BUNDLE_ID" \
  --requirements "=designated => identifier \"$BUNDLE_ID\"" "$APP"
codesign --verify --deep --strict "$APP"
codesign -d -r- "$APP" 2>&1 | grep designated
echo "pronto: $APP"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP" "/Applications/"
  echo "instalado: /Applications/$APP_NAME.app"
fi
