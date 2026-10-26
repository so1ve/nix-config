"""Keep one bounded, interactive review's progress and feedback."""

import argparse
import json
import os
import tempfile
from pathlib import Path

STATUSES = ("pending", "discussing", "revisit", "reviewed", "excluded")


def relative_path(value):
    path = Path(os.path.normpath(value))
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"Use a workspace-relative path: {value}")
    if path == Path("."):
        raise ValueError("A file path is required")
    return path


def load(path):
    state = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(state, dict):
        raise TypeError("The review record must be a JSON object")
    for key in ("goal", "scope", "overview"):
        if not isinstance(state.get(key), str):
            raise TypeError(f"The review record needs a string '{key}'")
    if not isinstance(state.get("files"), list) or not state["files"]:
        raise ValueError("The review record needs a nonempty 'files' list")
    seen = set()
    for item in state["files"]:
        if not isinstance(item, dict) or not isinstance(item.get("path"), str):
            raise TypeError("Each file needs a string 'path'")
        name = str(relative_path(item["path"]))
        if name != item["path"] or name in seen:
            raise ValueError(f"Duplicate or non-normalized file path: {item['path']}")
        seen.add(name)
        if item.get("status") not in STATUSES:
            raise ValueError(f"Unknown file status: {item.get('status')}")
        if not isinstance(item.get("summary"), str):
            raise TypeError(f"Missing summary for {name}")
        if not isinstance(item.get("feedback"), list):
            raise TypeError(f"Missing feedback list for {name}")
        for note in item["feedback"]:
            if not isinstance(note, dict) or not all(
                isinstance(note.get(key), str) for key in ("text", "outcome")
            ):
                raise ValueError(f"Invalid feedback for {name}")
    return state


def save(path, state):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, delete=False
        ) as stream:
            temporary = Path(os.path.relpath(stream.name))
            json.dump(state, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        temporary.replace(path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def find_file(state, value):
    name = str(relative_path(value))
    for item in state["files"]:
        if item["path"] == name:
            return item
    raise ValueError(f"File is outside this review's scope: {name}")


def unresolved(item):
    return sum(not note["outcome"].strip() for note in item["feedback"])


def show(state, selected=None):
    items = state["files"]
    reviewed = sum(item["status"] == "reviewed" for item in items)
    excluded = sum(item["status"] == "excluded" for item in items)
    open_feedback = sum(
        unresolved(item) for item in items if item["status"] != "excluded"
    )
    remaining = [
        item
        for item in items
        if item["status"] != "excluded"
        and (item["status"] != "reviewed" or unresolved(item))
    ]
    print(f"Goal: {state['goal']}\nScope: {state['scope']}")
    print(
        f"Reviewed: {reviewed}/{len(items)}; excluded: {excluded}; "
        f"unresolved feedback: {open_feedback}"
    )
    print("Complete: " + ("yes" if not remaining else "no"))
    print("Next: " + (remaining[0]["path"] if remaining else "none"))
    if state["overview"]:
        print(f"\nOverview: {state['overview']}")
    for item in [selected] if selected is not None else items:
        print(f"\n[{item['status']}] {item['path']}")
        if selected is None:
            continue
        if item["summary"]:
            print(item["summary"])
        for number, note in enumerate(item["feedback"], 1):
            print(f"  {number}. {note['text']}")
            print("     Outcome: " + (note["outcome"] or "unresolved"))


def parser():
    cli = argparse.ArgumentParser(description=__doc__)
    commands = cli.add_subparsers(dest="command", required=True)
    for name in ("init", "show", "overview", "file", "feedback", "decide"):
        sub = commands.add_parser(name)
        sub.add_argument("--state", required=True, help="Workspace-relative JSON file")
        if name == "init":
            sub.add_argument("--goal", required=True)
            sub.add_argument("--scope", required=True)
            sub.add_argument("--files", nargs="+", required=True)
        elif name == "overview":
            sub.add_argument("--text", required=True)
        elif name == "show":
            sub.add_argument("--path", help="Show one file's summary and feedback")
        else:
            sub.add_argument("--path", required=True)
            if name == "file":
                sub.add_argument("--status", choices=STATUSES, required=True)
                sub.add_argument("--summary")
            elif name == "feedback":
                sub.add_argument("--text", required=True)
            else:
                sub.add_argument("--number", type=int, required=True)
                sub.add_argument("--outcome", required=True)
    return cli


def run(args):
    path = relative_path(args.state)
    if not path.resolve().is_relative_to(Path.cwd().resolve()):
        raise ValueError("The review record must stay inside the workspace")
    selected = None
    if args.command == "init":
        names = list(dict.fromkeys(str(relative_path(p)) for p in args.files))
        if str(path) in names:
            raise ValueError("The review record cannot be a target file")
        state = {
            "goal": args.goal,
            "scope": args.scope,
            "overview": "",
            "files": [
                {"path": name, "status": "pending", "summary": "", "feedback": []}
                for name in names
            ],
        }
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("x", encoding="utf-8") as stream:
            json.dump(state, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
    else:
        state = load(path)
        if args.command == "show":
            show(state, find_file(state, args.path) if args.path else None)
            return
        if args.command == "overview":
            state["overview"] = args.text
        else:
            item = find_file(state, args.path)
            selected = item
            if args.command == "file":
                if args.status == "reviewed" and unresolved(item):
                    raise ValueError("Record an outcome for unresolved feedback first")
                if args.status == "excluded" and not (args.summary or "").strip():
                    raise ValueError(
                        "Excluding a file requires the user's reason in --summary"
                    )
                item["status"] = args.status
                if args.summary is not None:
                    item["summary"] = args.summary
            elif args.command == "feedback":
                if not args.text.strip():
                    raise ValueError("Feedback cannot be blank")
                item["feedback"].append({"text": args.text, "outcome": ""})
                if item["status"] == "reviewed":
                    item["status"] = "revisit"
            else:
                if not 1 <= args.number <= len(item["feedback"]):
                    raise ValueError("Feedback number does not exist in this file")
                if not args.outcome.strip():
                    raise ValueError("An outcome cannot be blank")
                item["feedback"][args.number - 1]["outcome"] = args.outcome
        save(path, state)
    show(state, selected)


def main():
    cli = parser()
    args = cli.parse_args()
    try:
        run(args)
    except (OSError, TypeError, ValueError) as error:
        cli.exit(1, f"Review record {args.state}: {error}\n")


if __name__ == "__main__":
    main()
