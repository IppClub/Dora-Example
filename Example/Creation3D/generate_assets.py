"""Original offline unit GLBs, Y up, centered origin; no runtime mesh API."""
import json, math, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parent / 'assets'

def write(name, triangles):
    p=[]; n=[]
    for a,b,c in triangles:
        u=[b[i]-a[i] for i in range(3)]; v=[c[i]-a[i] for i in range(3)]
        normal=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
        length=math.sqrt(sum(x*x for x in normal))
        if length<1e-10: continue
        p.extend((a,b,c)); n.extend([tuple(x/length for x in normal)]*3)
    raw=b''.join(struct.pack('<3f',*v) for v in p+n)
    doc={'asset':{'version':'2.0','generator':'Dora Creation3D original primitives, MIT'},'scene':0,'scenes':[{'nodes':[0]}], 'nodes':[{'mesh':0,'name':name}], 'meshes':[{'primitives':[{'attributes':{'POSITION':0,'NORMAL':1},'material':0}]}], 'materials':[{'doubleSided':name=='plane','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.85}}], 'buffers':[{'byteLength':len(raw)}], 'bufferViews':[{'buffer':0,'byteLength':len(p)*12,'byteOffset':0},{'buffer':0,'byteLength':len(n)*12,'byteOffset':len(p)*12}], 'accessors':[{'bufferView':0,'componentType':5126,'count':len(p),'type':'VEC3','min':[min(v[i] for v in p) for i in range(3)],'max':[max(v[i] for v in p) for i in range(3)]},{'bufferView':1,'componentType':5126,'count':len(n),'type':'VEC3'}]}
    js=json.dumps(doc,separators=(',',':')).encode(); js+=b' '*(-len(js)%4)
    raw+=b'\0'*(-len(raw)%4)
    (ROOT/(name+'.glb')).write_bytes(struct.pack('<III',0x46546c67,2,28+len(js)+len(raw))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(raw),0x004e4942)+raw)
    print(name,len(p)//3,'triangles')

def quad(a,b,c,d): return [(a,b,c),(a,c,d)]
tri=[]
for axis in range(3):
    for sign in (-1,1):
        # Cross product of cyclic coordinate axes gives the outward normal.
        u=(axis+1)%3; v=(axis+2)%3
        verts=[]
        for x,y in [(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]:
            p=[0,0,0]; p[axis]=sign*.5; p[u]=x; p[v]=y; verts.append(tuple(p))
        if sign<0: verts.reverse()
        tri+=quad(*verts)
write('cube',tri)
write('plane',quad((-.5,0,-.5),(-.5,0,.5),(.5,0,.5),(.5,0,-.5)))
tri=[]
for i in range(16):
    a=2*math.pi*i/16; b=2*math.pi*(i+1)/16
    lo=(.5*math.cos(a),-.5,.5*math.sin(a)); hi=(lo[0],.5,lo[2])
    nl=(.5*math.cos(b),-.5,.5*math.sin(b)); nh=(nl[0],.5,nl[2])
    tri+=quad(lo,hi,nh,nl)+[((0,.5,0),nh,hi),((0,-.5,0),lo,nl)]
write('cylinder',tri)
def point(lat,lon): return (.5*math.cos(lat)*math.cos(lon),.5*math.sin(lat),.5*math.cos(lat)*math.sin(lon))
tri=[]
for j in range(8):
    a=-math.pi/2+j*math.pi/8; b=a+math.pi/8
    for i in range(16):
        c=i*2*math.pi/16; d=c+2*math.pi/16
        tri+=quad(point(a,c),point(b,c),point(b,d),point(a,d))
write('sphere',tri)
