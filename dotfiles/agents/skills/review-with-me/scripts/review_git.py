"""Read reviewable files without changing Git's index, refs, or history."""

import difflib
import os
import subprocess
from pathlib import Path, PurePosixPath

MAX_BYTES = 2_000_000


def git(repo, *args):
    result = subprocess.run(
        ["git", "--no-pager", *args],
        cwd=repo,
        capture_output=True,
        check=False,
        env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"},
    )
    if result.returncode:
        raise ValueError(result.stderr.decode("utf-8", "replace").strip())
    return result.stdout


def path_name(value):
    if not isinstance(value, str) or not value or "\0" in value:
        raise ValueError("文件路径不能为空")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or ".git" in path.parts:
        raise ValueError("请使用仓库内的相对路径")
    return path.as_posix()


def commit(repo, ref):
    return (
        git(repo, "rev-parse", "--verify", "--end-of-options", f"{ref}^{{commit}}")
        .decode()
        .strip()
    )


def repository(cwd):
    return git(cwd, "rev-parse", "--show-toplevel").decode().strip()


def content(data, mode):
    if len(data) > MAX_BYTES:
        return {
            "text": None,
            "mode": mode,
            "size": len(data),
            "notice": "文件超过 2 MB，请在编辑器中审阅",
        }
    try:
        text = data.decode("utf-8") if b"\0" not in data else None
    except UnicodeDecodeError:
        text = None
    return {
        "text": text,
        "mode": mode,
        "size": len(data),
        "notice": "二进制文件" if text is None else "",
    }


def at_commit(repo, ref, path):
    entry = git(repo, "--literal-pathspecs", "ls-tree", "-z", ref, "--", path)
    if not entry:
        return None
    metadata, name = entry.split(b"\t", 1)
    if name.rstrip(b"\0").decode() != path:
        return None
    mode, kind, oid = metadata.decode().split()
    if kind == "commit":
        return content((oid + "\n").encode(), mode)
    if kind != "blob":
        return None
    size = int(git(repo, "cat-file", "-s", oid))
    if size > MAX_BYTES:
        return {
            "text": None,
            "mode": mode,
            "size": size,
            "notice": "文件超过 2 MB，请在编辑器中审阅",
        }
    return content(git(repo, "cat-file", "blob", oid), mode)


def at_worktree(repo, path):
    root = Path(repo).resolve()
    target = root / path
    # A symlink itself is reviewable; its target must never be read.
    if not target.parent.resolve().is_relative_to(root):
        raise ValueError(f"路径经过仓库外的符号链接：{path}")
    if target.is_symlink():
        return content(os.readlink(target).encode(), "120000")
    if not target.exists():
        return None
    if target.is_dir():
        if (target / ".git").exists():
            return content((commit(target, "HEAD") + "\n").encode(), "160000")
        raise ValueError(f"需要文件路径，不能直接读取目录：{path}")
    details = target.stat()
    mode = "100755" if details.st_mode & 0o111 else "100644"
    if details.st_size > MAX_BYTES:
        return {
            "text": None,
            "mode": mode,
            "size": details.st_size,
            "notice": "文件超过 2 MB，请在编辑器中审阅",
        }
    return content(target.read_bytes(), mode)


def in_scope(path, scope):
    return not scope or any(
        item == "." or path == item or path.startswith(item.rstrip("/") + "/")
        for item in scope
    )


def capture_files(repo, base, head, scope, include, state_path):
    args = [
        "--literal-pathspecs",
        "diff",
        "--name-status",
        "-z",
        "--find-renames",
        base,
    ]
    if head != "WORKTREE":
        head = commit(repo, head)
        args.append(head)
    parts = git(repo, *args, "--", *scope).split(b"\0")
    entries = {}
    i = 0
    while i < len(parts) and parts[i]:
        status, path = parts[i].decode(), parts[i + 1].decode()
        i += 2
        old_path = path
        if status[0] in "RC":
            path = parts[i].decode()
            i += 1
        entries[path] = old_path
    if head == "WORKTREE":
        untracked = git(
            repo,
            "--literal-pathspecs",
            "ls-files",
            "--others",
            "--exclude-standard",
            "-z",
            "--",
            *scope,
        )
        for path in untracked.split(b"\0"):
            if path:
                entries[path.decode()] = path.decode()
    for path in include:
        path = path_name(path)
        if not in_scope(path, scope):
            raise ValueError(f"文件不在本次审阅范围内：{path}")
        entries.setdefault(path, path)
    state_relative = (
        Path(state_path).resolve().relative_to(Path(repo).resolve()).as_posix()
    )
    result = {}
    for path, old_path in sorted(entries.items()):
        path_name(path)
        if path.startswith(".review/") or path in (
            state_relative,
            state_relative + ".lock",
        ):
            continue
        before = at_commit(repo, base, old_path)
        after = (
            at_worktree(repo, path)
            if head == "WORKTREE"
            else at_commit(repo, head, path)
        )
        if before is None and after is None:
            raise ValueError(f"文件不存在：{path}")
        result[path] = {
            "path": path,
            "old_path": old_path,
            "old": before,
            "new": after,
            "status": "added"
            if before is None
            else "deleted"
            if after is None
            else "renamed"
            if path != old_path
            else "modified"
            if before != after
            else "context",
        }
    return result


def blocks(file):
    before, after = file["old"], file["new"]
    if any(side and side["text"] is None for side in (before, after)):
        return []
    old = before["text"].splitlines(keepends=True) if before else []
    new = after["text"].splitlines(keepends=True) if after else []
    return [
        {
            "id": str(index),
            "old_start": a + 1,
            "old_count": b - a,
            "new_start": c + 1,
            "new_count": d - c,
        }
        for index, (tag, a, b, c, d) in enumerate(
            difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes()
        )
        if tag != "equal"
    ]


def comparison(state, revision_id=None, against="base"):
    revisions = state["revisions"]
    revision = (
        next((r for r in revisions if r["id"] == revision_id), None)
        if revision_id
        else revisions[-1]
        if revisions
        else None
    )
    if revision is None:
        raise ValueError("找不到该版本，请先 capture")
    if against == "base":
        return revision, revision["files"]
    previous = next((r for r in revisions if r["id"] == against), None)
    if previous is None:
        raise ValueError("找不到对比版本")
    files = {}
    for path in revision["files"].keys() | previous["files"].keys():
        current = revision["files"].get(path)
        older = previous["files"].get(path)
        before = older["new"] if older else current["old"]
        after = current["new"] if current else older["old"]
        if before != after:
            files[path] = {
                "path": path,
                "old_path": path,
                "old": before,
                "new": after,
                "status": "added"
                if before is None
                else "deleted"
                if after is None
                else "modified",
            }
    return revision, files
