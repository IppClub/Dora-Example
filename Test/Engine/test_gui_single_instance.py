#!/usr/bin/env python3
"""Test production GUI single-instance behavior; optionally check a real desktop engine.

xmake dora-test --case=test_gui_single_instance --repo=/path/to/Dora-Example
Append -- --engine /absolute/path/Dora for GUI/CLI integration (desktop required).
"""
import argparse
import concurrent.futures
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd())).resolve()


def stop(proc):
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=6)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=3)
    for stream in (proc.stdin, proc.stdout, proc.stderr):
        if stream:
            stream.close()


def fixture_tests(temp):
    source = temp / 'instance.cpp'
    exe = temp / ('instance.exe' if os.name == 'nt' else 'instance')
    source.write_text(r'''
#include "Source/Basic/GuiInstance.h"
#include <iostream>
int main(int, char** argv) {
    Dora::GuiInstance instance(argv[1]);
    auto result = instance.acquire();
    if (result == Dora::GuiInstance::Result::Error) return 2;
    if (result != Dora::GuiInstance::Result::Primary) {
        std::cout << "EXISTING" << std::endl;
        return 0;
    }
    std::cout << "PRIMARY" << std::endl;
    std::string command, token;
    while (std::getline(std::cin, command)) {
        if (command == "quit") return 0;
        std::cout << (instance.takeActivationRequest(token) ? "ACTIVATED:" : "IDLE:") << token << std::endl;
    }
}
''')
    compiler = os.environ.get('CXX', 'cl' if os.name == 'nt' else 'c++')
    if Path(compiler).stem.lower() == 'cl':
        args = [compiler, '/nologo', '/std:c++17', '/EHsc', '/W4', '/I' + str(ROOT), str(source),
                '/Fe:' + str(exe), '/link', 'user32.lib', 'advapi32.lib']
    else:
        args = [compiler, '-std=c++17', '-pthread', '-Wall', '-Wextra', '-I', str(ROOT), str(source), '-o', str(exe)]
        if os.name == 'nt':
            args += ['-luser32', '-ladvapi32']
    subprocess.run(args, check=True, cwd=temp)
    name = 'dora-instance-test-' + uuid.uuid4().hex
    notification = 'IDLE:' if sys.platform == 'linux' else 'ACTIVATED:'

    def spawn():
        return subprocess.Popen([str(exe), name], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)

    def command(proc, text):
        proc.stdin.write(text + '\n')
        proc.stdin.flush()
        return proc.stdout.readline().strip()

    def duplicate(token=None):
        env = dict(os.environ)
        env.pop('XDG_ACTIVATION_TOKEN', None)
        if token:
            env['XDG_ACTIVATION_TOKEN'] = token
        result = subprocess.run([str(exe), name], input='', capture_output=True, text=True, env=env, timeout=5)
        assert result.returncode == 0 and result.stdout.strip() == 'EXISTING', result

    owner = spawn()
    try:
        assert owner.stdout.readline().strip() == 'PRIMARY'
        # On activation platforms, requests must survive until the first event poll.
        duplicate()
        assert command(owner, 'poll') == notification
        assert command(owner, 'poll') == 'IDLE:'
        for _ in range(4):
            duplicate()
            assert command(owner, 'poll') == notification
        # Multiple contenders cannot become owners. Poll concurrently to drain
        # the bounded activation queue, as a running GUI would.
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
            futures = [pool.submit(duplicate) for _ in range(24)]
            while not all(f.done() for f in futures):
                command(owner, 'poll')
                time.sleep(.01)
            for future in futures:
                future.result()
        assert owner.poll() is None
        owner.stdin.write('quit\n')
        owner.stdin.flush()
        assert owner.wait(timeout=3) == 0
    finally:
        stop(owner)
    # Normal exit and abrupt death must both allow immediate ownership recovery.
    for crash in (False, True, False):
        owner = spawn()
        try:
            assert owner.stdout.readline().strip() == 'PRIMARY'
            duplicate()
            assert command(owner, 'poll') == notification
            if crash:
                owner.kill()
            else:
                owner.stdin.write('quit\n')
                owner.stdin.flush()
            owner.wait(timeout=3)
        finally:
            stop(owner)
    # Start contenders together with no existing owner, exercising startup races.
    contenders = [spawn() for _ in range(8)]
    try:
        results = [p.stdout.readline().strip() for p in contenders]
        assert results.count('PRIMARY') == 1 and results.count('EXISTING') == 7, results
        primary = contenders[results.index('PRIMARY')]
        assert command(primary, 'poll') == notification
    finally:
        for proc in contenders:
            stop(proc)
    if os.name != 'nt':
        shutil.rmtree('/tmp/' + name + '-' + str(os.geteuid()))
    print('PASS: one GUI owner, repeated/concurrent launch, clean/crash recovery and platform activation policy')
    return exe


def window_tests(temp, library, notifier):
    """Exercise the production activation function against a real SDL window."""
    import sys
    if sys.platform == 'linux':
        print('SKIP: Linux automatic window activation is intentionally disabled for both X11 and Wayland')
        return
    application = (ROOT / 'Source/Basic/Application.cpp').read_text()
    start = application.index('void activateGuiWindow(')
    function = application[start:application.index('\n}', start) + 2]
    source = temp / ('window.mm' if sys.platform == 'darwin' else 'window.cpp')
    exe = temp / ('window.exe' if os.name == 'nt' else 'window')
    if sys.platform == 'darwin':
        import plistlib
        contents = temp / 'WindowTest.app/Contents'
        (contents / 'MacOS').mkdir(parents=True)
        (contents / 'Info.plist').write_bytes(plistlib.dumps({
            'CFBundleExecutable': 'window', 'CFBundleIdentifier': 'org.dora.single-instance-test',
            'CFBundleName': 'Dora Window Test', 'CFBundlePackageType': 'APPL',
        }))
        exe = contents / 'MacOS/window'
    native = ''
    if sys.platform == 'darwin':
        objc = (ROOT / 'Source/Basic/Application.mm').read_text()
        start = objc.index('void activateGuiWindowMac(')
        native = 'namespace Dora {\n' + objc[start:objc.index('\n}', start) + 2] + '\n}\n'
    source.write_text(r'''
#define SDL_MAIN_HANDLED
#include "SDL.h"
#include "Source/Basic/GuiInstance.h"
#include <iostream>
#include "SDL_syswm.h"
#ifdef __APPLE__
#import <Cocoa/Cocoa.h>
#endif
#define BX_PLATFORM_LINUX @IS_LINUX@
#define BX_PLATFORM_OSX @IS_MAC@
#define BX_PLATFORM_WINDOWS @IS_WIN@
NATIVE
ACTIVATE
int main(int, char** argv) {
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 2;
    auto window = SDL_CreateWindow("Dora single-instance window test", 50, 50, 500, 300, SDL_WINDOW_RESIZABLE);
    if (!window) return 3;
    std::cerr << "Native window driver: " << SDL_GetCurrentVideoDriver() << std::endl;
    auto pump = [] {
        SDL_Event event;
        while (SDL_PollEvent(&event)) { }
        SDL_Delay(10);
    };
    Dora::GuiInstance instance(argv[1]);
    if (instance.acquire() != Dora::GuiInstance::Result::Primary) return 4;
    for (int i = 0; i < 50; ++i) pump();
    SDL_MinimizeWindow(window);
    for (int i = 0; i < 200 && !(SDL_GetWindowFlags(window) & SDL_WINDOW_MINIMIZED); ++i) pump();
    if (!(SDL_GetWindowFlags(window) & SDL_WINDOW_MINIMIZED)) return 5;
    for (int i = 0; i < 50; ++i) pump();
    std::cout << "MINIMIZED" << std::endl;
    std::string token;
    bool requested = false;
    for (int i = 0; i < 500 && !requested; ++i) {
        requested = instance.takeActivationRequest(token);
        pump();
    }
    if (!requested) return 6;
    activateGuiWindow(window, token);
    for (int i = 0; i < 300; ++i) {
        pump();
        auto flags = SDL_GetWindowFlags(window);
        if (!(flags & SDL_WINDOW_MINIMIZED) && (flags & SDL_WINDOW_INPUT_FOCUS)) {
            std::cout << "RESTORED_AND_FOCUSED" << std::endl;
            SDL_DestroyWindow(window);
            SDL_Quit();
            return 0;
        }
    }
#ifdef __APPLE__
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    SDL_GetWindowWMInfo(window, &info);
    NSWindow* native = info.info.cocoa.window;
    std::cerr << "native visible=" << [native isVisible] << " mini=" << [native isMiniaturized]
        << " key=" << [native isKeyWindow] << " active=" << [NSApp isActive]
        << " policy=" << [NSApp activationPolicy] << std::endl;
#endif
    std::cerr << "Restoration flags: " << SDL_GetWindowFlags(window) << " SDL error: " << SDL_GetError() << std::endl;
    return 7;
}
'''.replace('ACTIVATE', function).replace('NATIVE', native).replace('@IS_MAC@', '1' if sys.platform == 'darwin' else '0').replace('@IS_WIN@', '1' if os.name == 'nt' else '0').replace('@IS_LINUX@', '1' if sys.platform == 'linux' else '0'))
    compiler = os.environ.get('CXX', 'cl' if os.name == 'nt' else 'c++')
    if Path(compiler).stem.lower() == 'cl':
        args = [compiler, '/nologo', '/std:c++17', '/EHsc',
                '/MTd' if library.parent.name.lower() == 'debug' else '/MT', '/I' + str(ROOT),
                '/I' + str(ROOT / 'Source/3rdParty/SDL2/include'), str(source), str(library),
                '/Fe:' + str(exe), '/link', 'user32.lib', 'gdi32.lib', 'winmm.lib', 'imm32.lib',
                'ole32.lib', 'oleaut32.lib', 'version.lib', 'uuid.lib', 'advapi32.lib',
                'setupapi.lib', 'shell32.lib']
    else:
        args = [compiler, '-std=c++17', '-pthread', '-I', str(ROOT),
                '-I', str(ROOT / 'Source/3rdParty/SDL2/include'), str(source), str(library), '-o', str(exe)]
        if sys.platform == 'darwin':
            for framework in ('Cocoa', 'Carbon', 'IOKit', 'CoreAudio', 'AudioToolbox', 'CoreVideo',
                              'ForceFeedback', 'GameController', 'CoreHaptics', 'Metal'):
                args += ['-framework', framework]
        elif sys.platform == 'linux':
            args += ['-ldl', '-lm', '-lrt', '-lX11']
    subprocess.run(args, check=True, cwd=temp)
    name = 'dora-window-test-' + uuid.uuid4().hex
    proc = subprocess.Popen([str(exe), name], stdout=subprocess.PIPE, text=True)
    try:
        assert proc.stdout.readline().strip() == 'MINIMIZED', proc.wait(timeout=5)
        duplicate = subprocess.run([str(notifier), name], capture_output=True, text=True, timeout=5)
        assert duplicate.returncode == 0 and duplicate.stdout.strip() == 'EXISTING'
        assert proc.stdout.readline().strip() == 'RESTORED_AND_FOCUSED', proc.wait(timeout=5)
        assert proc.wait(timeout=5) == 0
    finally:
        stop(proc)
        if os.name != 'nt':
            shutil.rmtree('/tmp/' + name + '-' + str(os.geteuid()), ignore_errors=True)
    print('PASS: native SDL window was minimized, restored and focused after duplicate launch')


def owned_engine_window(pid):
    """Inspect only the window belonging to the GUI process this test started."""
    import ctypes as c
    import sys
    if os.name == 'nt':
        from ctypes import wintypes as w
        api = c.WinDLL('user32', use_last_error=True)
        callback_type = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
        api.EnumWindows.argtypes = [callback_type, w.LPARAM]
        api.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]
        for name in ('IsWindowVisible', 'IsIconic', 'IsZoomed'):
            getattr(api, name).argtypes = [w.HWND]
        api.ShowWindow.argtypes = [w.HWND, c.c_int]
        api.GetForegroundWindow.restype = w.HWND
        windows = []
        @callback_type
        def visit(window, _):
            process = w.DWORD()
            api.GetWindowThreadProcessId(window, c.byref(process))
            if process.value == pid and api.IsWindowVisible(window):
                windows.append(window)
            return True
        deadline = time.monotonic() + 5
        while not windows:
            api.EnumWindows(visit, 0)
            if windows or time.monotonic() >= deadline:
                break
            time.sleep(.05)
        assert len(windows) == 1, ('expected one visible engine window', windows)
        window = windows[0]
        class Window:
            def minimize(self):
                api.ShowWindow(window, 6)
            def minimized(self):
                return bool(api.IsIconic(window))
            def focused(self):
                return api.GetForegroundWindow() == window
            def close(self):
                pass
        return Window()
    if sys.platform != 'linux' or os.environ.get('SDL_VIDEODRIVER', 'x11') != 'x11':
        return None
    api = c.CDLL('libX11.so.6')
    ulong = c.c_ulong
    display_type = c.c_void_p
    api.XOpenDisplay.argtypes = [c.c_char_p]
    api.XOpenDisplay.restype = display_type
    display = api.XOpenDisplay(None)
    assert display, 'X11 display unavailable'
    api.XDefaultRootWindow.argtypes = [display_type]
    api.XDefaultRootWindow.restype = ulong
    api.XInternAtom.argtypes = [display_type, c.c_char_p, c.c_int]
    api.XInternAtom.restype = ulong
    api.XGetWindowProperty.argtypes = [display_type, ulong, ulong, c.c_long, c.c_long,
        c.c_int, ulong, c.POINTER(ulong), c.POINTER(c.c_int), c.POINTER(ulong),
        c.POINTER(ulong), c.POINTER(c.c_void_p)]
    api.XQueryTree.argtypes = [display_type, ulong, c.POINTER(ulong), c.POINTER(ulong),
        c.POINTER(c.POINTER(ulong)), c.POINTER(c.c_uint)]
    api.XFree.argtypes = [c.c_void_p]
    api.XIconifyWindow.argtypes = [display_type, ulong, c.c_int]
    api.XSync.argtypes = [display_type, c.c_int]
    api.XCloseDisplay.argtypes = [display_type]
    root = api.XDefaultRootWindow(display)
    def prop(window, name):
        atom = api.XInternAtom(display, name.encode(), 0)
        actual, count, remaining, form, data = ulong(), ulong(), ulong(), c.c_int(), c.c_void_p()
        status = api.XGetWindowProperty(display, window, atom, 0, 1024, 0, 0,
            c.byref(actual), c.byref(form), c.byref(count), c.byref(remaining), c.byref(data))
        try:
            if status or form.value != 32 or not data.value:
                return []
            return list(c.cast(data, c.POINTER(ulong))[:count.value])
        finally:
            if data.value:
                api.XFree(data)
    def children(window):
        root_out, parent, data, count = ulong(), ulong(), c.POINTER(ulong)(), c.c_uint()
        if not api.XQueryTree(display, window, c.byref(root_out), c.byref(parent), c.byref(data), c.byref(count)):
            return []
        try:
            return list(data[:count.value])
        finally:
            if data:
                api.XFree(data)
    deadline = time.monotonic() + 5
    while True:
        clients = prop(root, '_NET_CLIENT_LIST') or children(root)
        windows = [window for window in clients if prop(window, '_NET_WM_PID') == [pid]]
        if windows or time.monotonic() >= deadline:
            break
        time.sleep(.05)
    assert len(windows) == 1, ('expected one X11 engine window', windows)
    window = windows[0]
    class Window:
        def minimize(self):
            assert api.XIconifyWindow(display, window, 0)
            api.XSync(display, 0)
        def minimized(self):
            return prop(window, 'WM_STATE')[:1] == [3]
        def focused(self):
            return prop(root, '_NET_ACTIVE_WINDOW') == [window]
        def describe(self):
            return {'window': window, 'wmState': prop(window, 'WM_STATE'), 'activeWindow': prop(root, '_NET_ACTIVE_WINDOW')}
        def close(self):
            api.XCloseDisplay(display)
    return Window()


def engine_tests(engine, temp):
    # This harness owns the real GUI's single-instance namespace, so require a
    # free service port before launch rather than touching an existing process.
    import socket
    for port in (8866, 8868):
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', port))
    profile = temp / 'profile'
    profile.mkdir()
    env = dict(os.environ, HOME=str(profile), CFFIXED_USER_HOME=str(profile), DORA_PORT='8866',
               XDG_DATA_HOME=str(profile / 'data'),
               XDG_CONFIG_HOME=str(profile / 'config'), XDG_CACHE_HOME=str(profile / 'cache'))
    log = (temp / 'engine.log').open('w')
    owner = subprocess.Popen([str(engine), '--asset', str(ROOT / 'Assets')], cwd=ROOT, env=env,
                             stdout=log, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 40
        while True:
            assert owner.poll() is None, (temp / 'engine.log').read_text()
            try:
                with socket.create_connection(('127.0.0.1', 8866), timeout=.2):
                    break
            except OSError:
                assert time.monotonic() < deadline, (temp / 'engine.log').read_text()
                time.sleep(.1)
        window = owned_engine_window(owner.pid)
        if window:
            try:
                if sys.platform == 'linux':
                    window.minimize()
                    deadline = time.monotonic() + 5
                    while not window.minimized():
                        assert time.monotonic() < deadline, 'engine window did not minimize'
                        time.sleep(.05)
                    result = subprocess.run([str(engine)], capture_output=True, text=True, env=env, timeout=5)
                    assert result.returncode == 0 and 'Please use the existing window' in result.stdout, result
                    time.sleep(.2)
                    assert window.minimized(), 'Linux duplicate launch must leave window activation to the user'
                    print('PASS: Linux duplicate launch leaves the existing minimized window unchanged', flush=True)
                else:
                    for attempt in range(5):
                        window.minimize()
                        deadline = time.monotonic() + 5
                        while not window.minimized():
                            assert time.monotonic() < deadline, 'engine window did not minimize'
                            time.sleep(.05)
                        result = subprocess.run([str(engine)], capture_output=True, text=True, env=env, timeout=5)
                        assert result.returncode == 0 and 'Dora GUI is already running' in result.stdout, result
                        deadline = time.monotonic() + 5
                        while window.minimized() or not window.focused():
                            assert time.monotonic() < deadline, ('engine window did not restore and gain foreground focus', window.describe() if hasattr(window, 'describe') else {'minimized':window.minimized(),'focused':window.focused()})
                            time.sleep(.05)
                    print('PASS: actual engine window restored and gained foreground focus in five minimize/relaunch cycles', flush=True)
            finally:
                window.close()
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            def duplicate(_):
                result = subprocess.run([str(engine)], capture_output=True, text=True, env=env, timeout=5)
                assert result.returncode == 0 and 'Dora GUI is already running' in result.stdout, result
                if sys.platform == 'linux':
                    assert 'Please use the existing window' in result.stdout and 'Activation requested' not in result.stdout
            list(pool.map(duplicate, range(12)))
        # Each CLI process writes its own marker before waiting for the shared
        # release file: all must overlap, while the GUI remains alive.
        script = temp / 'cli.lua'
        release = temp / 'release'
        script.write_text('local a = Dora.CLI.args\n'
                          'assert(Dora.CLI.writeFile(a[1], "ready"))\n'
                          'while not Dora.CLI.exists(a[2]) do end\n'
                          'print("CLI completed")\n')
        cli_env = dict(env, DORA_CLI_SCRIPT=str(script))
        markers = [temp / ('cli-' + str(i)) for i in range(4)]
        processes = [subprocess.Popen([str(engine), 'cli', str(m), str(release)], env=cli_env,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for m in markers]
        try:
            deadline = time.monotonic() + 10
            while not all(m.exists() for m in markers):
                assert all(p.poll() is None for p in processes), 'CLI exited before release'
                assert time.monotonic() < deadline, 'CLI processes did not overlap'
                time.sleep(.05)
            assert all(p.poll() is None for p in processes)
            release.write_text('go')
            for proc in processes:
                output, error = proc.communicate(timeout=5)
                assert proc.returncode == 0 and 'CLI completed' in output, (output, error)
        finally:
            for proc in processes:
                stop(proc)
        assert owner.poll() is None
        print('PASS: real GUI duplicates exit with terminal message; four CLI processes overlap beside GUI')
    finally:
        stop(owner)
        log.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=Path)
    parser.add_argument('--sdl-library', type=Path, help='Native SDL static library for a real minimized-window test')
    args = parser.parse_args()
    directory = tempfile.mkdtemp(prefix='dora-instance-')
    try:
        temp = Path(directory)
        notifier = fixture_tests(temp)
        if args.sdl_library:
            window_tests(temp, args.sdl_library.resolve(), notifier)
        if args.engine:
            engine_tests(args.engine.resolve(), temp)
    finally:
        # Windows may retain an image mapping briefly after process exit.
        deadline = time.monotonic() + 3
        while True:
            try:
                shutil.rmtree(directory)
                break
            except PermissionError:
                if time.monotonic() >= deadline:
                    raise
                time.sleep(.05)
