import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, copyFile, writeFile, readFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';

test('Studio serves verified Godot assets with isolation headers and rejects corrupted packages', async () => {
  const engine = process.env.DORA_SSR_ROOT;
  assert.ok(engine, 'DORA_SSR_ROOT is required');
  const godotVersion = JSON.parse(await readFile(join(engine, 'Source/3rdParty/Godot/UPSTREAM.json'), 'utf8')).version;
  const dir = await mkdtemp(join(tmpdir(), 'studio-godot-serving-'));
  try {
    for (const name of ['runtime.go', 'godot.go']) await copyFile(new URL('../internal/studio/' + name, import.meta.url), join(dir, name));
    await writeFile(join(dir, 'go.mod'), 'module studio-godot-test\n\ngo 1.23\n');
    await writeFile(join(dir, 'godot_test.go'), `package studio
import("testing";"os";"path/filepath";"encoding/json";"crypto/sha256";"fmt";"net/http";"net/http/httptest";"strings")
func TestGodotRuntime(t *testing.T) {
 root:=t.TempDir()
 for _,name:=range runtimeFiles {
  b:=[]byte(name)
  if name=="studio-runtime.json" { b,_=json.Marshal(map[string]any{"engineBuild":"bound","engineVersion":"1.10.0","profile":"dora-preset","entry":"index.html","godot":true}) }
  if err:=os.WriteFile(filepath.Join(root,name),b,0600);err!=nil {t.Fatal(err)}
 }
 os.Mkdir(filepath.Join(root,"godot"),0700)
 artifacts:=map[string]string{}
 for _,name:=range godotFiles {
  b:=[]byte("runtime-"+name);os.WriteFile(filepath.Join(root,"godot",name),b,0600)
  artifacts[name]=fmt.Sprintf("%x",sha256.Sum256(b))
 }
 manifest:=map[string]any{"package_format":"dora-godot-runtime","package_version":1,"godot_version":${JSON.stringify(godotVersion)},"bridge_abi":1,"graphics_backend":"webgl2","artifacts":artifacts}
 raw,_:=json.Marshal(manifest)
 os.WriteFile(filepath.Join(root,"godot/manifest.json"),raw,0600)
 handler,err:=NewRuntimeHandler(root);if err!=nil {t.Fatal(err)}
 for _,name:=range append(append([]string{},godotFiles...),"manifest.json") {
  rec:=httptest.NewRecorder();handler.ServeHTTP(rec,httptest.NewRequest(http.MethodGet,"https://player.test/godot/"+name,nil))
  if rec.Code!=200 || rec.Header().Get("Cross-Origin-Embedder-Policy")!="require-corp" || rec.Header().Get("Cross-Origin-Resource-Policy")!="cross-origin" {t.Fatalf("Godot asset unavailable or unisolated: %s %d",name,rec.Code)}
  if strings.HasSuffix(name,".mjs") && !strings.Contains(rec.Header().Get("Content-Type"),"javascript") {t.Fatalf("ES module MIME: %s",rec.Header().Get("Content-Type"))}
 }
 rec:=httptest.NewRecorder();handler.ServeHTTP(rec,httptest.NewRequest(http.MethodGet,"https://player.test/godot/private.txt",nil));if rec.Code!=404 {t.Fatal("private asset exposed")}
 manifest["godot_version"]="0.0.0-unsupported"
 wrongVersion,_:=json.Marshal(manifest);os.WriteFile(filepath.Join(root,"godot/manifest.json"),wrongVersion,0600)
 if _,err=NewRuntimeHandler(root);err==nil {t.Fatal("wrong Godot version accepted")}
 os.WriteFile(filepath.Join(root,"godot/manifest.json"),raw,0600)
 os.WriteFile(filepath.Join(root,"godot/dora-godot.wasm"),[]byte("corrupt"),0600)
 if _,err=NewRuntimeHandler(root);err==nil {t.Fatal("corrupt Godot accepted")}
 os.Remove(filepath.Join(root,"godot/dora-godot.wasm"))
 if _,err=NewRuntimeHandler(root);err==nil {t.Fatal("missing Godot accepted")}
}
`);
    const result = spawnSync('go', ['test', '-v', '.'], {cwd: dir, encoding: 'utf8', timeout: 120000});
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { await rm(dir, {recursive: true, force: true}); }
});
