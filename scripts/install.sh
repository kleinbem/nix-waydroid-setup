#!/usr/bin/env bash
# Waydroid Setup - Install Magisk, Houdini, Widevine
set -euo pipefail

# These are substituted by Nix at build time
ASSETS="${ASSETS:-}"
WAYDROID_DIR="/var/lib/waydroid"
WAYDROID_DATA="${HOME}/.local/share/waydroid/data"
PIF_URL="https://github.com/chiteroman/PlayIntegrityFix/releases/latest/download/PlayIntegrityFix.zip"

log() { echo -e "\033[1;32m[*]\033[0m $*"; }
err() { echo -e "\033[1;31m[!]\033[0m $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || err "Run as root"
[[ -n "$ASSETS" ]] || err "ASSETS not set"

img_dir() { 
  grep -Po 'images_path\s*=\s*\K.*' "$WAYDROID_DIR/waydroid.cfg" 2>/dev/null || echo "$WAYDROID_DIR/images"
}

overlayfs() { 
  grep -q 'mount_overlays\s*=\s*True' "$WAYDROID_DIR/waydroid.cfg" 2>/dev/null
}

prop() { 
  sed -i "/^\[properties\]/a $1 = $2" "$WAYDROID_DIR/waydroid.cfg"
}

log "=== Waydroid Setup ==="
waydroid container stop 2>/dev/null || true

if overlayfs; then
  COPY_DIR="/var/lib/waydroid/overlay"
else
  COPY_DIR="/tmp/waydroid"
  img=$(img_dir)
  
  for p in system vendor; do
    img_path="$img/$p.img"
    mp="$COPY_DIR"
    [[ "$p" != "system" ]] && mp="$COPY_DIR/$p"
    
    log "Mounting $p..."
    e2fsck -yf "$img_path" >/dev/null 2>&1 || true
    resize2fs "$img_path" "$(($(stat -c%s "$img_path")/1024/1024+500))M" >/dev/null 2>&1
    mkdir -p "$mp"
    mountpoint -q "$mp" && umount "$mp"
    mount -o rw "$img_path" "$mp"
  done
fi

log "Installing Houdini..."
cp -r "$ASSETS/system/"* "$COPY_DIR/system/"
prop "ro.dalvik.vm.native.bridge" "libhoudini.so"
prop "ro.enable.native.bridge.exec" "1"

log "Installing Widevine..."
cp -r "$ASSETS/vendor/"* "$COPY_DIR/vendor/"

log "Installing Magisk..."
mgsk="$COPY_DIR/system/etc/init/magisk"
mkdir -p "$mgsk"
for lib in "$ASSETS/magisk/lib/x86_64/"*.so; do
  cp "$lib" "$mgsk/$(basename "$lib" | sed 's/^lib//;s/\.so$//')"
done
chmod 755 "$mgsk/"*
cp "$ASSETS/magisk/magisk.apk" "$mgsk/"
cp -r "$ASSETS/magisk/assets/chromeos" "$mgsk/" 2>/dev/null || true
cp "$ASSETS/magisk/bootanim.rc" "$COPY_DIR/system/etc/init/bootanim.rc"

mkdir -p "$WAYDROID_DATA/adb/magisk"
cp -r "$mgsk/"* "$WAYDROID_DATA/adb/magisk/"

log "Downloading PlayIntegrityFix..."
mkdir -p "$WAYDROID_DATA/local/tmp"
curl -sL "$PIF_URL" -o "$WAYDROID_DATA/local/tmp/PlayIntegrityFix.zip" || log "PIF download failed (optional)"

if ! overlayfs; then
  log "Unmounting..."
  for p in vendor system; do
    mp="$COPY_DIR"
    [[ "$p" != "system" ]] && mp="$COPY_DIR/$p"
    umount "$mp" 2>/dev/null || true
  done
fi

log "Starting Waydroid..."
waydroid upgrade -o 2>/dev/null || true
waydroid session start &
sleep 12

log "Configuring Magisk..."
for c in "magisk --zygisk on" "magisk --denylist enable" "magisk --denylist add com.google.android.gms" "magisk --denylist add com.android.vending"; do
  waydroid shell su -c "$c" 2>/dev/null || true
done
waydroid shell su -c "magisk --install-module /data/local/tmp/PlayIntegrityFix.zip" 2>/dev/null || true

log "Done! Register: https://www.google.com/android/uncertified/"
