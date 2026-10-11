#!/usr/bin/env python3
"""Exercise production DrawNode geometry with a headless vertex sink.

Only engine storage/rendering is replaced; helpers and drawing commands are
compiled verbatim from DrawNode.cpp. Requires a C++17 compiler.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile
import os

def default_engine_root():
    if os.environ.get('DORA_SSR_ROOT'):
        return Path(os.environ['DORA_SSR_ROOT']).expanduser().resolve()
    for parent in Path(__file__).resolve().parents:
        candidate = parent / 'Dora-SSR'
        if (candidate / 'Source/Node/DrawNode.cpp').is_file():
            return candidate
    return None


ROOT = default_engine_root()
PRELUDE = r'''
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <limits>
#include <numeric>
#include <stdexcept>
#include <vector>
#define s_cast static_cast
template<class... T> void Warn(T...) {}
struct Vec2 {
 float x=0, y=0;
 Vec2 operator+(Vec2 b) const {return {x+b.x,y+b.y};}
 Vec2 operator-(Vec2 b) const {return {x-b.x,y-b.y};}
 Vec2 operator-() const {return {-x,-y};}
 Vec2 operator*(float b) const {return {x*b,y*b};}
 Vec2 operator/(float b) const {return {x/b,y/b};}
 float dot(Vec2 b) const {return x*b.x+y*b.y;}
 float lengthSquared() const {return dot(*this);}
 float length() const {return std::sqrt(lengthSquared());}
 float distanceSquared(Vec2 b) const {return (*this-b).lengthSquared();}
 static Vec2 normalize(Vec2 b) {auto l=b.length();return l>0?b/l:b;}
 static Vec2 perp(Vec2 b) {return {-b.y,b.x};}
 static const Vec2 zero;
};
const Vec2 Vec2::zero={0,0};
struct Vec4 {float x,y,z,w;};
struct Color {
 uint32_t value; uint8_t a;
 Color(uint32_t v):value(v),a(v>>24){}
 Vec4 toVec4() const {return {float((value>>16)&255)/255,float((value>>8)&255)/255,float(value&255)/255,float(a)/255};}
};
struct Rect {
 Vec2 origin; struct {float width,height;} size;
 float getLeft() const {return origin.x;}
 float getRight() const {return origin.x+size.width;}
 float getBottom() const {return origin.y;}
 float getTop() const {return origin.y+size.height;}
};
struct DrawVertexInput {Vec4 position,color;Vec2 texCoord;};
struct DrawNode {
 static DrawNode* create() {static DrawNode node;node.clear();return &node;}
 enum {VertexColorDirty,VertexPosDirty};
 struct {void setOn(int){}} _flags;
 std::vector<DrawVertexInput> _vertices;
 std::vector<DrawVertexInput> _posColors;
 std::vector<uint16_t> _indices;
 bool ensureVertexCapacity(uint64_t n) {return n<=65536-_vertices.size();}
 void pushVertex(Vec2 p,Vec4 c,Vec2 uv) {_vertices.push_back({{p.x,p.y,0,1},c,uv});}
 void clear() {_vertices.clear();_posColors.clear();_indices.clear();}
 auto& getVertices() {return _vertices;}
 auto& getIndices() {return _indices;}
 void drawIndexedVertices(const std::vector<DrawVertexInput>& v,const std::vector<uint16_t>& i) {
  if(!ensureVertexCapacity(v.size()))return;
  auto start=_vertices.size();_vertices.insert(_vertices.end(),v.begin(),v.end());
  for(auto index:i) {if(index>=v.size())throw std::runtime_error("bad index");_indices.push_back(start+index);}
 }
 void drawDot(const Vec2&,float,Color);
 void drawCircle(const Vec2&,float,Color);
 void drawRect(const Rect&,Color,float,Color);
 void drawRoundedRect(const Rect&,float,Color,float,Color);
 void drawRing(const Vec2&,float,float,Color,float,Color);
 void drawSector(const Vec2&,float,float,float,Color,float,Color);
 void drawEllipse(const Vec2&,float,float,Color);
 void drawSegment(const Vec2&,const Vec2&,float,Color);
 void drawPolyline(const std::vector<Vec2>&,float,Color,bool);
 void drawPolyline(const Vec2*,uint32_t,float,Color,bool);
 void drawArc(const Vec2&,float,float,float,float,Color);
 void drawQuadraticBezier(const Vec2&,const Vec2&,const Vec2&,float,Color);
 void drawCubicBezier(const Vec2&,const Vec2&,const Vec2&,const Vec2&,float,Color);
 void drawPolygon(const std::vector<Vec2>&,Color,float,Color);
 void drawPolygon(const Vec2*,uint32_t,Color,float,Color);
};
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine-root', type=Path, default=ROOT, help='Dora-SSR checkout (or set DORA_SSR_ROOT)')
    args = parser.parse_args()
    if args.engine_root is None:
        parser.error('Cannot locate Dora-SSR; supply --engine-root or DORA_SSR_ROOT')
    source = (args.engine_root / 'Source/Node/DrawNode.cpp').read_text()
    helpers = source[source.index('namespace {'):source.index('/* DrawNode */')]
    commands = source[source.index('void DrawNode::drawDot('):source.index('void DrawNode::drawVertices(')]
    tests = (Path(__file__).with_name('drawnode_geometry.cpp')).read_text()
    with tempfile.TemporaryDirectory(prefix='dora-geometry-') as directory:
        directory = Path(directory)
        cpp = directory / 'test.cpp'
        cpp.write_text(PRELUDE + helpers + commands + tests + '\nint main(){try{runTests();std::cout<<"DrawNode geometry checks passed\\n";}catch(const std::exception& e){std::cerr<<e.what()<<"\\n";return 1;}}\n')
        executable = directory / 'test'
        subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++17', '-fsanitize=address,undefined', '-g', str(cpp), '-o', str(executable)], check=True)
        subprocess.run([str(executable)], check=True)

if __name__ == '__main__':
    main()
