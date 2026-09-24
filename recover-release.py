"""Recover the owner's published static release through its normal asset URLs.

The access token is supplied over stdin, never stored or forwarded on redirects.
The output manifest distinguishes byte-for-byte recovery from later edits.
"""
import concurrent.futures
import hashlib
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DIST = ROOT / 'dist'
DIST.mkdir(exist_ok=True)
config = json.loads(sys.stdin.readline())
origin = config['origin'].rstrip('/')
token = config['token']

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlsplit(newurl).netloc != urllib.parse.urlsplit(origin).netloc:
            return None
        return super().redirect_request(req, fp, code, msg, headers, newurl)

def download(name):
    endpoint = '/' if name == 'index.html' else '/' + name
    request = urllib.request.Request(origin + endpoint, headers={
        'OAI-Sites-Authorization': 'Bearer ' + token,
    })
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=90) as response:
            data = response.read()
        target = DIST / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        return name, data, None
    except urllib.error.HTTPError as error:
        return name, None, error.code

pending = {'index.html','style.css','ui.js','engine-manifest.js','engine-loader.js',
           'game.js','audio-engine.js','cinematic.js','game.audio.worklet.js',
           'game.audio.position.worklet.js','media/audio/manifest.json',
           'art-review/index.html','art-review/approval/index.html','art-review/revision/index.html'}
records, failures = {}, {}
previous_path=ROOT/'release-recovery.json'
if previous_path.exists():
    previous=json.loads(previous_path.read_text())
    records=previous['assets']
    failures={k:v for k,v in previous['unavailable_optional_paths'].items() if v not in (301,302,307,308)}
    pending.update(k for k,v in previous['unavailable_optional_paths'].items() if v in (301,302,307,308) and not k.startswith('cdn-cgi/'))
old_dist = Path('/workspace/sites/dirty-room/dist')
for path in old_dist.rglob('*'):
    name = str(path.relative_to(old_dist))
    if path.is_file() and not name.startswith('media/story/') and name not in {
        'story.js','viewport.js','game.pck','game.wasm.gz',
    } and not re.search(r'\.part\d+$',name):
        pending.add(name)

def resolve(base, value):
    url = urllib.parse.urljoin(origin + '/' + base, value)
    parsed = urllib.parse.urlsplit(url)
    if parsed.netloc != urllib.parse.urlsplit(origin).netloc:
        return None
    path = urllib.parse.unquote(parsed.path).lstrip('/')
    if not path or path.startswith('cdn-cgi/') or '..' in Path(path).parts:
        return None
    if path.endswith('/'):
        if path.startswith('art-review/'): path += 'index.html'
        else: return None
    if not re.search(r'\.(?:html|css|js|png|jpe?g|webp|svg|mp3|wav|ogg|mp4|json|gz|part\d+)$',path):
        return None
    return path

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    while pending:
        batch = sorted(pending - records.keys() - failures.keys())
        pending.clear()
        for name,data,error in pool.map(download,batch):
            if error:
                failures[name]=error
                continue
            records[name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
            if name.endswith(('.html','.css','.js','.json')):
                text=data.decode('utf-8')
                for value in re.findall(r'''(?:src|href)=["']([^"']+)["']|url\(["']?([^)'"\s]+)|["']((?:\.?\.?/)?(?:media|art-review)/[^"'\s]+)["']''',text):
                    target=resolve(name,next(x for x in value if x))
                    if target:pending.add(target)
                if name=='engine-manifest.js':
                    manifest=json.loads(text.split('=',1)[1].strip().rstrip(';'))
                    (ROOT/'release-engine-manifest.json').write_text(json.dumps(manifest,indent=2))
                    for key,value in manifest.items():
                        if isinstance(value,list):
                            pending.update(x for x in value if isinstance(x,str))
                    if manifest.get('gzipBytes'):pending.add('game.wasm.gz')
                elif name=='media/audio/manifest.json':
                    pending.update('media/audio/'+x for x in json.loads(text)['files'])
            print(json.dumps({'asset':name,'bytes':len(data)}),flush=True)

required=['index.html','ui.js','game.js','engine-manifest.js','engine-loader.js','style.css']
missing=[name for name in required if name not in records]
(ROOT/'release-recovery.json').write_text(json.dumps({
    'origin':origin,'source_version':7,
    'source_commit':'407cf4af6c788a99443ea1f85781a89de0f3aebc',
    'assets':records,'unavailable_optional_paths':failures,'missing_required':missing,
},indent=2))
print(json.dumps({'recovered_files':len(records),'bytes':sum(x['bytes'] for x in records.values()),'missing_required':missing,'optional_unavailable':failures}),flush=True)
if missing:raise SystemExit(1)
