#!/usr/bin/env python3
"""Real-engine acceptance for failure, timeout and port-ownership cleanup."""
import argparse
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'support'))
from native_agent import NativeAgent, add_engine_argument, assert_ports_free


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    add_engine_argument(parser)
    args = parser.parse_args()
    repo = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd())).resolve()

    def check(label, action, exception, message=None, exit_codes=(0,), **options):
        service = NativeAgent(args.engine, repo, **options)
        try:
            with service:
                action(service)
        except exception as error:
            if message is not None:
                assert message in str(error), str(error)
        else:
            raise AssertionError(f'{label}: expected {exception.__name__}')
        assert service.process is not None and service.process.poll() is not None, label
        assert service.process.returncode in exit_codes, f'{label}: unexpected exit {service.process.returncode}'
        assert not service.root.exists(), f'{label}: disposable profile leaked'
        assert_ports_free()
        print(f'PASS: {label}; process reaped, profile removed, ports released', flush=True)

    def assertion_failure(service):
        raise AssertionError('injected test assertion')

    check('test assertion failure', assertion_failure, AssertionError, 'injected test assertion')
    check('Lua command failure', lambda s: s.command(s.root, 'error("injected Lua failure")'),
          AssertionError, 'injected Lua failure')
    check('Lua execution timeout', lambda s: s.command(s.root, 'sleep(10)', timeout_seconds=1),
          AssertionError, 'timed out')

    def request_timeout(service):
        service.command(service.root, 'print("warm command bridge")')
        try:
            service.command(service.root, 'Content:save("timeout-started", "yes"); sleep(10)', client_timeout=1)
        except subprocess.TimeoutExpired:
            assert (service.root / 'timeout-started').is_file(), 'CLI timed out before executing the request'
            raise

    check('CLI request timeout during Lua execution', request_timeout, subprocess.TimeoutExpired)
    check('startup timeout', lambda s: None, TimeoutError, 'startup timed out', startup_timeout=.001, exit_codes=(0, -signal.SIGTERM))
    check('unresponsive engine shutdown', lambda s: os.kill(s.process.pid, signal.SIGSTOP),
          AssertionError, 'shutdown timed out', shutdown_timeout=.2, exit_codes=(-signal.SIGKILL,))

    # An occupied port belongs to somebody else: fail before launching anything.
    assert_ports_free()
    with socket.socket() as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(('0.0.0.0', 8866))
        listener.listen()
        service = NativeAgent(args.engine, repo)
        try:
            with service:
                raise AssertionError('must not enter')
        except RuntimeError as error:
            assert 'already in use' in str(error), str(error)
        else:
            raise AssertionError('occupied port accepted')
        assert service.process is None
        assert listener.getsockname()[1] == 8866
    assert_ports_free()
    print('PASS: occupied port rejected without starting or stopping another service', flush=True)


if __name__ == '__main__':
    main()
