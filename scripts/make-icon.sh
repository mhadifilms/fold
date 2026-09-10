#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
ICON_TMP="$(mktemp -d)"
trap 'rm -rf "$ICON_TMP"' EXIT
for size in 16 32 64 128 256 512 1024; do
  sips -z "$size" "$size" Resources/Logo.png --out "$ICON_TMP/$size.png" >/dev/null
done
python3 - "$ICON_TMP" <<'PY'
from pathlib import Path
import struct, sys
parts=[]
for tag,size in [('icp4',16),('icp5',32),('icp6',64),('ic07',128),('ic08',256),('ic09',512),('ic10',1024)]:
    png=(Path(sys.argv[1])/f'{size}.png').read_bytes()
    parts.append(tag.encode()+struct.pack('>I',len(png)+8)+png)
payload=b''.join(parts)
Path('Resources/AppIcon.icns').write_bytes(b'icns'+struct.pack('>I',len(payload)+8)+payload)
PY
