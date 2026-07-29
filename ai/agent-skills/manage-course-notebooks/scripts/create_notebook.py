#!/usr/bin/env python3
"""Create a lesson notebook with course-level kernel metadata."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


CELL_ID_RE = re.compile(r"[^A-Za-z0-9_-]+")


def cell_id(value: str, suffix: str) -> str:
    normalized = CELL_ID_RE.sub("-", value.strip().lower()).strip("-_")
    normalized = normalized or "lesson"
    return f"{normalized[:48]}-{suffix}"[:64]


def resolve_output(course_dir: Path, output: str) -> Path:
    course_dir = course_dir.resolve()
    output_path = (course_dir / output).resolve()
    if not output_path.is_relative_to(course_dir):
        raise ValueError("output must stay inside the course directory")
    return output_path


def notebook(args: argparse.Namespace) -> dict[str, object]:
    slug = Path(args.output).stem
    return {
        "cells": [
            {
                "cell_type": "markdown",
                "id": cell_id(slug, "introduction"),
                "metadata": {},
                "source": [
                    f"# {args.title}\n",
                    "\n",
                    f"Course: [{args.course_title}]({args.course_url})\n",
                    "\n",
                    f"Lesson: [{args.title}]({args.lesson_url})\n",
                    "\n",
                    "Transcribe the lesson example below. The gated course "
                    "code has not been invented or reconstructed.",
                ],
            },
            {
                "cell_type": "code",
                "execution_count": None,
                "id": cell_id(slug, "example"),
                "metadata": {},
                "outputs": [],
                "source": [],
            },
        ],
        "metadata": {
            "kernelspec": {
                "display_name": args.kernel_display_name,
                "language": "python",
                "name": args.kernel_name,
            },
            "language_info": {
                "name": "python",
                "version": args.python_version,
            },
        },
        "nbformat": 4,
        "nbformat_minor": 5,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--course-dir", type=Path, required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--course-title", required=True)
    parser.add_argument("--course-url", required=True)
    parser.add_argument("--lesson-url", required=True)
    parser.add_argument("--kernel-name", required=True)
    parser.add_argument("--kernel-display-name", required=True)
    parser.add_argument("--python-version", default="3.11")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    course_dir = args.course_dir.resolve()
    if not course_dir.is_dir():
        raise SystemExit(f"course directory does not exist: {course_dir}")

    try:
        output_path = resolve_output(course_dir, args.output)
    except ValueError as error:
        raise SystemExit(str(error)) from error

    if output_path.exists():
        raise SystemExit(f"refusing to overwrite existing notebook: {output_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(notebook(args), ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
