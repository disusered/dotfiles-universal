#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["markdownify"]
# ///
"""Convert Jira XML (RSS) export to Markdown for `bd create --file` or standalone use."""

import argparse
import json
import subprocess
import sys
import tempfile
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
    """Convert a single Jira XML item to markdown and extract its key."""
    key = item.findtext("key", "")
    summary = item.findtext("summary", "")

    desc_el = item.find("description")
    if desc_el is not None:
        # findtext() misses HTML parsed as XML child elements; serialize inner content
        inner = (desc_el.text or "") + "".join(
            ET.tostring(child, encoding="unicode") for child in desc_el
        )
        description = md(inner).strip() if inner.strip() else ""
    else:
        description = ""

    raw_type = item.findtext("type", "Task")
    issue_type = TYPE_MAP.get(raw_type, "task")

    raw_priority = item.findtext("priority", "Medium")
    priority = PRIORITY_MAP.get(raw_priority, 2)

    # statusCategory can be an attribute on <status> or a sibling element
    status_cat_el = item.find("statusCategory")
    if status_cat_el is not None:
        status_cat = status_cat_el.get("key", "undefined")
    else:
        status_el = item.find("status")
        status_cat = status_el.get("statusCategory", "undefined") if status_el is not None else "undefined"
    status = STATUS_CATEGORY_MAP.get(status_cat, "open")

    assignee_el = item.find("assignee")
    assignee = assignee_el.text if assignee_el is not None and assignee_el.text else None

    reporter_el = item.find("reporter")
    created_by = (
        reporter_el.text if reporter_el is not None and reporter_el.text else None
    )

    created_at = parse_jira_date(item.findtext("created", ""))
    updated_at = parse_jira_date(item.findtext("updated", ""))

    labels = [l.text.replace(" ", "-") for l in item.findall("labels/label") if l.text]
    labels.extend(s.replace(" ", "-") for s in extract_sprint_labels(item))

    # Build markdown sections
    sections = []
    sections.append(f"## {summary}")

    # Use ### Description so bd preserves multi-paragraph content
    if description:
        sections.append(f"### Description\n{description}")

    fields = [
        ("Priority", str(priority)),
        ("Type", issue_type),
        ("Assignee", assignee),
        ("Labels", ", ".join(labels) if labels else None),
        ("Status", status),
        ("External Ref", key),
        ("Created By", created_by),
        ("Created At", created_at if created_at else None),
        ("Updated At", updated_at if updated_at else None),
    ]

    for name, value in fields:
        if value:
            sections.append(f"### {name}\n{value}")

    return "\n\n".join(sections), key


def main():
    parser = argparse.ArgumentParser(
        description="Convert Jira XML (RSS) export to Markdown.",
        epilog="example: jira-to-md export.xml | bd create --file -\n"
        "         pbpaste | jira-to-md --bd",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "file",
        nargs="?",
        type=argparse.FileType("r"),
        default=None,
        help="Jira XML file (default: stdin)",
    )
    parser.add_argument(
        "--bd",
        action="store_true",
        help="create issues in beads via bd create --file",
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
    markdown_parts = []
    external_refs = []

    for item in items:
        item_md, key = convert_item(item)
        markdown_parts.append(item_md)
        external_refs.append(key)

        links = extract_links(item)
        for link_desc in links:
            all_links.append(f"{key} {link_desc}")

    output = "\n\n".join(markdown_parts) + "\n"

    if args.bd:
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".md", delete=True
        ) as tmp:
            tmp.write(output)
            tmp.flush()
            result = subprocess.run(
                ["bd", "create", "--file", tmp.name, "--json"],
                capture_output=True, text=True,
            )
            if result.returncode != 0:
                sys.stderr.write(result.stderr)
                raise SystemExit(result.returncode)

            created = json.loads(result.stdout)
            for issue, ref in zip(created, external_refs):
                if not ref:
                    continue
                subprocess.run(
                    ["bd", "update", issue["id"], "--external-ref", ref],
                    check=True,
                )
            # Print the normal (non-json) summary
            for issue in created:
                print(f"  {issue['id']}: {issue['title']}")
    else:
        sys.stdout.write(output)

    if all_links and not args.no_links:
        print("\n--- Issue Links (informational) ---", file=sys.stderr)
        for link in all_links:
            print(link, file=sys.stderr)


if __name__ == "__main__":
    main()
