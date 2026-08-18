#!/usr/bin/env bash
set -euo pipefail

pkill polybar || true

while pgrep -x polybar > /dev/null; do sleep 0.1; done

polybar axyl 2>&1 | tee -a /tmp/polybar.log &
