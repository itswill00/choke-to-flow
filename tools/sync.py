#!/usr/bin/env python3
"""Copy workspace module files into an already-installed module directory.

Run as root (build.sh handles su). Dirs/files listed below are build-only and
never pushed to the phone.
"""
import os
import shutil
import sys

SKIP_DIRS = {"webui-src", "node_modules", "__pycache__", ".git", ".github", "tests", "tools", "state"}
SKIP_FILES = {"build.sh", "README.md", "ROADMAP.md", "CHANGELOG.md", "LICENSE", ".gitignore"}
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

    # webroot/ is pure build output: replace it so stale hashed assets vanish.
    web_dst = os.path.join(dst, "webroot")
    if os.path.isdir(web_dst):
        shutil.rmtree(web_dst)

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

    # Runtime state is per-device. Never copy the workspace's header-only files
    # over an installed baseline/touched list.
    state_dir = os.path.join(dst, "state")
    os.makedirs(state_dir, exist_ok=True)
    for name, header in (
        ("targets.tsv", "# key\tpath\tkind\n"),
        ("baseline.tsv", "# key\tvalue\n"),
        ("touched.tsv", "# key\toriginal\n"),
        ("last_apply.tsv", "# key\tstatus\trequested\tactual\n"),
    ):
        path = os.path.join(state_dir, name)
        if not os.path.exists(path):
            with open(path, "w") as fh:
                fh.write(header)
        os.chmod(path, 0o644)
    cfg = os.path.join(state_dir, "config.tsv")
    if not os.path.exists(cfg):
        shutil.copy2(os.path.join(dst, "defaults", "config.tsv"), cfg)
    os.chmod(cfg, 0o644)

    moddir = os.path.join(dst, "webroot", "moddir.txt")
    os.makedirs(os.path.dirname(moddir), exist_ok=True)
    with open(moddir, "w") as fh:
        fh.write(dst)

    print("synced:", src, "->", dst)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
