#!/usr/bin/env python3
"""Просмотр и обслуживание очереди требований в backlog/."""
import argparse
import datetime
import re
import sys
from pathlib import Path

BACKLOG = Path(__file__).resolve().parent.parent / "backlog"
STATUSES = ["in-progress", "testing", "analyzed", "new", "deferred", "done", "rejected"]
CLOSED = {"done", "rejected"}
PRIORITY = {"high": 0, "medium": 1, "low": 2}


def load():
    items = []
    for path in sorted(BACKLOG.glob("[0-9]*.md")):
        text = path.read_text()
        match = re.match(r"---\n(.*?)\n---\n", text, re.S)
        if not match:
            continue
        meta = dict(line.split(":", 1) for line in match.group(1).splitlines() if ":" in line)
        meta = {k.strip(): v.strip() for k, v in meta.items()}
        meta["path"] = path
        items.append(meta)
    return items


def sort_key(item):
    return (STATUSES.index(item.get("status", "new")) if item.get("status") in STATUSES else 99,
            PRIORITY.get(item.get("priority"), 9), item.get("id", ""))


def cmd_list(args):
    items = load()
    if not args.all:
        items = [i for i in items if i.get("status") not in CLOSED]
    for field in ("status", "group", "priority"):
        wanted = getattr(args, field)
        if wanted:
            items = [i for i in items if i.get(field) in wanted.split(",")]
    items.sort(key=sort_key)
    if not items:
        print("Очередь пуста.")
        return
    print("| id | статус | приоритет | группа | размер | название |")
    print("|---|---|---|---|---|---|")
    for i in items:
        print(f"| {i.get('id')} | {i.get('status')} | {i.get('priority')} | {i.get('group')} | {i.get('size', '?')} | {i.get('title')} |")
    counts = {}
    for i in load():
        counts[i.get("status")] = counts.get(i.get("status"), 0) + 1
    print("\n" + ", ".join(f"{s}: {counts[s]}" for s in STATUSES if s in counts))


def find(item_id):
    for i in load():
        if i.get("id") == item_id.zfill(3):
            return i
    sys.exit(f"Требование {item_id} не найдено")


def cmd_show(args):
    for item_id in args.ids:
        print(find(item_id)["path"].read_text())


def cmd_next_id(_args):
    ids = [int(i["id"]) for i in load() if i.get("id", "").isdigit()]
    print(f"{max(ids, default=0) + 1:03d}")


def cmd_set(args):
    today = datetime.date.today().isoformat()
    for item_id in args.ids:
        item = find(item_id)
        text = item["path"].read_text()
        head, body = text.split("\n---\n", 1)
        head = re.sub(rf"^{args.field}:.*$", f"{args.field}: {args.value}", head, flags=re.M) \
            if re.search(rf"^{args.field}:", head, re.M) else head + f"\n{args.field}: {args.value}"
        head = re.sub(r"^updated:.*$", f"updated: {today}", head, flags=re.M)
        item["path"].write_text(head + "\n---\n" + body)
        print(f"{item['id']}: {args.field} = {args.value}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd")

    p = sub.add_parser("list", help="таблица очереди (по умолчанию без закрытых)")
    p.add_argument("--all", action="store_true", help="включая done и rejected")
    p.add_argument("--status", help="фильтр, через запятую")
    p.add_argument("--group", help="фильтр, через запятую")
    p.add_argument("--priority", help="фильтр, через запятую")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("show", help="полный текст требований")
    p.add_argument("ids", nargs="+")
    p.set_defaults(func=cmd_show)

    p = sub.add_parser("next-id", help="номер для нового требования")
    p.set_defaults(func=cmd_next_id)

    p = sub.add_parser("set", help="изменить поле: set status testing 3 4")
    p.add_argument("field")
    p.add_argument("value")
    p.add_argument("ids", nargs="+")
    p.set_defaults(func=cmd_set)

    args = parser.parse_args()
    if not args.cmd:
        args = parser.parse_args(["list"])
    args.func(args)


if __name__ == "__main__":
    main()
