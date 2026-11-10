#!/usr/bin/env python3
"""Original RGBA preservation, alignment and rebuild regression checks."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import os
import sys

ENGINE_ART = Path(os.environ['DORA_ENGINE_ROOT']) / 'Tools/Art/Mobile'
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'support'))
from godot_paths import ENGINE_ROOT

from PIL import Image
CELL, PIVOT = 272, (136, 248)
DEST = ENGINE_ROOT/'Assets/Image/Mobile/dora-remix-states.png'
LAYOUT = ENGINE_ROOT/'Assets/Script/Dev/Mobile/MascotFrames.ts'
SOURCE = ENGINE_ART/'dora-remix-states.original.png'
def rebuilt(directory):
    output, layout = Path(directory)/'atlas.png', Path(directory)/'MascotFrames.ts'
    subprocess.run([os.environ.get('DORA_XMAKE','xmake'),'lua',str(ENGINE_ART/'rebuild_mascot.lua'),'--output',str(output),'--layout-output',str(layout),'--evidence',str(directory)],check=True,capture_output=True)
    return output, layout, json.loads((Path(directory)/'atlas.json').read_text())



class MascotAtlasTest(unittest.TestCase):
    def test_source_is_original_not_generated(self):
        self.assertEqual(hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                         '3684c2eef76bec9ebb418905418944805f715091ef8bcce76c81e8095cb178d1')

    def test_original_rgba_and_alignment(self):
        original=Image.open(SOURCE).convert('RGBA')
        atlas=Image.open(DEST).convert('RGBA')
        self.assertEqual(atlas.size,(CELL*4,CELL*6))
        with tempfile.TemporaryDirectory() as directory:
            output, layout, record = rebuilt(directory)
            generated = Image.open(output).convert('RGBA')
            self.assertEqual(atlas.tobytes(), generated.tobytes())
            self.assertEqual(LAYOUT.read_text(), layout.read_text())
            metadata = record['frames']
        for i,meta in enumerate(metadata):
            actual=atlas.crop((i%4*CELL,i//4*CELL,(i%4+1)*CELL,(i//4+1)*CELL))
            x,y=meta['destination']
            crop=meta['source_crop']
            self.assertEqual(actual.crop((x,y,x+crop[2]-crop[0],y+crop[3]-crop[1])).tobytes(),
                             original.crop(crop).tobytes(),'Changed original color/alpha')
            self.assertEqual(meta['source_pivot'][1]+meta['translation'][1],PIVOT[1])
            self.assertEqual(meta['source_pivot'][0]+meta['translation'][0],meta['pivot'][0])
            self.assertLessEqual(abs(meta['pivot'][0]-PIVOT[0]),.5)
            self.assertTrue(any(0<p[3]<255 for p in actual.get_flattened_data()),'Original alpha was quantized')
        self.assertGreater(len(set(atlas.get_flattened_data())),100000,'Original palette was quantized')

    def test_reproducible(self):
        with tempfile.TemporaryDirectory(prefix='dora-mascot-test-') as directory:
            output=Path(directory)/'atlas.png'
            layout=Path(directory)/'MascotFrames.ts'
            output, layout, _ = rebuilt(directory)
            self.assertEqual(Image.open(DEST).convert('RGBA').tobytes(),Image.open(output).convert('RGBA').tobytes())
            first = output.read_bytes()
            rebuilt(directory)
            self.assertEqual(first,output.read_bytes(),'Repeated Lua rebuild changed encoded output')
            self.assertEqual(LAYOUT.read_bytes(),layout.read_bytes())
            metadata=json.loads((Path(directory)/'atlas.json').read_text())
            self.assertEqual(len(metadata['frames']),24)


if __name__ == '__main__':
    unittest.main()
