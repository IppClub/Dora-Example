"""Compatibility surface for existing Python tests, backed exclusively by Lua."""
from pathlib import Path
from lua_tools import call, LuaToolError
ProjectError = LuaToolError
GAME_FORMAT = 'dora-godot-game'
GODOT_VERSION = (4, 7)
PLATFORMS = {'macOS', 'Linux', 'Windows Desktop', 'Android', 'iOS', 'Web'}
_MODULE = 'Tools.Godot.project_delivery'
def digest(path): return call(_MODULE, 'digest', path)
def write_json(path, value): return call(_MODULE, 'write_json', path, value)
def source_files(root): return map(Path, call(_MODULE, 'source_files', root, list_result=True))
def fingerprint(root): return call(_MODULE, 'fingerprint', root)
def find_project(source, selection=None): return Path(call(_MODULE, 'find_project', source, selection))
def config_strings(text): return call(_MODULE, 'config_strings', text)
def inspect_project(source, selection=None): return call(_MODULE, 'inspect_project', source, selection)
def require_supported(info): return call(_MODULE, 'require_supported', info)
def run_command(command, log, timeout, *, env=None, cwd=None): return call(_MODULE, 'run_command', command, log, timeout, dict(env=env, cwd=cwd))
def editor_identity(executable): return call(_MODULE, 'editor_identity', executable)
def prepare(source, output, editor, selection=None, timeout=300): return call(_MODULE, 'prepare', source, output, editor, selection, timeout)
def inspect_pck(path): return call(_MODULE, 'inspect_pck', path)
def verify_game(package): return call(_MODULE, 'verify_game', package)
def inspect(source, selection=None): return call(_MODULE, 'inspect', source, selection)
def presets(project): return call(_MODULE, 'presets', project, list_result=True)
def export_game(source, output, work, editor, game_id, version='0.1.0', selection=None, preset=None, platform=None, timeout=300):
    return call(_MODULE, 'export_game', source, output, work, editor, game_id, version, selection, preset, platform, timeout)
def archive_game(package, output): return call(_MODULE, 'archive_game', package, output)
def install_game(archive, output, max_bytes=4*1024**3, max_files=10000): return call(_MODULE, 'install_game', archive, output, max_bytes, max_files)
def import_repository(archive, output, max_bytes=4*1024**3, max_files=100000): return call(_MODULE, 'import_repository', archive, output, max_bytes, max_files)
