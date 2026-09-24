"""Update gameplay bytecode while retaining all packed runtime art.

Usage: python scripts/rebuild-pack.py /absolute/path/to/gdre_tools.x86_64
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

root=Path(__file__).resolve().parents[1]
dist=root/'dist';build=root/'build';build.mkdir(exist_ok=True)
manifest=json.loads((dist/'engine-manifest.js').read_text().split('=',1)[1].strip().rstrip(';'))
original=b''.join((dist/name).read_bytes() for name in manifest['packParts'])
assert len(original)==manifest['packBytes'] and hashlib.sha256(original).hexdigest()==manifest['packSha256']
base=build/'base.pck';base.write_bytes(original)
compiled=build/'compiled';compiled.mkdir(exist_ok=True)
def run(args):
    result=subprocess.run([sys.argv[1],'--headless',*args],capture_output=True,text=True)
    if result.returncode:raise RuntimeError(result.stdout[-4000:]+result.stderr[-4000:])
scripts=['main','balance','anatomy']
run(['--compile='+str(root/'godot'/f'{name}.gd') for name in scripts]+[
     '--bytecode=ebc36a7','--output='+str(compiled)])
output=build/'game.pck'
run(['--pck-patch='+str(base)]+[
    '--patch-file='+str(compiled/f'{name}.gdc')+f'=res://{name}.gdc' for name in scripts
]+['--output='+str(output)])
data=output.read_bytes()
manifest['packBytes']=len(data)
manifest['packSha256']=hashlib.sha256(data).hexdigest()
manifest['revision']=manifest['wasmSha256'][:8]+'-'+manifest['packSha256'][:8]
manifest['packParts']=[]
for index,start in enumerate(range(0,len(data),manifest['partBytes'])):
    name='game.pck.part'+str(index);manifest['packParts'].append(name)
    (dist/name).write_bytes(data[start:start+manifest['partBytes']])
(dist/'engine-manifest.js').write_text('window.engineManifest='+json.dumps(manifest,separators=(',',':'))+';\n')
print(json.dumps({'packBytes':len(data),'packSha256':manifest['packSha256']}))
