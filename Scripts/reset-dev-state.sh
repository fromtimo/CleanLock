#!/bin/zsh
set -euo pipefail

/usr/bin/pkill CleanLock 2>/dev/null || true
/usr/bin/defaults delete dev.cleanlock.CleanLock 2>/dev/null || true
/usr/bin/tccutil reset Accessibility dev.cleanlock.CleanLock 2>/dev/null || true
/usr/bin/tccutil reset ListenEvent dev.cleanlock.CleanLock 2>/dev/null || true
/usr/bin/killall cfprefsd 2>/dev/null || true

echo "CleanLock dev state reset"
