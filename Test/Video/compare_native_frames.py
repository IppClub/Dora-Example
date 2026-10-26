# Copyright (c) 2026 Li Jin. SPDX-License-Identifier: MIT
"""Compare NativeVideoControls.lua captures with independent FFmpeg decoding."""
import argparse
import json
from fractions import Fraction
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('original', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
result = json.loads((args.output / 'result.json').read_text())
assert result['success'], result.get('error')
metadata = json.loads(subprocess.check_output([
    'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
    'stream=width,height,r_frame_rate,duration', '-of', 'json', str(args.original)
]))['streams'][0]
fps = float(Fraction(metadata['r_frame_rate']))
last = round(float(metadata['duration']) * fps) - 1
size = metadata['width'] * metadata['height'] * 3
rows = result['captures']
assert len(rows) == 16, 'incomplete native test captures'
expected = lambda row: min(last, max(0, int(row['time'] * fps + 1e-7)))
indices = sorted({i for row in rows for i in range(max(0, expected(row)-5), min(last, expected(row)+5)+1)})
groups = []
for index in indices:
    if groups and groups[-1][1] + 1 == index:
        groups[-1][1] = index
    else:
        groups.append([index, index])
select = '+'.join(f'between(n,{a},{b})' for a, b in groups)
# Theora duplicate packets at EOF may not produce separate FFmpeg output images.
raw = subprocess.check_output([
    'ffmpeg', '-v', 'error', '-i', str(args.original), '-an', '-vf',
    f"tpad=stop_mode=clone:stop_duration=2,fps={fps},select='{select}'",
    '-fps_mode', 'passthrough', '-frames:v', str(len(indices)),
    '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'
])
assert len(raw) == len(indices) * size
references = {index: raw[n*size:(n+1)*size] for n, index in enumerate(indices)}
comparisons = []
for row in rows:
    image = subprocess.check_output([
        'ffmpeg', '-v', 'error', '-i', str(args.output / row['file']),
        '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'
    ])
    assert len(image) == size, f"unexpected capture dimensions: {row['file']}"
    frame = expected(row)
    scores = [(sum(abs(a-b) for a, b in zip(image, references[i]))/size, abs(i-frame), i)
              for i in range(max(0, frame-5), min(last, frame+5)+1)]
    error, _, matching = min(scores)
    comparisons.append({**row, 'expectedFrame': frame, 'matchingFrame': matching,
                        'frameDifference': matching-frame, 'meanAbsoluteRgbError': error})
(args.output / 'native-frame-comparison.json').write_text(json.dumps(comparisons, indent=2)+'\n')
assert all(abs(r['frameDifference']) <= 1 and r['meanAbsoluteRgbError'] < 1 for r in comparisons), comparisons
print(f"VIDEO_NATIVE_FRAMES_PASS {len(comparisons)} images, max frame difference="
      f"{max(abs(r['frameDifference']) for r in comparisons)}")
