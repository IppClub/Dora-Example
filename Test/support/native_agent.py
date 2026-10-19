"""Own a disposable native Agent service; never attach to a developer's engine."""
from contextlib import AbstractContextManager
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

PORTS = (8866, 8868)


def assert_ports_free(ports=PORTS):
    for port in ports:
        with socket.socket() as sock:
            if hasattr(socket, 'SO_EXCLUSIVEADDRUSE'):
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
            else:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind(('0.0.0.0', port))
            except OSError as error:
                raise RuntimeError(f'Port {port} is already in use; refusing to attach to or stop an existing service') from error


def add_engine_argument(parser):
    parser.add_argument('--engine', '--dora', dest='engine', type=Path, required=True,
                        help='Native Dora binary to launch in a disposable profile (--dora is an alias)')


class NativeAgent(AbstractContextManager):
    def __init__(self, engine, repo, startup_timeout=30, shutdown_timeout=12, ports=PORTS):
        self.ports = tuple(ports)
        self.engine = Path(engine).resolve()
        self.repo = Path(repo).resolve()
        self.startup_timeout = startup_timeout
        self.shutdown_timeout = shutdown_timeout
        self.process = None
        self.temporary = None
        self.log = None
        self.environment = {key: value for key, value in os.environ.items()
                            if key.lower() not in {'http_proxy', 'https_proxy', 'all_proxy', 'no_proxy'}}

    def __enter__(self):
        if sys.platform not in ('darwin', 'linux'):
            raise RuntimeError('Disposable native Agent profiles currently support macOS/Linux only')
        if not self.engine.is_file() or not os.access(self.engine, os.X_OK):
            raise RuntimeError(f'Native engine is not executable: {self.engine}')
        if not (self.repo / 'Assets/Script/Dev/WebServer.lua').is_file():
            raise RuntimeError(f'DORA_ENGINE_ROOT must point to an engine checkout: {self.repo}')
        if sys.platform == 'linux' and not (os.environ.get('DISPLAY') or os.environ.get('WAYLAND_DISPLAY')):
            raise RuntimeError('Native engine requires a display; run under xvfb-run with Mesa on headless Linux')
        assert_ports_free(self.ports)
        self.temporary = tempfile.TemporaryDirectory(prefix='dora-native-agent-')
        self.root = Path(self.temporary.name).resolve()
        self.profile = self.root / 'profile'
        self.profile.mkdir()
        self.log_path = self.root / 'engine.log'
        self.log = self.log_path.open('w')
        self.environment.update(CFFIXED_USER_HOME=str(self.profile), XDG_DATA_HOME=str(self.profile / 'data'), DORA_PORT=str(self.ports[0]))
        deadline = time.monotonic() + self.startup_timeout
        try:
            self.process = subprocess.Popen(
                [str(self.engine), '--asset', str(self.repo / 'Assets')],
                cwd=self.repo / 'Assets', env=self.environment,
                stdout=self.log, stderr=subprocess.STDOUT, start_new_session=True)
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            last_error = 'no response'
            while time.monotonic() < deadline:
                if self.process.poll() is not None:
                    raise RuntimeError(f'Native engine exited during startup: {self.process.returncode}')
                try:
                    request = urllib.request.Request(f'http://127.0.0.1:{self.ports[0]}/status', data=b'{}',
                                                    headers={'Content-Type': 'application/json', 'Sec-Fetch-Site': 'same-origin'})
                    with opener.open(request, timeout=min(1, max(.001, deadline - time.monotonic()))) as response:
                        status = json.load(response)
                    writable = Path(status['writablePath']).resolve()
                    if self.profile not in writable.parents:
                        raise RuntimeError(f'Refusing service outside disposable profile: {writable}')
                    self.status = status
                    print(f'Native Agent ready (pid={self.process.pid}, disposable profile)', flush=True)
                    return self
                except urllib.error.HTTPError as error:
                    raise RuntimeError(f'Native Agent readiness returned HTTP {error.code}') from error
                except (OSError, urllib.error.URLError) as error:
                    last_error = str(error)
                    time.sleep(min(.1, max(0, deadline - time.monotonic())))
            raise TimeoutError(f'Native Agent startup timed out after {self.startup_timeout}s: {last_error}')
        except BaseException:
            self.__exit__(*sys.exc_info())
            raise

    def command(self, project, code, timeout_seconds=30, client_timeout=None):
        request = Path(project) / 'request.json'
        request.write_text(json.dumps({'mode': 'lua', 'code': code, 'timeoutSeconds': timeout_seconds}))
        result = subprocess.run(
            [str(self.engine), '--asset', str(self.repo / 'Assets'), 'cli', 'agent', 'command',
             '-p', str(project), '--input', str(request)],
            text=True, capture_output=True, env=self.environment,
            timeout=client_timeout if client_timeout is not None else timeout_seconds + 20)
        try:
            reply = json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise AssertionError(f'Invalid CLI response (exit={result.returncode}): {result.stdout}\n{result.stderr}') from error
        if result.returncode != 0 or not reply.get('success'):
            raise AssertionError(f'Agent command failed (exit={result.returncode}): {reply}')
        return reply

    def __exit__(self, exc_type, exc, traceback):
        errors = []
        try:
            if self.process is not None:
                if self.process.poll() is None:
                    self.process.terminate()
                try:
                    self.process.wait(timeout=self.shutdown_timeout)
                except subprocess.TimeoutExpired:
                    errors.append('Native engine shutdown timed out; killed its process group')
                    os.killpg(self.process.pid, signal.SIGKILL)
                    self.process.wait(timeout=5)
                if self.process.returncode != 0:
                    errors.append(f'Native engine exit code: {self.process.returncode}')
                deadline = time.monotonic() + 3
                while True:
                    try:
                        assert_ports_free(self.ports)
                        break
                    except RuntimeError as error:
                        if time.monotonic() >= deadline:
                            errors.append(str(error))
                            break
                        time.sleep(.1)
            if exc is not None or errors:
                if self.log is not None:
                    self.log.flush()
                    print('Native Agent engine log (tail):\n' + self.log_path.read_text(errors='replace')[-6000:], file=sys.stderr)
                if errors:
                    message = '; '.join(errors)
                    if exc is None:
                        raise AssertionError(message)
                    if hasattr(exc, 'add_note'):
                        exc.add_note(message)
                    print(message, file=sys.stderr)
            elif self.process is not None:
                print(f'Native Agent exited normally; ports {self.ports[0]}/{self.ports[1]} released', flush=True)
        finally:
            if self.log is not None:
                self.log.close()
            if self.temporary is not None:
                self.temporary.cleanup()
        return False
