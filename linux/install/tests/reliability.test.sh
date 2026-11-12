#!/usr/bin/bash
set -Eeuo pipefail
python3 "$(dirname "${BASH_SOURCE[0]}")/reliability.py"
