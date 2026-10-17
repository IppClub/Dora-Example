#!/usr/bin/env python3
"""Exercise POSIX shutdown, optionally against a freshly built desktop engine.

python3 Tools/tests/test_shutdown_watchdog.py --engine /absolute/path/Dora
The engine test requires a desktop session and unused ports 8866 and 8868.
"""
import argparse
import http.client
import json
import os
from pathlib import Path
import signal
import socket
import sqlite3
import subprocess
import tempfile
import time

ROOT = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd())).resolve()
PORTS = (8866, 8868)


def wait_for(predicate, timeout=30):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError("Timed out waiting for engine state")


def post(path, body, timeout=1):
    conn = http.client.HTTPConnection("127.0.0.1", PORTS[0], timeout=timeout)
    try:
        conn.request("POST", path, json.dumps(body), {
            "Content-Type": "application/json", "Sec-Fetch-Site": "same-origin",
        })
        response = conn.getresponse()
        data = response.read()
        assert response.status == 200, (response.status, data)
        return json.loads(data)
    finally:
        conn.close()


def assert_ports_free():
    for port in PORTS:
        with socket.socket() as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.bind(("0.0.0.0", port))
            sock.listen()


def fixture_tests(temp):
    source = temp / "watchdog.cpp"
    exe = temp / "watchdog"
    application = (ROOT / "Source/Basic/Application.cpp").read_text()
    start = application.index("class ShutdownWatchdog {")
    watchdog = application[start:application.index("\n};", start) + len("\n};")]
    source.write_text(r'''
#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <system_error>
#include <thread>
WATCHDOG
#include <iostream>
#include <string>
void wedge() { for (;;) std::this_thread::sleep_for(std::chrono::seconds(1)); }
void drain() { std::this_thread::sleep_for(std::chrono::seconds(2)); }
int main(int argc, char** argv) {
    const std::string mode = argv[1];
    if (!ShutdownWatchdog::start(mode == "drain" ? drain : +[]{})
        || !ShutdownWatchdog::start(+[]{})) return 2;
    std::cout << "READY" << std::endl;
    if (mode == "wedged" || mode == "drain") wedge();
    while (!ShutdownWatchdog::isRequested())
        std::this_thread::sleep_for(std::chrono::milliseconds(5));
    if (mode == "cleanup") { std::atexit(wedge); }
    return 0;
}
'''.replace('WATCHDOG', watchdog))
    subprocess.run([os.environ.get("CXX", "c++"), "-std=c++17", "-pthread",
                    "-I", str(ROOT), str(source), "-o", str(exe)], check=True)
    for mode in ("normal", "wedged", "cleanup", "drain"):
        for sig in (signal.SIGTERM, signal.SIGINT):
            proc = subprocess.Popen([str(exe), mode], stdout=subprocess.PIPE, text=True)
            try:
                assert proc.stdout.readline().strip() == "READY"
                started = time.monotonic()
                proc.send_signal(sig)
                if mode == "wedged":
                    time.sleep(1)
                    proc.send_signal(sig)  # A second request must not reset the deadline.
                code = proc.wait(timeout=7)
                elapsed = time.monotonic() - started
                assert code == (0 if mode == "normal" else 128 + sig), (mode, sig, code)
                assert elapsed < (1 if mode == "normal" else 6 if mode == "drain" else 4), elapsed
                if mode == "drain":
                    assert elapsed >= 5, elapsed  # Two-second drain, then three-second grace.
                elif mode != "normal":
                    assert elapsed >= 3, elapsed
                print(f"fixture {mode} {sig.name}: exit={code}, {elapsed:.3f}s", flush=True)
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()
                proc.stdout.close()


def engine_tests(engine, temp, cases=None):
    assert_ports_free()  # Never signal an unrelated existing instance.
    if cases is None:
        cases = [(m, s) for m in ("normal", "wedged", "database", "database-wedged")
                 for s in (signal.SIGTERM, signal.SIGINT)]
        cases.append(("database-event", signal.SIGTERM))
    for mode, sig in cases:
        profile = temp / f"{mode}-{sig.name}"
        profile.mkdir()
        pending_db = mode.startswith("database")
        wedged = mode.endswith("wedged")
        reader = None
        marker = profile / "entered-loop"
        project = profile / "project"
        project.mkdir()
        (project / "init.lua").write_text(
            'local Dora = require("Dora")\n'
            'Dora.thread(function()\n'
            '  Dora.sleep(0.5)\n'
            f'  assert(Dora.Content:save({json.dumps(str(marker))}, "entered"))\n'
            '  while true do end\n'
            'end)\n')
        db_path = profile / "transaction.db"
        setup = profile / "database-ready"
        go = profile / "begin-transactions"
        if pending_db:
            lua = 'local Dora = require("Dora")\nlocal DB = Dora.DB\n'
            lua += f"DB:exec(\"ATTACH DATABASE '{db_path}' AS shutdown_test\")\n"
            lua += 'DB:exec("PRAGMA shutdown_test.journal_mode=DELETE")\n'
            lua += 'DB:exec("PRAGMA busy_timeout=15000")\n'
            lua += 'DB:exec("CREATE TABLE shutdown_test.items(id INTEGER PRIMARY KEY)")\n'
            lua += f'assert(Dora.Content:save({json.dumps(str(setup))}, "ready"))\n'
            for index in range(2):
                lua += ('Dora.thread(function()\n'
                        f'  while not Dora.Content:exist({json.dumps(str(go))}) do Dora.sleep(0.01) end\n'
                        '  assert(DB:transactionAsync({\n'
                        f'    "INSERT INTO shutdown_test.items VALUES({2*index+1})",\n'
                        f'    "INSERT INTO shutdown_test.items VALUES({2*index+2})"\n'
                        '  }))\nend)\n')
            if wedged:
                lua += ('Dora.thread(function()\n'
                        f'  while not Dora.Content:exist({json.dumps(str(go))}) do Dora.sleep(0.01) end\n'
                        '  Dora.sleep(0.5)\n'
                        f'  assert(Dora.Content:save({json.dumps(str(marker))}, "entered"))\n'
                        '  while true do end\nend)\n')
            (project / "init.lua").write_text(lua)
        log_path = profile / "engine.log"
        with log_path.open("w") as log:
            proc = subprocess.Popen([str(engine)], cwd=ROOT / "Assets",
                                    env=dict(os.environ, CFFIXED_USER_HOME=str(profile),
                                             XDG_DATA_HOME=str(profile / "data")),
                                    stdout=log, stderr=log)
            try:
                def ready():
                    assert proc.poll() is None, log_path.read_text()[-3000:]
                    try:
                        return post("/info", {}).get("platform") in ("macOS", "Linux")
                    except OSError:
                        return False
                wait_for(ready)
                # Both listeners must exist before testing their release.
                for port in PORTS:
                    with socket.create_connection(("127.0.0.1", port), timeout=1):
                        pass
                if pending_db or wedged:
                    result = post("/run", {"file": str(project / "init.lua"),
                                          "asProj": True, "projectRoot": str(project)}, 10)
                    assert result.get("success"), result
                    if pending_db:
                        wait_for(setup.exists, 10)
                        reader = sqlite3.connect(db_path)
                        reader.execute("BEGIN")
                        assert reader.execute("SELECT COUNT(*) FROM items").fetchone() == (0,)
                        go.write_text("start")
                        journal = Path(str(db_path) + "-journal")
                        wait_for(lambda: journal.exists() and journal.stat().st_size > 0, 10)
                    if wedged:
                        wait_for(marker.exists, 10)
                    time.sleep(0.2)
                    if wedged:
                        try:
                            post("/info", {}, 0.5)
                        except TimeoutError:
                            pass
                        else:
                            raise AssertionError("Logic thread is still answering requests")
                    assert proc.poll() is None
                started = time.monotonic()
                if mode == "database-event":
                    result = post("/command", {"code": "App.devMode = false\nApp\\shutdown!", "log": False})
                    assert result.get("success"), result
                else:
                    proc.send_signal(sig)
                if pending_db:
                    time.sleep(3.5)
                    assert proc.poll() is None, "Exit interrupted a pending database transaction"
                    assert reader.execute("SELECT COUNT(*) FROM items").fetchone() == (0,)
                    reader.commit()
                    reader.close()
                    reader = None
                    released = time.monotonic()
                code = proc.wait(timeout=6)
                elapsed = time.monotonic() - started
                expected = (128 + sig,) if wedged else (0,)
                assert code in expected, (mode, sig, code)
                assert elapsed < (8 if pending_db else 3 if mode == "normal" else 4.5), elapsed
                if pending_db:
                    assert elapsed >= 3.5, elapsed
                    if wedged:
                        assert time.monotonic() - released >= 3, "Grace started before DB stopped"
                    with sqlite3.connect(db_path) as db:
                        assert db.execute("SELECT id FROM items ORDER BY id").fetchall() == [(1,), (2,), (3,), (4,)]
                        assert db.execute("PRAGMA integrity_check").fetchone() == ("ok",)
                elif wedged:
                    assert elapsed >= 3, elapsed
                assert_ports_free()
                event = "SDL_QUIT" if mode == "database-event" else sig.name
                print(f"engine {mode} {event}: pid={proc.pid}, exit={code}, "
                      f"{elapsed:.3f}s; both ports rebound" +
                      ("; both transactions committed, integrity ok" if pending_db else ""), flush=True)
            except BaseException:
                print(log_path.read_text()[-4000:], flush=True)
                raise
            finally:
                if reader is not None:
                    reader.close()
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="dora-shutdown-test-") as directory:
        temp = Path(directory)
        fixture_tests(temp)
        if args.engine:
            engine_tests(args.engine.resolve(), temp)
