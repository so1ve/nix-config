"""CLI outputs used by Hermes native cron monitors."""

import argparse
import json

from . import campus, lexue, mailbox


def run(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["mail", "mail-index", "lexue", "campus-status"])
    parser.add_argument("--year", type=int)
    parser.add_argument("--month", type=int)
    parser.add_argument("--course", type=int, default=0)
    parser.add_argument("--limit", type=int, default=20)
    args = parser.parse_args(argv)
    if args.command in {"mail", "mail-index"}:
        value = mailbox.list_mail(args.limit, include_content=args.command == "mail")
    elif args.command == "lexue":
        value = {"events": lexue.calendar(args.year, args.month, args.course)}
    else:
        value = {"cookies_present": campus._cookies().is_file()}
    print(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True))


def main():
    run()
