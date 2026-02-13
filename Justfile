# Waydroid Setup for NixOS

default:
    @just --list

# Run the installer (requires sudo)
install:
    sudo nix run .

# Initialize Waydroid (Fast parallel downloads to preinstalled path - skips waydroid init download!)
# Images go to /etc/waydroid-extra/images/ which waydroid checks BEFORE downloading!
init-fast:
    nix shell nixpkgs#aria2 nixpkgs#unzip -c bash -c " \
        set -e; \
        IMAGES_DIR='/etc/waydroid-extra/images'; \
        sudo mkdir -p \$IMAGES_DIR; \
        echo '[*] Downloading GAPPS images to preinstalled path...'; \
        echo '[*] (waydroid init will use these without re-downloading)'; \
        sudo aria2c -c -x 16 -s 16 -d \$IMAGES_DIR -o system.zip 'https://downloads.sourceforge.net/project/waydroid/images/system/lineage/waydroid_x86_64/lineage-20.0-20250809-GAPPS-waydroid_x86_64-system.zip'; \
        sudo aria2c -c -x 16 -s 16 -d \$IMAGES_DIR -o vendor.zip 'https://downloads.sourceforge.net/project/waydroid/images/vendor/waydroid_x86_64/lineage-20.0-20250809-MAINLINE-waydroid_x86_64-vendor.zip'; \
        echo '[*] Extracting images...'; \
        sudo unzip -o \$IMAGES_DIR/system.zip system.img -d \$IMAGES_DIR/; \
        sudo unzip -o \$IMAGES_DIR/vendor.zip vendor.img -d \$IMAGES_DIR/; \
        sudo rm -f \$IMAGES_DIR/system.zip \$IMAGES_DIR/vendor.zip; \
        echo '[*] ✅ GAPPS images installed to preinstalled path!'"

# Alias for the manual download method
init-aria: init-fast

# Run the post-install activation (Zygisk, Magisk config, PIF)
activate:
    nix run .#activate

# Update PlayIntegrityFix module
update-pif:
    nix run .#update-pif

# Update hashes in sources.nix (Expert)
update-hashes:
    nix run .#update-hashes

# Initialize Waydroid configuration (generates waydroid_base.prop and LXC config)
# Because images are in /etc/waydroid-extra/images/ (a preinstalled_images_path),
# waydroid init will SKIP downloading and use them directly!
fix-config:
    #!/usr/bin/env bash
    set -e
    
    echo "[*] Running waydroid init..."
    echo "[*] (Images are in preinstalled path - NO DOWNLOAD will happen)"
    
    # waydroid init finds images in /etc/waydroid-extra/images/ and uses them
    # The -s GAPPS flag is for the config file, but no download occurs!
    sudo waydroid init -s GAPPS
    
    # Ensure our Houdini properties are set
    if [ -f /var/lib/waydroid/waydroid.cfg ]; then
        # Add Houdini properties if not present
        if ! grep -q "ro.dalvik.vm.native.bridge" /var/lib/waydroid/waydroid.cfg; then
            sudo sed -i '/\[properties\]/a ro.dalvik.vm.native.bridge = libhoudini.so' /var/lib/waydroid/waydroid.cfg
        fi
        if ! grep -q "ro.enable.native.bridge.exec" /var/lib/waydroid/waydroid.cfg; then  
            sudo sed -i '/\[properties\]/a ro.enable.native.bridge.exec = 1' /var/lib/waydroid/waydroid.cfg
        fi
        # Ensure [properties] section exists
        if ! grep -q "\[properties\]" /var/lib/waydroid/waydroid.cfg; then
            echo -e "\n[properties]\nro.dalvik.vm.native.bridge = libhoudini.so\nro.enable.native.bridge.exec = 1" | sudo tee -a /var/lib/waydroid/waydroid.cfg > /dev/null
        fi
    fi
    
    echo "[*] ✅ Config initialized successfully!"

# Get Android ID for device registration
get-id:
    nix run .#get-id

# Clear Play Store & GMS data (after device registration)
clear-gms:
    sudo waydroid shell -- sh -c "pm clear com.android.vending && pm clear com.google.android.gms"
    echo "[*] Play Store and GMS data cleared. Restart Waydroid now."

# Check detailed system status
status:
    nix run .#status

# Deep clean and relaunch Magisk Manager
fix-magisk:
    curl -sL "https://github.com/1q23lyc45/KitsuneMagisk/releases/download/v27.2-kitsune-4/app-release.apk" -o /tmp/magisk-fix.apk
    sudo cp /tmp/magisk-fix.apk ~/.local/share/waydroid/data/local/tmp/magisk.apk
    sudo waydroid shell -- pm install -r -t /data/local/tmp/magisk.apk
    sudo waydroid shell -- pm clear io.github.huskydg.magisk
    sudo waydroid shell -- am start -n io.github.huskydg.magisk/com.topjohnwu.magisk.MainActivity
    rm /tmp/magisk-fix.apk
    echo "[*] Magisk reinstalled and relaunched."

# Quick health check (OK/NOK)
check:
    nix run .#check

# Force Magisk to hide from Google Play Services
fix-integrity:
    echo "[*] Adding Google services to MagiskHide..."
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "magiskhide add com.google.android.gms"
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "magiskhide add com.android.vending"
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "magiskhide add com.google.android.gsf"
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "magiskhide add com.henrikherzig.playintegritychecker"
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "magiskhide enable"
    echo "[*] Done! Now clearing GMS cache..."
    just clear-gms
    echo "[*] Configuration applied. Follow with 'just restart' then 'just activate'."

# Hard reset the Magisk daemon (fixes "Daemon error")
fix-daemon:
    echo "[*] Killing stuck Magisk processes..."
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "pkill -f magisk" || true
    sleep 2
    echo "[*] Restarting Magisk Delta daemon..."
    sudo waydroid shell -- sh -c "/dev/magisk_waydroid/magisk --auto-selinux --daemon"
    sleep 3
    echo "[*] Initializing Hide engine..."
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "/dev/magisk_waydroid/magisk --post-fs-data"
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "magiskhide enable"
    echo "[*] Daemon should be healthy now. Run 'just status' to verify."

# Force a fingerprint update for Play Integrity Fix (includes 60s wait)
refresh-pif:
    echo "[*] Triggering Play Integrity Fix update..."
    # Try all known script names for various PIF forks
    sudo waydroid shell -- /dev/magisk_waydroid/su -c " \
        [ -f /data/adb/modules/playintegrityfix/check.sh ] && sh /data/adb/modules/playintegrityfix/check.sh; \
        [ -f /data/adb/modules/playintegrityfix/update.sh ] && sh /data/adb/modules/playintegrityfix/update.sh; \
        [ -f /data/adb/modules/playintegrityfix/migrate.sh ] && sh /data/adb/modules/playintegrityfix/migrate.sh; \
        true"
    echo "[*] Fingerprint update triggered. Waiting 60s for background download..."
    @for i in {60..1}; do echo -ne "\r[*] Remaining: ${i}s "; sleep 1; done; echo -e "\r[*] Wait complete.             "
    echo "[*] Resetting GMS memory..."
    just clear-gms
    echo "[*] Done. Please run 'just restart' then 'just activate'."

# List files in the Play Integrity module (Debug)
list-pif:
    echo "[*] Files in Play Integrity Fix module:"
    sudo waydroid shell -- ls -R /data/adb/modules/playintegrityfix
    echo "[*] Checking for config files..."
    sudo waydroid shell -- ls -l /data/adb/modules/playintegrityfix/*.json 2>/dev/null || echo "No .json config found."
    sudo waydroid shell -- ls -l /data/adb/modules/playintegrityfix/*.prop 2>/dev/null || echo "No .prop config found."

# Inject a working Nexus 5X fingerprint (The "Golden Ticket")
inject-pif:
    echo "[*] Creating Nexus 5X fingerprint..."
    sudo waydroid shell -- /dev/magisk_waydroid/su -c 'echo "{\"PRODUCT\":\"bullhead\",\"DEVICE\":\"bullhead\",\"MANUFACTURER\":\"LGE\",\"BRAND\":\"google\",\"MODEL\":\"Nexus 5X\",\"FINGERPRINT\":\"google/bullhead/bullhead:6.0/MDB08I/2354965:user/release-keys\",\"SECURITY_PATCH\":\"2015-11-01\",\"ID\":\"MDB08I\",\"TYPE\":\"user\",\"TAGS\":\"release-keys\"}" > /data/adb/modules/playintegrityfix/pif.json'
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "chmod 644 /data/adb/modules/playintegrityfix/pif.json"
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "chown root:root /data/adb/modules/playintegrityfix/pif.json"
    echo "[*] Fingerprint injected! Now clearing memory..."
    just clear-gms
    echo "[*] Done. Please run 'just restart' then 'just activate'."

# Install recommended apps (F-Droid, Aurora Store, utilities)
install-apps:
    #!/usr/bin/env bash
    set -e
    TMPDIR="/tmp/waydroid-apps"
    mkdir -p "$TMPDIR"

    install_app() {
        local name="$1"
        local url="$2"
        local file="$TMPDIR/$(basename "$url")"
        if [[ "$file" == *"?"* ]]; then file="${file%%\?*}"; fi
        if [[ "$file" != *".apk" ]]; then file="$file.apk"; fi
        
        # Color codes
        local GREEN='\033[0;32m'
        local RED='\033[0;31m'
        local NC='\033[0m' # No Color
        
        echo -n "[*] $name: "
        if curl -sL "$url" -o "$file"; then
            local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            if [ "$size" -gt 1000000 ]; then
                if waydroid app install "$file" 2>/dev/null; then
                    echo -e "${GREEN}OK${NC} (Installed)"
                else
                    echo -e "${RED}NOK${NC} (Install failed)"
                fi
            else
                echo -e "${RED}NOK${NC} (Download corrupted: $size bytes)"
            fi
        else
            echo -e "${RED}NOK${NC} (Download error)"
        fi
    }

    # Helper for GitHub releases (robust match)
    install_gh() {
        local name="$1"
        local repo="$2"
        local match="$3"
        echo "[*] Finding $name on GitHub..."
        
        # Try /releases/latest first
        local url=$(nix shell nixpkgs#curl nixpkgs#jq -c bash -c "curl -s 'https://api.github.com/repos/$repo/releases/latest' | jq -r --arg m \"$match\" '.assets[] | select(.name | contains(\$m)) | .browser_download_url' | head -n 1")
        
        # Fallback to the first release in the list if /latest is empty
        if [ "$url" == "null" ] || [ -z "$url" ]; then
            url=$(nix shell nixpkgs#curl nixpkgs#jq -c bash -c "curl -s 'https://api.github.com/repos/$repo/releases' | jq -r --arg m \"$match\" '.[0].assets[] | select(.name | contains(\$m)) | .browser_download_url' | head -n 1")
        fi
        
        # Final fallback: just get anything ending in .apk
        if [ "$url" == "null" ] || [ -z "$url" ]; then
            url=$(nix shell nixpkgs#curl nixpkgs#jq -c bash -c "curl -s 'https://api.github.com/repos/$repo/releases' | jq -r '.[0].assets[] | select(.name | endswith(\".apk\")) | .browser_download_url' | head -n 1")
        fi

        if [ "$url" != "null" ] && [ -n "$url" ]; then
            install_app "$name" "$url"
        else
            echo "    ⚠️ Could not find $name release on $repo"
        fi
    }

    echo "=========================================="
    echo "[*] Installing recommended apps for Waydroid"
    echo "=========================================="
    echo ""

    echo "--- App Stores ---"
    install_app "F-Droid" "https://f-droid.org/F-Droid.apk"
    # Using verified stable F-Droid link (Version 4.8.0)
    install_app "Aurora Store" "https://f-droid.org/repo/com.aurora.store_72.apk"
    echo ""

    echo "--- Security & Privacy ---"
    install_gh "Aegis (2FA)" "beemdevelopment/Aegis" ".apk"
    install_gh "Bitwarden" "bitwarden/mobile" ".apk"
    echo ""

    echo "--- Utilities ---"
    install_gh "SPIC (Integrity Check)" "herzhenr/SPIC-android" ".apk"
    install_gh "Material Files" "zhanghai/MaterialFiles" ".apk"
    echo ""

    echo "--- Media ---"
    install_gh "NewPipe" "TeamNewPipe/NewPipe" ".apk"
    install_app "VLC" "https://get.videolan.org/vlc-android/3.5.4/VLC-Android-3.5.4-x86_64.apk"
    echo ""

    echo "--- Lifestyle ---"
    install_gh "Catima" "CatimaLoyalty/Android" ".apk"
    echo ""

    echo "--- Desktop Experience ---"
    # Using verified stable F-Droid link (Version 1.14.2)
    install_app "Smart Dock" "https://f-droid.org/repo/cu.axel.smartdock_1142.apk"
    echo ""

    rm -rf "$TMPDIR"

    echo "=========================================="
    echo "[*] ✅ App installation complete!"
    echo "=========================================="
    echo ""
    echo "Apps installed:"
    echo "  📦 F-Droid         - Open source app store"
    echo "  📦 Aurora Store    - Anonymous Play Store client"
    echo "  🔐 Aegis           - 2FA authenticator"
    echo "  🔐 Bitwarden       - Password manager"
    echo "  🔍 SPIC            - Play Integrity checker"
    echo "  📁 Material Files  - File manager"
    echo "  📺 NewPipe         - YouTube (no ads, background play)"
    echo "  🎬 VLC             - Media player"
    echo "  💳 Catima          - Loyalty cards wallet"
    echo "  🖥️  Smart Dock      - Desktop taskbar (multi-window)"

# Uninstall patches
uninstall:
    nix run .#uninstall

# Completely wipe Waydroid (for fresh install)
wipe:
    #!/usr/bin/env bash
    echo "[!] This will COMPLETELY REMOVE Waydroid data!"
    echo "    - /var/lib/waydroid (system)"
    echo "    - /etc/waydroid-extra/images (preinstalled images)"
    echo "    - ~/.local/share/waydroid (user data)"
    echo "    - ~/.cache/waydroid (cache)"
    echo "    - ~/.waydroid-cache (download cache)"
    echo "    - /tmp/waydroid* (temp files)"
    read -p "Are you sure? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        waydroid session stop 2>/dev/null || true
        sudo systemctl stop waydroid-container.service 2>/dev/null || true
        sudo rm -rf /var/lib/waydroid 2>/dev/null || true
        sudo rm -rf /etc/waydroid-extra/images 2>/dev/null || true
        sudo rm -rf ~/.local/share/waydroid 2>/dev/null || true
        rm -rf ~/.cache/waydroid 2>/dev/null || true
        rm -rf ~/.waydroid-cache 2>/dev/null || true
        sudo rm -rf /tmp/waydroid* 2>/dev/null || true
        echo "[*] Waydroid completely wiped. Run 'just setup' to reinstall."
    else
        echo "[*] Aborted."
    fi

# Fix common permission issues with data/data directories
fix-data-perms:
    waydroid shell "find /data/data -maxdepth 1 -type d -exec chmod 755 {} +"
    echo "[*] Data permissions fixed."

# Restart Waydroid session
restart:
    -just unfreeze
    -waydroid session stop
    waydroid session start

# Unfreeze the Waydroid container
unfreeze:
    sudo waydroid container unfreeze || true
    echo "[*] Container unfrozen."



# Launch the Waydroid UI
show:
    waydroid show-full-ui

# View Waydroid logs (live)
log:
    waydroid log

# Enter Android shell
shell:
    sudo waydroid shell

# Stop Waydroid completely
stop:
    -just unfreeze
    -waydroid session stop
    sudo systemctl stop waydroid-container.service 2>/dev/null || true
    echo "[*] Waydroid stopped."

# Full setup workflow (wipe → download → init → patch → start → activate)
setup:
    #!/usr/bin/env bash
    set -e
    
    # Early sudo validation so user can leave it running
    sudo -v
    # Keep sudo alive in the background during the setup phase
    (while true; do sudo -n true; sleep 60; done) &
    SUDO_ALIVE_PID=$!
    trap 'kill $SUDO_ALIVE_PID 2>/dev/null || true' EXIT
    
    echo "=========================================="
    echo "[*] WAYDROID COMPLETE SETUP"
    echo "=========================================="
    echo ""
    
    echo "[1/5] Downloading and extracting images..."
    echo "----------------------------------------"
    just init-fast
    echo ""
    
    echo "[2/5] Creating Waydroid configuration..."
    echo "----------------------------------------"
    # DON'T run 'waydroid init' at all - it ALWAYS downloads VANILLA images!
    # Create directories manually
    sudo mkdir -p /var/lib/waydroid/overlay/system/etc/init
    sudo mkdir -p /var/lib/waydroid/overlay/vendor
    sudo mkdir -p /var/lib/waydroid/overlay_rw/system
    sudo mkdir -p /var/lib/waydroid/overlay_rw/vendor
    sudo mkdir -p /var/lib/waydroid/overlay_work/system
    sudo mkdir -p /var/lib/waydroid/overlay_work/vendor
    sudo mkdir -p /var/lib/waydroid/rootfs
    # Create config files manually (bypasses waydroid init entirely)
    just fix-config
    echo ""

    echo "[3/5] Patching images with Magisk, Houdini, Widevine..."
    echo "----------------------------------------"
    just install
    echo ""
    
    echo "[4/5] Starting Waydroid session..."
    echo "----------------------------------------"
    # Start session in background
    waydroid session start &
    
    # Wait for session to be ready
    echo "[*] Waiting for Android to boot..."
    for i in {1..24}; do
        sleep 5
        if waydroid status 2>/dev/null | grep -q "Session:.*RUNNING"; then
            echo "[*] ✓ Session is running!"
            break
        fi
        if [ $i -eq 24 ]; then
            echo "[!] Timeout waiting for session. Try 'waydroid session start' manually."
            exit 1
        fi
        echo "[*] Still booting... ($((i*5))s)"
    done
    
    echo "[*] Giving Android 20s to finish initialization..."
    sleep 20
    echo ""
    
    echo "[5/5] Configuring MagiskHide and Play Integrity Fix..."
    echo "----------------------------------------"
    just activate
    echo ""
    
    echo "=========================================="
    echo "[*] ✅ SETUP COMPLETE!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. just show           - Launch Waydroid UI"
    echo "  2. just install-apps   - Install app collection"
    echo "  3. just status         - Check Magisk status"
    echo "  4. just get-id         - Get Android ID for Play certification"
    echo "  5. just hide-ui        - Hide Android status/nav bars (clean look)"

# Hide Android status and navigation bars (Immersive mode)
hide-ui:
    waydroid shell settings put global policy_control immersive.full=*
    echo "[*] UI hidden. Use 'just show-ui' to restore."

# Restore Android status and navigation bars
show-ui:
    waydroid shell settings put global policy_control null*
    echo "[*] UI restored."

# Standard Desktop Mode (Mouse works like a mouse)
desktop-mode:
    waydroid prop set persist.waydroid.cursor_on_subsurface true
    waydroid prop set persist.waydroid.fake_touch ""
    waydroid prop set persist.waydroid.multi_windows true
    @echo "[*] Desktop mode enabled (Mouse = Mouse). Run 'just restart' to apply."

# Tablet Mode (Mouse works like a finger)
tablet-mode:
    waydroid prop set persist.waydroid.cursor_on_subsurface false
    waydroid prop set persist.waydroid.fake_touch "on"
    waydroid prop set persist.waydroid.multi_windows false
    @echo "[*] Tablet mode enabled (Mouse = Touch). Run 'just restart' to apply."

# Toggle between Mouse and Touch input (No restart needed for some apps, but recommended)
toggle-touch:
    #!/usr/bin/env bash
    CURRENT=$(waydroid prop get persist.waydroid.fake_touch)
    if [ "$CURRENT" == "on" ]; then
        waydroid prop set persist.waydroid.fake_touch ""
        echo "[*] Input set to MOUSE. Run 'just restart' if UI feels off."
    else
        waydroid prop set persist.waydroid.fake_touch "on"
        echo "[*] Input set to TOUCH. Run 'just restart' if UI feels off."
    fi


# Enter development shell
dev:
    nix develop

# Lint shell scripts
lint:
    nix develop -c shellcheck scripts/*.sh

# Build assets
build:
    nix build .#assets

# Update flake inputs
update:
    nix flake update

# Verify flake
verify:
    nix flake check
# Debug and force Zygisk (Agent helper command)
debug-zygisk:
    #!/usr/bin/env bash
    set -e
    log() { echo -e "\033[1;34m[*]\033[0m $*"; }
    
    log "--- System Environment ---"
    echo "Host NoNewPrivs: $(cat /proc/self/status | grep NoNewPrivs | awk '{print $2}')"
    
    log "--- Magisk Database State ---"
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "/dev/magisk_waydroid/magisk --sqlite \"SELECT * FROM settings;\"" || echo "Failed to read DB"
    
    log "--- Searching for Magisk Logs ---"
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "ls -l /data/adb/*.log" || echo "No logs in /data/adb/"
    
    log "--- Forcing Daemon Restart ---"
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "pkill -9 magiskd" || true
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "/dev/magisk_waydroid/magisk --auto-selinux --daemon"
    sleep 2
    
    log "--- Checking if Zygisk is loaded in processes ---"
    # Look for Zygisk in process maps (classic way to check if it's active)
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "grep -l \"zygisk\" /proc/*/maps 2>/dev/null | head -n 5" || echo "Zygisk NOT found in any process memory"
    
    log "--- Forcing Deep Zygote Restart ---"
    # This is the most aggressive way to force a reload
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "setprop ctl.restart zygote" || true
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "killall -9 zygote zygote64" || true
    
    log "--- Final Status ---"
    sleep 3
    sudo waydroid shell -- /dev/magisk_waydroid/su -c "/dev/magisk_waydroid/magisk -v" || echo "Magisk daemon not responding"
    echo "If you don't see :Z:H above, Zygisk is still failing to hook."
