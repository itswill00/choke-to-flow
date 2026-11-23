#!/usr/bin/env python3
"""Copy workspace module files into an already-installed module directory.

Run as root (build.sh handles su). Dirs/files listed below are build-only and
never pushed to the phone.
"""
import os
import shutil
import sys

SKIP_DIRS = {"webui-src", "node_modules", "__pycache__", ".git"}
SKIP_FILES = {"build.sh"}
EXECUTABLES = {
    "service.sh", "boot-completed.sh", "hotinstall.sh",
    "action.sh", "uninstall.sh", "customize.sh", "lib/core.sh",
}


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: sync.py <src> <dst>")
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    if not os.path.isdir(dst):
        print("target belum ada:", dst)
        return 1

    for root, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        rel = os.path.relpath(root, src)
        out = dst if rel == "." else os.path.join(dst, rel)
        os.makedirs(out, exist_ok=True)
        for name in files:
            if name in SKIP_FILES or name.endswith(".zip"):
                continue
            shutil.copy2(os.path.join(root, name), os.path.join(out, name))

    for name in EXECUTABLES:
        path = os.path.join(dst, name)
        if os.path.exists(path):
            os.chmod(path, 0o755)

    moddir = os.path.join(dst, "webroot", "moddir.txt")
    os.makedirs(os.path.dirname(moddir), exist_ok=True)
    with open(moddir, "w") as fh:
        fh.write(dst)

    print("synced:", src, "->", dst)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
