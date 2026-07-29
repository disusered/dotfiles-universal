#!/usr/bin/env python3
"""Audit a uv course environment, notebooks, and registered kernelspec."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--course-dir", type=Path, required=True)
    parser.add_argument("--kernel-name", required=True)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, object]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"{path}: invalid JSON: {error}") from error


def notebook_issues(path: Path, kernel_name: str) -> list[str]:
    try:
        data = load_json(path)
    except ValueError as error:
        return [str(error)]

    issues: list[str] = []
    if data.get("nbformat") != 4:
        issues.append(f"{path}: expected notebook format 4")

    metadata = data.get("metadata")
    if not isinstance(metadata, dict):
        return issues + [f"{path}: missing metadata object"]

    kernelspec = metadata.get("kernelspec")
    if not isinstance(kernelspec, dict):
        return issues + [f"{path}: missing metadata.kernelspec object"]

    if kernelspec.get("name") != kernel_name:
        issues.append(
            f"{path}: kernelspec is {kernelspec.get('name')!r}, "
            f"expected {kernel_name!r}"
        )
    return issues


def kernelspec_issues(python: Path, kernel_name: str) -> list[str]:
    jupyter = python.parent / "jupyter"
    if not jupyter.is_file():
        return [f"missing Jupyter executable: {jupyter}"]

    result = subprocess.run(
        [str(jupyter), "kernelspec", "list", "--json"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        return [f"could not list kernelspecs: {detail}"]

    try:
        kernels = json.loads(result.stdout).get("kernelspecs", {})
    except json.JSONDecodeError as error:
        return [f"jupyter returned invalid JSON: {error}"]

    spec = kernels.get(kernel_name)
    if not isinstance(spec, dict):
        return [f"registered kernelspec not found: {kernel_name}"]

    resource_dir = spec.get("resource_dir")
    if not isinstance(resource_dir, str):
        return [f"kernelspec has no resource directory: {kernel_name}"]

    try:
        kernel_data = load_json(Path(resource_dir) / "kernel.json")
    except ValueError as error:
        return [str(error)]

    argv = kernel_data.get("argv")
    if not isinstance(argv, list) or not argv or not isinstance(argv[0], str):
        return [f"{resource_dir}/kernel.json: missing argv[0]"]

    configured_python = Path(argv[0]).expanduser()
    if not configured_python.exists():
        return [f"kernelspec interpreter does not exist: {configured_python}"]

    configured_path = configured_python.absolute()
    expected_path = python.absolute()
    same_environment = (
        configured_path.parent == expected_path.parent
        and configured_path.resolve() == expected_path.resolve()
    )
    if not same_environment:
        return [
            "kernelspec interpreter mismatch: "
            f"{configured_path} != {expected_path}"
        ]
    return []


def main() -> int:
    args = parse_args()
    course_dir = args.course_dir.resolve()
    python = course_dir / ".venv/bin/python"
    issues: list[str] = []

    if not (course_dir / "pyproject.toml").is_file():
        issues.append(f"missing project metadata: {course_dir / 'pyproject.toml'}")
    if not python.is_file():
        issues.append(f"missing course interpreter: {python}")

    notebooks = sorted(course_dir.glob("notebooks/**/*.ipynb"))
    if not notebooks:
        issues.append(f"no notebooks found under {course_dir / 'notebooks'}")
    for path in notebooks:
        issues.extend(notebook_issues(path, args.kernel_name))

    if python.is_file():
        issues.extend(kernelspec_issues(python, args.kernel_name))

    if issues:
        for issue in issues:
            print(f"FAIL: {issue}")
        return 1

    print(f"PASS: {len(notebooks)} notebook(s)")
    print(f"PASS: course interpreter {python.absolute()}")
    print(f"PASS: kernelspec {args.kernel_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
