#!/usr/bin/env python3
"""Exercise real acceptance predicates without starting Godot or a device."""
import ast
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, GODOT_UPSTREAM, GODOT_ENGINE_BANNER, GODOT_RUNTIME_PREFIX

base = TEST_REPO / 'Test/Godot/tests'
checks = 0

def predicates(relative, marker):
    tree = ast.parse((base / relative).read_text())
    found = [n for n in ast.walk(tree) if isinstance(n, ast.Assert) and marker in ast.unparse(n.test)]
    assert found, (relative, marker)
    return found

def exercise(nodes, good, bad):
    global checks
    for node in nodes:
        code = compile(ast.Expression(node.test), '<actual acceptance predicate>', 'eval')
        assert eval(code, good), ast.unparse(node.test)
        assert not eval(code, bad), ast.unparse(node.test)
        checks += 2

for relative in ('check_library.py',):
    exercise(predicates(relative, 'GODOT_RUNTIME_PREFIX'),
             dict(version=GODOT_RUNTIME_PREFIX+' ABI 1', GODOT_RUNTIME_PREFIX=GODOT_RUNTIME_PREFIX),
             dict(version='Godot 4.6-stable / Dora bridge ABI 1', GODOT_RUNTIME_PREFIX=GODOT_RUNTIME_PREFIX))
for relative in ('android/verify_dodge_release.py', 'android/verify_ordinary_release.py'):
    suffix = '\nDORA_DODGE complete=1 captures=12 ticks=625'
    exercise(predicates(relative, 'GODOT_ENGINE_BANNER'),
             dict(log=GODOT_ENGINE_BANNER+'stable.official\n'+suffix, GODOT_ENGINE_BANNER=GODOT_ENGINE_BANNER),
             dict(log='Godot Engine v4.6.stable.official\n'+suffix, GODOT_ENGINE_BANNER=GODOT_ENGINE_BANNER))
for banner in ('Godot Engine v4.6.stable', GODOT_ENGINE_BANNER+'stable'):
    exercise(predicates('ios/run_node.py', "'Godot Engine v'"), dict(log='Dora only'), dict(log=banner))

# Execute the actual reference header checks before the verifier opens any GPU samples.
tree = ast.parse((base/'verify_timing.py').read_text())
branch = next(n for n in tree.body if isinstance(n, ast.If) and ast.unparse(n.test)=='a.physics_catchup_reference')
header = branch.body[1:next(i for i,n in enumerate(branch.body) if isinstance(n, ast.For))]
code = compile(ast.Module(body=header, type_ignores=[]), '<actual timing reference header>', 'exec')
reference = dict(passed=True, contract='upstream_uncapped_render_step_before_physics_catchup_cap',
                 reference_commit=GODOT_UPSTREAM['upstream_commit'],
                 official_version=GODOT_UPSTREAM['version'].replace('-', '.')+'.official.'+GODOT_UPSTREAM['upstream_commit'][:9],
                 components={k: {} for k in ('official-godot-'+GODOT_UPSTREAM['version'].split('-',1)[0],
                                            'dora-metal', 'dora-egl-arm64', 'dora-egl-x64')})
scope = dict(catchup=reference, GODOT_UPSTREAM=GODOT_UPSTREAM,
             GODOT_ENGINE_VERSION=GODOT_UPSTREAM['version'].split('-',1)[0])
exec(code, scope)
checks += 1
for field, value, message in (
    ('reference_commit', '89cea1439', 'different Godot source revision'),
    ('official_version', '4.6.stable.official.89cea1439', 'different official editor'),
):
    try:
        exec(code, dict(scope, catchup=dict(reference, **{field: value})))
    except AssertionError as error:
        assert message in str(error), str(error)
    else:
        raise AssertionError('Accepted obsolete reference '+field)
    checks += 1

# Check version-to-cache wiring against the actual vendored GL path, not an old receipt.
java = (base/'android/lifecycle/app/src/main/java/org/dora/godotrc1/ReleaseLifecycle.java').read_text()
runner = (base/'android/run_ordinary_release.py').read_text()
version = GODOT_UPSTREAM['version'].split('-', 1)[0]
assert 'Dora/LibGodot-'+version+'/egl' in (ENGINE_ROOT/'Source/3rdParty/Godot/modules/dora_bridge/register_types_gl.cpp').read_text()
assert '"Dora/LibGodot-" + version + "/egl/shader_cache"' in java
assert "'-e', 'godot_cache_version', cache_version" in runner
assert "controller['shader_cache_version'] == cache_version" in runner
assert 'LibGodot-4.6' not in java
checks += 5
print(f'Runtime version acceptance guards: PASS ({checks} checks; CPU/metadata only)')
