"""Stage and serve real-browser OGV acceptance against an existing Web build.

The supplied OGV is copied byte-for-byte; it is not transcoded or committed.
Use a 52-second or longer multiplexed Theora/Vorbis fixture (such as sintel.ogv).
"""
import argparse
import base64
import hashlib
import json
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import shutil
import subprocess
from urllib.parse import urlsplit

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('engine', type=Path, help='Dora-SSR checkout')
parser.add_argument('original', type=Path)
parser.add_argument('output', type=Path, help='disposable staging/results directory')
parser.add_argument('--engine-files', type=Path, help='defaults to engine/build/web')
parser.add_argument('--port', type=int, default=8880)
parser.add_argument('--isolate', action='store_true', help='enable COOP/COEP for pthread builds')
parser.add_argument('--stage-only', action='store_true')
args = parser.parse_args()
tests = Path(__file__).resolve().parent
engine, original, output = args.engine.resolve(), args.original.resolve(), args.output.resolve()
engine_files = args.engine_files.resolve() if args.engine_files else engine / 'build/web'
output.mkdir(parents=True, exist_ok=True)
metadata = json.loads(subprocess.check_output([
    'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
    'stream=duration,width,height', '-of', 'json', str(original)]))
duration = float(metadata['streams'][0]['duration'])
assert duration >= 52, 'full-duration checkpoints require a fixture at least 52 seconds long'
(output / 'fixture.json').write_text(json.dumps({
    'original': str(original), 'duration': duration,
    'sha256': hashlib.sha256(original.read_bytes()).hexdigest()}, indent=2) + '\n')
for name in ['controls', 'continuous', 'lovefull']:
    stage = output / 'source' / name
    stage.mkdir(parents=True, exist_ok=True)
    prefix = "local D=require('Dora');local out=D.Content.writablePath..'/ogv-controls';assert(D.Content:mkdir(out));local p=out..'/result.json';if D.Content:exist(p) then D.Content:remove(p) end;"
    if name != 'lovefull':
        shutil.copyfile(tests / ('NativeVideoControls.lua' if name == 'controls' else 'WebOgvContinuous.lua'), stage / 'test.lua')
        shutil.copyfile(original, stage / 'sample.ogv')
        code = prefix + "dofile('/game/test.lua')('/game/sample.ogv',out)\n"
    else:
        love = stage / 'love'
        love.mkdir(exist_ok=True)
        for filename in ['main.lua', 'encode.lua']:
            shutil.copyfile(tests / 'WebLoveOgv' / filename, love / filename)
        shutil.copyfile(original, love / 'sample.ogv')
        (love / 'settings.lua').write_text(f'return {{duration={duration}}}\n')
        width, height = metadata['streams'][0]['width'], metadata['streams'][0]['height']
        (love / 'conf.lua').write_text(f"function love.conf(t)t.identity='ogv-web-lovefull';t.window.width={width};t.window.height={height} end\n")
        code = "local D=require('Dora');local p=D.Content.writablePath..'/Love/ogv-web-lovefull/result.json';if D.Content:exist(p) then D.Content:remove(p) end;D.Director.entry:addChild(assert(D.LoveNode('/game/love/main.lua')))\n"
    code = ("local D=require('Dora');local start=D.Content.writablePath..'/ogv-start';"
            "if D.Content:exist(start) then D.Content:remove(start) end;"
            "print('OGV_TEST_READY');"
            "D.thread(function()while not D.Content:exist(start) do D.sleep() end;" + code + "end)\n")
    (stage / 'init.lua').write_text(code)
    subprocess.run(['node', str(engine / 'Projects/xmake/tools/web/package_web_game.mjs'),
                    str(stage), str(output / 'cases' / name), 'init.lua'], check=True)
(output / 'index.html').write_text((tests / 'web_ogv_harness.html').read_text())
if args.stage_only:
    raise SystemExit()

class Handler(SimpleHTTPRequestHandler):
    def translate_path(self, url):
        route = urlsplit(url).path
        base = engine_files if route.startswith('/engine/') else output
        relative = route[len('/engine/'):] if route.startswith('/engine/') else route.lstrip('/') or 'index.html'
        target = (base / relative).resolve()
        if not target.is_relative_to(base):
            return str(output / 'missing')
        return str(target)

    def end_headers(self):
        if args.isolate:
            self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
            self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def do_POST(self):
        name = urlsplit(self.path).path.removeprefix('/result/')
        if name not in ['controls', 'continuous', 'lovefull']:
            self.send_error(404)
            return
        data = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        dest = output / 'results' / name
        dest.mkdir(parents=True, exist_ok=True)
        if 'file' in data:
            assert Path(data['file']).name == data['file'] and data['file'].endswith('.png')
            (dest / data['file']).write_bytes(base64.b64decode(data['base64']))
        else:
            (dest / 'result.json').write_text(json.dumps(data['result'], indent=2) + '\n')
            (dest / 'browser.json').write_text(json.dumps(data['browser'], indent=2) + '\n')
        self.send_response(200)
        self.end_headers()

print(f'OGV acceptance: http://127.0.0.1:{args.port}/ (isolation={args.isolate})', flush=True)
ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
