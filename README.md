# nix-waydroid-setup

Waydroid setup for NixOS with Magisk, ARM translation, and Play Integrity patches.

## Features

- **Magisk Delta** - Root with MagiskHide
- **Libhoudini** - ARM translation for x86_64
- **Widevine** - DRM for streaming (L3)
- **PlayIntegrityFork** - Pass Play Integrity attestation
- **Pre-configured** - Clipboard, multi-window, fake WiFi

## Quick Start

```bash
# Complete setup in one command
just setup

# Or step by step:
just wipe         # Clean slate
just init-fast    # Download images
just install      # Patch with Magisk/Houdini/Widevine
just restart      # Start session
just activate     # Configure MagiskHide + PIF
```

## Commands

### Setup & Management
| Command | Description |
|---------|-------------|
| `just setup` | Complete automated setup |
| `just wipe` | Remove all Waydroid data |
| `just install` | Patch images with Magisk/Houdini/Widevine |
| `just activate` | Configure MagiskHide + install PIF |

### Daily Usage
| Command | Description |
|---------|-------------|
| `just show` | Launch Waydroid UI |
| `just restart` | Restart session |
| `just stop` | Stop completely |
| `just shell` | Enter Android shell |
| `just log` | View live logs |

### Utilities
| Command | Description |
|---------|-------------|
| `just status` | Check Waydroid/Magisk status |
| `just get-id` | Get Android ID for registration |
| `just clear-gms` | Clear Play Store data |
| `just install-apps` | Install F-Droid, Aurora Store, YASNAC |

## NixOS Module

```nix
# flake.nix
inputs.nix-waydroid-setup.url = "github:kleinbem/nix-waydroid-setup";

# configuration.nix
imports = [ inputs.nix-waydroid-setup.nixosModules.default ];
programs.waydroid-setup.enable = true;
```

This handles kernel parameters, modules, and networking automatically.

## Post-Install

1. Run `just status` to verify Magisk and PIF are working
2. Open YASNAC to check Play Integrity (install with `just install-apps`)
3. If not certified: `just get-id` → register at https://www.google.com/android/uncertified/
4. Wait 10-30 minutes, then `just clear-gms && just restart`

## License

MIT © Martin Kleinberger
