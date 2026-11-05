#!/usr/bin/env python3
"""Exercise the Windows builder's actual version probe under a cp1252 default."""
import ast
import copy
import os
from pathlib import Path
import re
import subprocess
import sys
from unittest.mock import patch

root = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd()))
tree = ast.parse((root / 'Tools/Godot/build_windows_runtime.py').read_text())
probe = next(node.value for node in tree.body if isinstance(node, ast.Assign)
             and any(isinstance(target, ast.Name) and target.id == 'version_output' for target in node.targets))
real_check_output = subprocess.check_output

def windows_output(command, **kwargs):
    # The xmake banner is UTF-8; its emoji includes 0x8f, undefined in cp1252.
    kwargs.setdefault('encoding', 'cp1252')
    return real_check_output([sys.executable, '-c',
        "import sys; sys.stdout.buffer.write(b'xmake v3.1.2\\n\\xf0\\x9f\\x8f\\x97\\n')"], **kwargs)

def evaluate(expression):
    return eval(compile(ast.Expression(expression), '<actual-version-probe>', 'eval'),
                {'subprocess': subprocess, 'xmake': 'xmake'})

with patch.object(subprocess, 'check_output', windows_output):
    result = evaluate(probe)
    assert re.search(r'xmake\s+v(\d+)\.', result)[1] == '3'
    assert '\U0001f3d7' in result
    old = copy.deepcopy(probe)
    old.keywords = [arg for arg in old.keywords if arg.arg not in ('encoding', 'errors')]
    old.keywords.append(ast.keyword(arg='text', value=ast.Constant(True)))
    ast.fix_missing_locations(old)
    try:
        evaluate(old)
    except UnicodeDecodeError:
        pass
    else:
        raise AssertionError('Negative control must reproduce the original cp1252 failure')
print('PASS actual xmake version probe with cp1252 default; original failure reproduced')
