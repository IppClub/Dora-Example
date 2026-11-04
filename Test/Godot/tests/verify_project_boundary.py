"""Image and GPU-accounting checks for ordinary-host project boundaries."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[3] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import hashlib,re
from PIL import Image,ImageChops
def verify(out,expected_error,failed_reader_reported=True):
    log=(out/'run.log').read_text()
    lifecycle=expected_error is None
    for token in ('running=initial','running=other' if lifecycle else 'different_project_rejected=1','running=recovered','complete=1 captures=5'):
        assert 'GODOT_PROJECT_BOUNDARY '+token in log,token
    assert re.findall(r'GODOT_NODE_SCENE boots=(\d+) root_path_ok=1',log)==(['1','1','1'] if lifecycle else ['1','2']),'Unexpected scene boots at project boundaries'
    errors=[line for line in log.splitlines() if '[error]' in line or 'ERROR:' in line]
    if lifecycle:
        assert not errors,errors
    else:
        assert len(errors)==1 and expected_error in errors[0],errors
    assert not any(text in log for text in ('BGFX LEAK:','C++ objects leaks','GODOT_NODE_TEST','MTLCommandBufferError'))
    clients=re.findall(r'GodotRuntime client closed: produced=(\d+), completed=(\d+), gpuErrors=(\d+)',log)
    assert len(clients)==(3 if lifecycle else 2) and all(int(p)>0 and p==c and e=='0' for p,c,e in clients),clients
    readers=re.findall(r'GodotRuntime readers: buffers=(\d+), frames=(\d+), waits=(\d+), signals=(\d+), pending=(\d+), completed=(\d+), gpuErrors=(\d+)',log)
    assert len(readers)==(3 if lifecycle or failed_reader_reported else 2) and sum(int(row[1])>0 for row in readers)==(3 if lifecycle else 2),readers
    for b,f,w,s,pending,c,e in readers:
        assert b=='3' and pending=='0' and f==c and e=='0',readers
        if int(f)>0:assert 0<int(w)<=int(s) and int(s)==int(f)*3,readers
    if lifecycle:
        ids=re.findall(r'DORA_GODOT_PROJECT_ID instance=(\d+) tree=(\d+)',log)
        assert len(ids)==3 and len({i for i,t in ids})==1 and len({t for i,t in ids})==3,ids
        clean=re.findall(r'DORA_GODOT_PROJECT_CLEAN objects=(\d+) resources=(\d+) nodes=(\d+)',log)
        assert len(clean)==3 and all(n=='0' for o,r,n in clean),clean
    def pixels(im):return im.get_flattened_data() if hasattr(im,'get_flattened_data') else im.getdata()
    changed=[]
    for prefix in ('initial','recovered'):
        images=[Image.open(out/(prefix+'-'+suffix+'.png')).convert('RGB') for suffix in ('a','b')]
        assert images[0].size==images[1].size
        w,h=images[0].size;box=(round(w*.4),round(h*.3),round(w*.6),round(h*.7))
        crops=[im.crop(box) for im in images]
        assert all(sum(g>70 and b>70 and r<g*.65 for r,g,b in pixels(im))>100 for im in crops),'Godot pixels missing'
        count=sum(max(pixel)>8 for pixel in pixels(ImageChops.difference(*crops)));assert count>100;changed.append(count)
    removed=Image.open(out/'removed.png').convert('RGB');w,h=removed.size
    assert all(max(abs(c-e) for c,e in zip(pixel,(25,35,49)))<=3 for pixel in pixels(removed.crop((w//2-50,h//2-50,w//2+50,h//2+50))))
    images={path.name:hashlib.file_digest(path.open('rb'),'sha256').hexdigest() for path in out.glob('*.png')}
    assert len(images)==5
    return {'captures':5,'changed_pixels':changed,'gpu_clients':clients,'gpu_readers':readers,'failed_client_reader_reported':failed_reader_reported,'images_sha256':images}
