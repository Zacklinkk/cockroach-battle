"""Restore editable runtime assets without overwriting current gameplay scripts.

Usage: python scripts/restore-editor-assets.py /absolute/path/to/gdre_tools
The original compressed runtime textures remain in dist's tracked PCK chunks.
Converted editor assets and imported caches are reproducible, ignored outputs.
"""
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'dist/engine-manifest.js').read_text().split('=',1)[1].strip().rstrip(';'))
with tempfile.TemporaryDirectory(prefix='cockroach-editor-') as temp:
    temp=Path(temp)
    data=b''.join((root/'dist'/name).read_bytes() for name in manifest['packParts'])
    assert len(data)==manifest['packBytes']
    assert hashlib.sha256(data).hexdigest()==manifest['packSha256']
    pack=temp/'game.pck';pack.write_bytes(data)
    output=temp/'recovered'
    subprocess.run([sys.argv[1],'--headless','--recover='+str(pack),'--output='+str(output)],check=True)
    for name in ['assets','.godot']:
        shutil.copytree(output/name,root/'godot'/name,dirs_exist_ok=True)
    print('Editor assets restored; current gameplay source scripts preserved.')
