#!/usr/bin/env python3
"""Measure production sector tessellation without a renderer.

Run with --source PATH to compare against a saved DrawNode.cpp. Results are
median CPU microseconds from seven calls, not frame times or GPU measurements.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

from test_drawnode_geometry import PRELUDE, ROOT

MAIN = r'''
#include <chrono>
int main() {
 auto node = DrawNode::create();
 const Color color(0x805030d0), transparent(0);
 std::cout << "sweep,width,median_us,vertices,triangles\n";
 for (float sweep : {30.f, 270.f, 359.f, -270.f}) {
  for (float width : {4.f, 6000.f, 12000.f}) {
   std::array<long long, 7> times;
   size_t vertices = 0, triangles = 0;
   for (auto& time : times) {
    const auto start = std::chrono::steady_clock::now();
    node->drawSector({0, 0}, 10000, 0, sweep, transparent, width, color);
    time = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - start).count();
    vertices = node->getVertices().size(); triangles = node->getIndices().size() / 3;
    node->clear();
   }
   std::sort(times.begin(), times.end());
   std::cout << sweep << ',' << width << ',' << times[3] << ',' << vertices << ',' << triangles << '\n';
  }
 }
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, help='Saved DrawNode.cpp to benchmark instead of the current engine')
    parser.add_argument('--engine-root', type=Path, default=ROOT, help='Dora-SSR checkout (or set DORA_SSR_ROOT)')
    args = parser.parse_args()
    if args.source is None and args.engine_root is None:
        parser.error('Cannot locate Dora-SSR; supply --engine-root, --source or DORA_SSR_ROOT')
    source_path = args.source if args.source is not None else args.engine_root / 'Source/Node/DrawNode.cpp'
    source = source_path.read_text()
    helpers = source[source.index('namespace {'):source.index('/* DrawNode */')]
    commands = source[source.index('void DrawNode::drawDot('):source.index('void DrawNode::drawVertices(')]
    with tempfile.TemporaryDirectory(prefix='dora-sector-benchmark-') as directory:
        directory = Path(directory)
        cpp = directory / 'benchmark.cpp'
        cpp.write_text(PRELUDE + helpers + commands + MAIN)
        executable = directory / 'benchmark'
        subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++17', '-O2', str(cpp), '-o', str(executable)], check=True)
        subprocess.run([str(executable)], check=True)


if __name__ == '__main__':
    main()
