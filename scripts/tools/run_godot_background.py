"""Render Godot on a private Windows desktop, without touching the input desktop.

Usage: python scripts/tools/run_godot_background.py --godot <exe> --log <file>
       -- <Godot arguments, including --path and capture scene>
The scene reads its real GPU viewport. This tool never calls SwitchDesktop.
"""
import argparse
import ctypes
from ctypes import wintypes
import json
import msvcrt
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--log', required=True, type=Path)
    parser.add_argument('--timeout', type=float, default=240)
    parser.add_argument('args', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if sys.platform != 'win32':
        parser.error('private desktops are Windows-only')
    if not args.godot.is_file():
        parser.error('Godot executable does not exist')
    godot = args.godot.resolve()
    # Official _console.exe is a launcher: monitor/terminate the engine itself.
    if godot.name.lower().endswith('_console.exe'):
        engine = godot.with_name(godot.name[:-len('_console.exe')] + '.exe')
        if not engine.is_file():
            parser.error('pass the engine executable, not a console launcher')
        godot = engine
    child_args = args.args[1:] if args.args[:1] == ['--'] else args.args
    if '--headless' in child_args or '--always-on-top' in child_args:
        parser.error('use ordinary headless execution or omit --always-on-top')
    if '--' not in child_args:
        child_args.append('--')
    child_args.append('--background-capture')

    user = ctypes.WinDLL('user32', use_last_error=True)
    user.CreateDesktopW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR, ctypes.c_void_p,
                                   wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p]
    user.CreateDesktopW.restype = wintypes.HANDLE
    user.CloseDesktop.argtypes = [wintypes.HANDLE]
    user.GetForegroundWindow.restype = wintypes.HWND
    user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    enum_proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user.EnumDesktopWindows.argtypes = [wintypes.HANDLE, enum_proc, wintypes.LPARAM]
    user.GetUserObjectInformationW.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p,
                                             wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]

    def desktop_name(handle):
        buffer = ctypes.create_unicode_buffer(256)
        needed = wintypes.DWORD()
        if not user.GetUserObjectInformationW(handle, 2, buffer, ctypes.sizeof(buffer), ctypes.byref(needed)):
            return ''
        return buffer.value

    class StartupInfo(ctypes.Structure):
        _fields_ = [('cb', wintypes.DWORD), ('reserved', wintypes.LPWSTR), ('desktop', wintypes.LPWSTR),
                    ('title', wintypes.LPWSTR), ('x', wintypes.DWORD), ('y', wintypes.DWORD),
                    ('width', wintypes.DWORD), ('height', wintypes.DWORD), ('xchars', wintypes.DWORD),
                    ('ychars', wintypes.DWORD), ('fill', wintypes.DWORD), ('flags', wintypes.DWORD),
                    ('show', wintypes.WORD), ('reserved_size', wintypes.WORD), ('reserved_ptr', ctypes.c_void_p),
                    ('stdin', wintypes.HANDLE), ('stdout', wintypes.HANDLE), ('stderr', wintypes.HANDLE)]

    class ProcessInfo(ctypes.Structure):
        _fields_ = [('process', wintypes.HANDLE), ('thread', wintypes.HANDLE),
                    ('pid', wintypes.DWORD), ('tid', wintypes.DWORD)]

    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.CreateProcessW.argtypes = [wintypes.LPCWSTR, wintypes.LPWSTR, ctypes.c_void_p, ctypes.c_void_p,
                                     wintypes.BOOL, wintypes.DWORD, ctypes.c_void_p, wintypes.LPCWSTR,
                                     ctypes.POINTER(StartupInfo), ctypes.POINTER(ProcessInfo)]
    kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    kernel.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    name = f'CodexGodotCapture_{time.time_ns()}'
    desktop = user.CreateDesktopW(name, None, None, 0, 0x01FF, None)
    if not desktop:
        raise ctypes.WinError(ctypes.get_last_error())
    # Only the child runs on this desktop. This process stays on the user's
    # desktop to monitor the actual interactive foreground window.
    # CPython's subprocess.STARTUPINFO ignores a dynamically assigned lpDesktop.
    # Call CreateProcessW with the real native structure instead.
    startup = StartupInfo()
    startup.cb = ctypes.sizeof(startup)
    startup.desktop = name
    startup.flags = 0x0101  # USESTDHANDLES | USESHOWWINDOW
    startup.show = 0
    foreground_samples = 0
    samples = 0
    process = ProcessInfo()
    started = time.monotonic()
    args.log.parent.mkdir(parents=True, exist_ok=True)
    try:
        with args.log.open('w', encoding='utf-8') as output, open(os.devnull, 'r') as empty:
            startup.stdin = msvcrt.get_osfhandle(empty.fileno())
            startup.stdout = startup.stderr = msvcrt.get_osfhandle(output.fileno())
            os.set_handle_inheritable(startup.stdin, True)
            os.set_handle_inheritable(startup.stdout, True)
            command = ctypes.create_unicode_buffer(subprocess.list2cmdline([str(godot), '--windowed', *child_args]))
            if not kernel.CreateProcessW(str(godot), command, None, None, True, 0x08000000,
                                         None, str(Path.cwd()), ctypes.byref(startup), ctypes.byref(process)):
                raise ctypes.WinError(ctypes.get_last_error())
            private_windows = []

            @enum_proc
            def find_engine_window(hwnd, _param):
                owner = wintypes.DWORD()
                user.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
                if owner.value == process.pid:
                    private_windows.append(hwnd)
                return True

            # Verify real engine windows on the private desktop. Godot creates
            # its GUI on another thread, so the primary thread is insufficient.
            deadline = time.monotonic() + 5
            while not private_windows and time.monotonic() < deadline and kernel.WaitForSingleObject(process.process, 0) == 0x0102:
                user.EnumDesktopWindows(desktop, find_engine_window, 0)
                time.sleep(0.01)
            actual_desktop = desktop_name(desktop) if private_windows else ''
            if actual_desktop != name:
                raise RuntimeError(f'No engine window on private desktop {name}')
            while kernel.WaitForSingleObject(process.process, 0) == 0x0102:
                pid = wintypes.DWORD()
                user.GetWindowThreadProcessId(user.GetForegroundWindow(), ctypes.byref(pid))
                samples += 1
                if pid.value == process.pid:
                    foreground_samples += 1
                if time.monotonic() - started > args.timeout:
                    raise TimeoutError('Godot capture exceeded timeout')
                time.sleep(0.02)
            exit_code = wintypes.DWORD()
            kernel.GetExitCodeProcess(process.process, ctypes.byref(exit_code))
            report = {'engine': str(godot), 'pid': process.pid, 'private_desktop': name, 'verified_desktop': actual_desktop,
                      'foreground_samples': foreground_samples, 'samples': samples,
                      'exit_code': exit_code.value, 'elapsed_seconds': time.monotonic() - started}
            args.log.with_suffix('.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
            print(f'GODOT_BACKGROUND exit={exit_code.value} foreground_samples={foreground_samples} '
                  f'samples={samples} desktop={name} engine={godot.name} log={args.log}')
            return exit_code.value if foreground_samples == 0 else 8
    finally:
        if process.process:
            if kernel.WaitForSingleObject(process.process, 0) == 0x0102:
                kernel.TerminateProcess(process.process, 1)
                kernel.WaitForSingleObject(process.process, 10000)
            kernel.CloseHandle(process.process)
            kernel.CloseHandle(process.thread)
        user.CloseDesktop(desktop)


if __name__ == '__main__':
    raise SystemExit(main())
