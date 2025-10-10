#!/usr/bin/env python3
"""
sshpass_py.py — python sshpass style wrapper
Robust prompt detection + retry + fail detection.
Usage examples:
  SSH_PASS=secret python3 sshpass_py.py -v -- ssh root@192.168.178.1 ls
  python3 sshpass_py.py -f /path/to/pwfile -- scp local user@host:/remote/
"""
from __future__ import annotations
import os, sys, pty, select, errno, argparse, time

def hexdump(b: bytes) -> str:
    return ' '.join(f'{x:02x}' for x in b)

def parse_args():
    p = argparse.ArgumentParser(description="sshpass style wrapper (python)")
    p.add_argument('-f','--passfile', help='file with password (first line)')
    p.add_argument('-v','--verbose', action='store_true', help='debug hexdump')
    p.add_argument('-r','--retries', type=int, default=2, help='password re-send attempts on re-prompt (default 2)')
    p.add_argument('cmd', nargs=argparse.REMAINDER, help='command to run (optionally prepended by --)')
    return p.parse_args()

def get_password(args):
    if args.passfile:
        try:
            with open(args.passfile, 'r', encoding='utf-8') as f:
                return f.readline().rstrip('\r\n')
        except Exception as e:
            print("cannot read passfile:", e, file=sys.stderr); sys.exit(3)
    if 'SSH_PASS' in os.environ:
        return os.environ['SSH_PASS']
    print("password not provided: set SSH_PASS or -f/--passfile", file=sys.stderr); sys.exit(2)

def is_failure_text(low: bytes) -> bool:
    # common failure patterns (lowercase)
    fails = [b'permission denied', b'authentication failed', b'authentication error', b'login incorrect', b'access denied']
    return any(p in low for p in fails)

def main():
    args = parse_args()
    if not args.cmd:
        print("No command specified. Use: [--] ssh user@host cmd ...", file=sys.stderr); sys.exit(2)
    cmd = args.cmd
    if cmd[0] == '--':
        cmd = cmd[1:]
    password = get_password(args)

    pid, master = pty.fork()
    if pid == 0:
        try:
            os.execvp(cmd[0], cmd)
        except Exception as e:
            print("Exec fallito:", e, file=sys.stderr); os._exit(127)

    rolling = bytearray()
    sent_count = 0
    hostkey_answered = False
    max_retries = max(0, args.retries)
    try:
        while True:
            r, _, _ = select.select([master, sys.stdin.fileno()], [], [])
            if sys.stdin.fileno() in r:
                try:
                    data = os.read(sys.stdin.fileno(), 4096)
                except OSError:
                    data = b''
                if not data:
                    try:
                        os.shutdown(master, 1)
                    except Exception:
                        pass
                else:
                    os.write(master, data)

            if master in r:
                try:
                    data = os.read(master, 4096)
                except OSError as e:
                    if e.errno == errno.EIO:
                        break
                    else:
                        raise
                if not data:
                    break
                # Filtra prompt password dall'output
                filtered = data
                for p in [
                    b'password:',
                    b'passwort:',
                    b'pass:',
                    b"'s password:",
                    b'root password:',
                    b'root@',
                ]:
                    idx = filtered.lower().find(p)
                    while idx != -1:
                        # Cerca newline dopo il prompt
                        end = filtered.find(b'\n', idx)
                        # Cerca newline prima del prompt
                        start = filtered.rfind(b'\n', 0, idx)
                        # Rimuovi anche newline successivi
                        next_nl = end
                        while next_nl != -1 and next_nl+1 < len(filtered) and filtered[next_nl+1:next_nl+2] == b'\n':
                            next_nl += 1
                        if start != -1 and end != -1:
                            filtered = filtered[:start] + filtered[(next_nl+1) if next_nl != -1 else (end+1):]
                        elif end != -1:
                            filtered = filtered[:idx] + filtered[(next_nl+1) if next_nl != -1 else (end+1):]
                        elif start != -1:
                            filtered = filtered[:start]
                        else:
                            filtered = filtered[:idx]
                        idx = filtered.lower().find(p)
                # Rimuovi tutti i caratteri di newline e spazi all'inizio
                while filtered and filtered[:1] in (b'\n', b'\r', b' ', b'\t'):
                    filtered = filtered[1:]
                os.write(sys.stdout.fileno(), filtered)
                if args.verbose:
                    sys.stderr.write("[recv hex] " + hexdump(data) + "\n"); sys.stderr.flush()

                # rolling lower-case buffer
                rolling += data
                if len(rolling) > 4096:
                    rolling = rolling[-4096:]
                low = rolling.lower()

                # host key prompt handling
                if (not hostkey_answered) and b"are you sure you want to continue connecting" in low:
                    os.write(master, b"yes\n"); hostkey_answered = True; rolling = bytearray(); continue
                if (not hostkey_answered) and b"(yes/no)?" in low:
                    os.write(master, b"yes\n"); hostkey_answered = True; rolling = bytearray(); continue

                # detect password prompt robustly: support multiple variants
                if sent_count <= max_retries:
                    prompts = [
                        b'password:',
                        b'passwort:',
                        b'pass:',
                        b"'s password:",
                        b'root password:',
                        b'root@',
                    ]
                    for p in prompts:
                        if p in low:
                            os.write(master, password.encode() + b"\n")
                            sent_count += 1
                            if args.verbose:
                                sys.stderr.write(f"[debug] sent password (attempt {sent_count}) for prompt {p.decode(errors='ignore')}\n"); sys.stderr.flush()
                            rolling = bytearray()
                            break
                    else:
                        # fallback: 'password' + ':' nearby
                        idx = low.find(b'password')
                        if idx != -1:
                            window = low[idx: idx + 64]
                            if b':' in window:
                                os.write(master, password.encode() + b"\n")
                                sent_count += 1
                                if args.verbose:
                                    sys.stderr.write(f"[debug] sent password (attempt {sent_count})\n"); sys.stderr.flush()
                                rolling = bytearray()
                                continue

                # detect explicit auth failure -> exit with code 255
                if is_failure_text(low):
                    if args.verbose:
                        sys.stderr.write("[debug] detected authentication failure text, aborting\n"); sys.stderr.flush()
                    # wait a little to let ssh print final lines
                    time.sleep(0.05)
                    try:
                        _, status = os.waitpid(pid, 0)
                        sys.exit(1)
                    except ChildProcessError:
                        sys.exit(1)
    except KeyboardInterrupt:
        pass
    finally:
        try:
            _, status = os.waitpid(pid, 0)
            if os.WIFEXITED(status):
                sys.exit(os.WEXITSTATUS(status))
            else:
                sys.exit(1)
        except ChildProcessError:
            pass

if __name__ == "__main__":
    main()
