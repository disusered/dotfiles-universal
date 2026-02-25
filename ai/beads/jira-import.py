#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["markdownify"]
# ///
"""Convert Jira XML (RSS) export to Beads JSONL for import via `bd import`."""

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

from markdownify import markdownify as md

TYPE_MAP = {
    "Task": "task",
    "Bug": "bug",
    "Story": "feature",
    "Epic": "epic",
    "Sub-task": "task",
}

PRIORITY_MAP = {
    "Critical": 0,
    "Highest": 0,
    "High": 1,
    "Medium": 2,
    "Low": 3,
    "Lowest": 4,
}

STATUS_CATEGORY_MAP = {
    "new": "open",
    "indeterminate": "in_progress",
    "done": "closed",
    "undefined": "open",
}


def parse_jira_date(date_str):
    """Parse Jira date string to ISO 8601 UTC."""
    # Jira uses: "Mon, 1 Jan 2024 12:00:00 +0000" or similar RFC 2822
    for fmt in (
        "%a, %d %b %Y %H:%M:%S %z",
        "%Y-%m-%dT%H:%M:%S.%f%z",
        "%Y-%m-%dT%H:%M:%S%z",
    ):
        try:
            dt = datetime.strptime(date_str.strip(), fmt)
            return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        except ValueError:
            continue
    return date_str.strip()


def extract_links(item):
    """Extract issue link descriptions from an item."""
    links = []
    for link in item.findall("issuelinks/issuelinktype"):
        link_name = link.findtext("name", "")
        for direction in ("inwardlinks", "outwardlinks"):
            dir_el = link.find(direction)
            if dir_el is None:
                continue
            desc = dir_el.get("description", direction)
            for issue_link in dir_el.findall("issuelink"):
                key = issue_link.findtext("issuekey", "?")
                links.append(f"{desc} {key}")
    return links


def extract_sprint_labels(item):
    """Extract sprint names from customfields."""
    labels = []
    for cf in item.findall("customfields/customfield"):
        name_el = cf.find("customfieldname")
        if name_el is not None and name_el.text == "Sprint":
            for val in cf.findall("customfieldvalues/customfieldvalue"):
                if val.text:
                    labels.append(val.text.strip())
    return labels


def convert_item(item):
    """Convert a single Jira XML item to a beads JSONL dict."""
    key = item.findtext("key", "")
    summary = item.findtext("summary", "")

    # Description: HTML -> Markdown
    desc_html = item.findtext("description", "")
    description = md(desc_html).strip() if desc_html else ""

    # Type mapping
    raw_type = item.findtext("type", "Task")
    issue_type = TYPE_MAP.get(raw_type, "task")

    # Priority mapping
    raw_priority = item.findtext("priority", "Medium")
    priority = PRIORITY_MAP.get(raw_priority, 2)

    # Status mapping via statusCategory attribute
    status_el = item.find("status")
    if status_el is not None:
        status_cat = status_el.get("statusCategory", "undefined")
    else:
        status_cat = "undefined"
    status = STATUS_CATEGORY_MAP.get(status_cat, "open")

    # People
    assignee_el = item.find("assignee")
    owner = assignee_el.text if assignee_el is not None and assignee_el.text else None

    reporter_el = item.find("reporter")
    created_by = (
        reporter_el.text if reporter_el is not None and reporter_el.text else None
    )

    # Dates
    created_at = parse_jira_date(item.findtext("created", ""))
    updated_at = parse_jira_date(item.findtext("updated", ""))

    # Labels
    labels = [l.text for l in item.findall("labels/label") if l.text]
    labels.extend(extract_sprint_labels(item))

    record = {
        "external_ref": key,
        "title": summary,
        "description": description,
        "issue_type": issue_type,
        "priority": priority,
        "status": status,
        "created_at": created_at,
        "updated_at": updated_at,
    }

    if owner:
        record["owner"] = owner
    if created_by:
        record["created_by"] = created_by
    if labels:
        record["labels"] = labels

    return record, key


def main():
    parser = argparse.ArgumentParser(
        description="Convert Jira XML (RSS) export to Beads JSONL.",
        epilog="example: jira-import export.xml | bd import",
    )
    parser.add_argument(
        "file",
        nargs="?",
        type=argparse.FileType("r"),
        default=None,
        help="Jira XML file (default: stdin)",
    )
    parser.add_argument(
        "--no-links",
        action="store_true",
        help="suppress issue link summary on stderr",
    )
    args = parser.parse_args()

    if args.file:
        xml_data = args.file.read()
    elif not sys.stdin.isatty():
        xml_data = sys.stdin.read()
    else:
        parser.print_help(sys.stderr)
        raise SystemExit(1)

    if not xml_data.strip():
        print("error: empty input", file=sys.stderr)
        raise SystemExit(1)

    try:
        root = ET.fromstring(xml_data)
    except ET.ParseError as e:
        print(f"error: invalid XML: {e}", file=sys.stderr)
        raise SystemExit(1)
    channel = root.find("channel")
    items = channel.findall("item") if channel is not None else root.findall(".//item")

    all_links = []

    for item in items:
        record, key = convert_item(item)
        print(json.dumps(record))

        links = extract_links(item)
        for link_desc in links:
            all_links.append(f"{key} {link_desc}")

    if all_links and not args.no_links:
        print("\n--- Issue Links (informational) ---", file=sys.stderr)
        for link in all_links:
            print(link, file=sys.stderr)


if __name__ == "__main__":
    main()
