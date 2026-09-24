"""Assert a script-only update preserves every other packed v7 resource."""
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

tool, original, patched = sys.argv[1:4]
def unpack(pack, directory):
    result = subprocess.run([tool, '--headless', '--extract='+pack,
                             '--output='+str(directory)], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout[-4000:] + result.stderr[-4000:])
    return {str(p.relative_to(directory)):hashlib.sha256(p.read_bytes()).hexdigest()
            for p in directory.rglob('*') if p.is_file() and p.name!='gdre_export.log'}

with tempfile.TemporaryDirectory(prefix='cockroach-pack-audit-') as temporary:
    root = Path(temporary)
    before=unpack(original,root/'before')
    after=unpack(patched,root/'after')
    assert before.keys()==after.keys(), 'Packed file list changed'
    changed=sorted(name for name in before if before[name]!=after[name])
    assert changed==['anatomy.gdc','main.gdc'], changed
    result={'result':'PASS','packed_files':len(before),'changed':changed,
            'unchanged_files':len(before)-len(changed),
            'preserved':{name:digest for name,digest in before.items() if name not in changed}}
    Path('build/reports').mkdir(parents=True, exist_ok=True)
    Path('build/reports/art-preservation.json').write_text(json.dumps(result,indent=2))
    print(json.dumps({k:v for k,v in result.items() if k!='preserved'}))
