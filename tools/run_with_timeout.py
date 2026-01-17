#!/usr/bin/env python3
import argparse, os, signal, subprocess, sys, time
from pathlib import Path

def kill_proc_tree(proc: subprocess.Popen):
    try:
        pgid = os.getpgid(proc.pid)
        os.killpg(pgid, signal.SIGKILL)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass

def run(cmd, timeout, log_path, cwd=None):
    Path(log_path).parent.mkdir(parents=True, exist_ok=True)
    start = time.time()
    with open(log_path, "w", encoding="utf-8") as f:
        f.write(f"CMD: {' '.join(cmd)}\n")
        f.write(f"CWD: {cwd or os.getcwd()}\n")
        f.write(f"TIMEOUT: {timeout}s\n")
        f.write("---- OUTPUT ----\n")
        f.flush()

        proc = subprocess.Popen(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True,
            preexec_fn=os.setsid if hasattr(os, "setsid") else None,
        )

        try:
            for line in iter(proc.stdout.readline, ""):
                sys.stdout.write(line)
                f.write(line)
                f.flush()
                if time.time() - start > timeout:
                    f.write("\n---- TIMEOUT ----\n")
                    f.flush()
                    kill_proc_tree(proc)
                    return 124
            proc.wait(timeout=max(1, int(timeout - (time.time() - start))))
            code = proc.returncode if proc.returncode is not None else 1
            f.write(f"\n---- EXIT {code} ----\n")
            f.flush()
            return code
        except subprocess.TimeoutExpired:
            f.write("\n---- TIMEOUT (wait) ----\n")
            f.flush()
            kill_proc_tree(proc)
            return 124
        finally:
            try:
                if proc.stdout:
                    proc.stdout.close()
            except Exception:
                pass

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--log", required=True)
    ap.add_argument("--cwd", default=None)
    # Parse up to -- then treat rest as command
    import sys
    if "--" not in sys.argv:
        print("No -- separator found", file=sys.stderr)
        return 2
    idx = sys.argv.index("--")
    # Parse known args up to --
    args = ap.parse_args(sys.argv[1:idx])
    # Everything after -- is the command
    cmd = sys.argv[idx+1:]
    if not cmd:
        print("No command provided after --", file=sys.stderr)
        return 2
    return run(cmd, args.timeout, args.log, cwd=args.cwd)

if __name__ == "__main__":
    raise SystemExit(main())
