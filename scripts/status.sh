#!/usr/bin/env bash
# Check Waydroid and Magisk status
set -euo pipefail

echo "=== Waydroid Status ==="
waydroid status 2>/dev/null || echo "Waydroid not running"

echo ""
echo "=== Magisk Version ==="
waydroid shell su -c "magisk -v" 2>/dev/null || echo "Magisk not installed or container not running"

echo ""
echo "=== Zygisk Status ==="
waydroid shell su -c "magisk --zygisk status" 2>/dev/null || echo "Unknown"

echo ""
echo "=== DenyList ==="
waydroid shell su -c "magisk --denylist ls" 2>/dev/null | head -10 || echo "Unknown"
