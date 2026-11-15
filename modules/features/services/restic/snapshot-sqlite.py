import argparse
import json
import os
import sqlite3
import stat
from contextlib import closing
from pathlib import Path


def raise_walk_error(error):
    raise error


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    parser.add_argument("export_directory", type=Path)
    parser.add_argument("exclude_file", type=Path)
    args = parser.parse_args()

    config = json.loads(args.config.read_text())
    ignored = set(config["ignoredDirectories"])
    args.export_directory.mkdir()

    with args.exclude_file.open("w") as exclusions:
        for root in config["roots"]:
            for directory, children, files in os.walk(root, onerror=raise_walk_error):
                base = Path(directory)
                children[:] = [name for name in children if str(base / name) not in ignored]
                for name in files:
                    source = base / name
                    if source.suffix.lower() not in {".db", ".sqlite", ".sqlite3"}:
                        continue
                    metadata = source.lstat()
                    if not stat.S_ISREG(metadata.st_mode):
                        continue
                    with source.open("rb") as stream:
                        if stream.read(16) != b"SQLite format 3\0":
                            continue

                    target = args.export_directory / source.relative_to("/")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.touch(mode=0o600, exist_ok=False)
                    with (
                        closing(sqlite3.connect(source.as_uri() + "?mode=ro", uri=True)) as live_db,
                        closing(sqlite3.connect(target)) as backup_db,
                    ):
                        live_db.backup(backup_db)
                    os.chown(target, metadata.st_uid, metadata.st_gid)
                    target.chmod(stat.S_IMODE(metadata.st_mode))

                    for suffix in ("", "-wal", "-shm", "-journal"):
                        pattern = str(source) + suffix
                        for character in ("\\", "*", "?", "["):
                            pattern = pattern.replace(character, "\\" + character)
                        exclusions.write(pattern + "\n")


if __name__ == "__main__":
    main()
