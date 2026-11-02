"""CLI for review-with-me. All commands emit JSON except the local server."""

import argparse
import json
import sys
from pathlib import Path

from review_model import inbox, initialize, mutate, read, view


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in (
        "init",
        "capture",
        "show",
        "diff",
        "apply",
        "inbox",
        "serve",
        "import",
    ):
        sub = commands.add_parser(name)
        sub.add_argument(
            "--state", required=True, help="仓库内的相对路径，例如 .review/auth.json"
        )
        if name == "init":
            sub.add_argument("--title", required=True)
            sub.add_argument("--base", default="HEAD")
            sub.add_argument("--paths", nargs="*", default=[])
        elif name == "capture":
            sub.add_argument("--label", required=True)
            sub.add_argument("--head", default="WORKTREE")
            sub.add_argument("--include", nargs="*", default=[])
        elif name in ("show", "diff"):
            sub.add_argument("--revision")
            sub.add_argument("--against", default="base")
            sub.add_argument("--path")
        elif name == "apply":
            source = sub.add_mutually_exclusive_group(required=True)
            source.add_argument("--json", help="一个操作或原子批量操作数组")
            source.add_argument("--input", help="JSON 文件；- 表示标准输入")
        elif name == "inbox":
            sub.add_argument("--claim", action="store_true")
        elif name == "serve":
            sub.add_argument("--port", type=int, default=0)
        elif name == "import":
            sub.add_argument("--from", dest="source", required=True)
    args = parser.parse_args()
    try:
        if args.command == "init":
            result = initialize(args.state, args.title, args.base, args.paths)
        elif args.command == "capture":
            result = mutate(
                args.state,
                {
                    "op": "capture",
                    "label": args.label,
                    "head": args.head,
                    "include": args.include,
                },
            )
        elif args.command in ("show", "diff"):
            result = view(
                read(args.state),
                args.revision,
                args.against,
                with_text=args.command == "diff",
            )
            if args.path:
                result["files"] = [f for f in result["files"] if f["path"] == args.path]
        elif args.command == "apply":
            data = (
                args.json
                if args.json is not None
                else sys.stdin.read()
                if args.input == "-"
                else Path(args.input).read_text()
            )
            result = mutate(args.state, json.loads(data))
        elif args.command == "inbox":
            result = inbox(args.state, args.claim)
        elif args.command == "import":
            from review_import import import_legacy

            result = import_legacy(args.source, args.state)
        else:
            from review_server import serve

            serve(args.state, args.port)
            return
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except (ValueError, OSError, KeyError, TypeError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
