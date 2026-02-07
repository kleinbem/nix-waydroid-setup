# nix-waydroid-setup

Waydroid setup for NixOS. Single command to install Magisk, ARM translation, and Play Integrity patches.

## What it does

- **Libhoudini** - ARM translation for x86_64
- **Widevine** - DRM for streaming (L3)
- **Magisk Delta** - Root with Zygisk
- **PlayIntegrityFix** - Pass Device/Basic attestation

## Usage

### 1. NixOS Module Integration (Recommended)

Add this flake to your inputs and enable the module:

```nix
# flake.nix
inputs.nix-waydroid-setup.url = "github:kleinbem/nix-waydroid-setup";

# In your machine configuration
imports = [ inputs.nix-waydroid-setup.nixosModules.default ];
programs.waydroid-setup.enable = true;
```

This automatically handles:
- Kernel parameters (`psi=1`) and modules (`uhid`, `binder_linux`).
- Reliable networking (pre-creates `waydroid0` bridge).
- Installs the setup tool and helpers.

### 2. Manual Run

If you don't want the module, just run it:

```bash
# Initialize Waydroid first
waydroid init -s GAPPS -f

# Run the installer
sudo nix run github:kleinbem/nix-waydroid-setup
```

## Helper Apps

| Command | Description |
|---------|-------------|
| `waydroid-setup` | Main installer (Magisk, Houdini, etc) |
| `waydroid-get-id`| Get Android ID for Google registration |
| `waydroid-status`| Check Waydroid/Magisk status |
| `waydroid-update-pif`| Update PlayIntegrityFix to latest version |
| `waydroid-restart`| Restart container and session |
| `waydroid-uninstall`| Remove all patches and restore clean state |

## Post-install

1. Open Magisk app → verify Zygisk is enabled.
2. Run `waydroid-get-id` and register at https://www.google.com/android/uncertified/
3. Wait ~20 minutes for Google to sync.

## License

MIT © Martin Kleinberger
