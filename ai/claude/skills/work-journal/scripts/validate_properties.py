#!/usr/bin/env python3
"""
Validate Notion page properties before creation.

This script validates that all required properties are present and correctly
formatted for creating work pages in the Notion database.

Usage:
    python validate_properties.py --help
    python validate_properties.py --priority 1 --project "MyProject" --type feature
    python validate_properties.py --priority 0 --project "Auth" --type bug --jira 2110 --github 123 --repo "odasoftmx/app"

Exit codes:
    0 - All validations passed
    1 - Validation failed
"""

import argparse
import json
import sys
from typing import Dict, List, Optional, Tuple


# Constants
VALID_PRIORITIES = [0, 1, 2, 3, 4]
VALID_TYPES = ["bug", "feature", "task", "epic", "chore"]
JIRA_BASE_URL = "https://odasoftmx.atlassian.net/browse/"
GITHUB_BASE_URL = "https://github.com/"


class ValidationError:
    """Represents a single validation error with agent-centric guidance."""

    def __init__(self, property_name: str, message: str, suggestion: str):
        self.property = property_name
        self.message = message
        self.suggestion = suggestion

    def to_dict(self) -> Dict:
        return {
            "property": self.property,
            "message": self.message,
            "suggestion": self.suggestion
        }


class PropertyValidator:
    """Validates Notion work page properties."""

    def __init__(self):
        self.errors: List[ValidationError] = []

    def validate_priority(self, priority: Optional[int]) -> bool:
        """Validate Priority property (0-4)."""
        if priority is None:
            self.errors.append(ValidationError(
                "Priority",
                "Priority is required but not provided",
                "Ask the user: 'What priority should this work have? (0=Critical, 1=High, 2=Medium, 3=Low, 4=Backlog)'"
            ))
            return False

        if priority not in VALID_PRIORITIES:
            self.errors.append(ValidationError(
                "Priority",
                f"Invalid priority value: {priority}. Must be 0-4",
                f"Valid values: 0 (Critical), 1 (High), 2 (Medium), 3 (Low), 4 (Backlog). The user provided '{priority}' which is not in this range."
            ))
            return False

        return True

    def validate_project(self, project: Optional[str]) -> bool:
        """Validate Project property (non-empty string)."""
        if not project:
            self.errors.append(ValidationError(
                "Project",
                "Project is required but not provided or is empty",
                "Ask the user: 'What project or team does this work belong to?'"
            ))
            return False

        if not project.strip():
            self.errors.append(ValidationError(
                "Project",
                "Project name cannot be only whitespace",
                "Ask the user for a valid project name"
            ))
            return False

        return True

    def validate_type(self, work_type: Optional[str]) -> bool:
        """Validate Type property (bug/feature/task/epic/chore)."""
        if not work_type:
            self.errors.append(ValidationError(
                "Type",
                "Type is required but not provided",
                "Ask the user: 'What type of work is this? (bug, feature, task, epic, or chore)'"
            ))
            return False

        if work_type not in VALID_TYPES:
            self.errors.append(ValidationError(
                "Type",
                f"Invalid type: {work_type}. Must be one of: {', '.join(VALID_TYPES)}",
                f"The user mentioned '{work_type}'. Did they mean one of: {', '.join(VALID_TYPES)}? Ask for clarification."
            ))
            return False

        return True

    def validate_jira(self, jira_issue: Optional[str]) -> Tuple[bool, Optional[str]]:
        """
        Validate and construct Jira URL.

        Returns:
            (is_valid, constructed_url)
        """
        if not jira_issue:
            # Jira is optional, so not an error
            return True, None

        # Clean the input (remove common prefixes/suffixes)
        jira_issue = jira_issue.strip()
        jira_issue = jira_issue.replace("Jira", "").replace("JIRA", "").strip()
        jira_issue = jira_issue.lstrip("#")

        # Construct the full URL
        jira_url = f"{JIRA_BASE_URL}{jira_issue}"

        # Basic validation - just check it looks like an issue ID
        if not jira_issue:
            self.errors.append(ValidationError(
                "Jira issue #",
                "Jira issue number is empty after cleaning",
                "Check the user input for the Jira issue number. It should be in format like 'SYS-123' or just '2110'"
            ))
            return False, None

        return True, jira_url

    def validate_github(
        self,
        github_issue: Optional[str],
        repo: Optional[str]
    ) -> Tuple[bool, Optional[str]]:
        """
        Validate and construct GitHub URL.

        Returns:
            (is_valid, constructed_url)
        """
        if not github_issue:
            # GitHub is optional, so not an error
            return True, None

        # Clean the input
        github_issue = github_issue.strip()
        github_issue = github_issue.lstrip("#")

        # Check if issue number is valid
        if not github_issue.isdigit():
            self.errors.append(ValidationError(
                "Github issue #",
                f"Invalid GitHub issue number: {github_issue}. Must be numeric",
                f"The user provided '{github_issue}' which is not a valid issue number. Ask for the numeric issue number (e.g., '123')"
            ))
            return False, None

        # Check if repo is provided
        if not repo:
            self.errors.append(ValidationError(
                "Github issue #",
                "GitHub issue provided but repository is unknown",
                "Ask the user: 'What is the full GitHub repository name? (e.g., odasoftmx/sistema-escolar)'"
            ))
            return False, None

        # Clean repo (remove common prefixes)
        repo = repo.strip()
        repo = repo.replace("github.com/", "").replace("https://", "").replace("http://", "")
        repo = repo.rstrip("/")

        # Validate repo format (should be user/repo)
        if "/" not in repo:
            self.errors.append(ValidationError(
                "Github issue #",
                f"Invalid repository format: {repo}. Must be 'user/repo'",
                f"The repository should be in format 'user/repo' (e.g., 'odasoftmx/app'). Ask the user for the complete repository path."
            ))
            return False, None

        # Construct the full URL
        github_url = f"{GITHUB_BASE_URL}{repo}/issues/{github_issue}"

        return True, github_url

    def validate_all(
        self,
        priority: Optional[int],
        project: Optional[str],
        work_type: Optional[str],
        jira_issue: Optional[str] = None,
        github_issue: Optional[str] = None,
        repo: Optional[str] = None
    ) -> Dict:
        """
        Validate all properties and return result.

        Returns:
            {
                "valid": bool,
                "errors": List[Dict],
                "urls": {
                    "jira": Optional[str],
                    "github": Optional[str]
                }
            }
        """
        self.errors = []  # Reset errors

        # Validate required properties
        self.validate_priority(priority)
        self.validate_project(project)
        self.validate_type(work_type)

        # Validate and construct URLs
        jira_valid, jira_url = self.validate_jira(jira_issue)
        github_valid, github_url = self.validate_github(github_issue, repo)

        # Build result
        result = {
            "valid": len(self.errors) == 0,
            "errors": [error.to_dict() for error in self.errors],
            "urls": {
                "jira": jira_url,
                "github": github_url
            }
        }

        return result


def main():
    """Main entry point for the validation script."""
    parser = argparse.ArgumentParser(
        description="Validate Notion work page properties before creation",
        epilog="""
Examples:
  # Validate minimal required properties
  python validate_properties.py --priority 2 --project "Auth Team" --type feature

  # Validate with Jira issue
  python validate_properties.py --priority 0 --project "Backend" --type bug --jira 2110

  # Validate with GitHub issue (requires repo)
  python validate_properties.py --priority 1 --project "Frontend" --type feature --github 123 --repo "odasoftmx/app"

  # Validate all properties
  python validate_properties.py --priority 1 --project "Platform" --type bug --jira SYS-456 --github 789 --repo "odasoftmx/sistema-escolar"
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    # Required arguments
    parser.add_argument(
        "--priority",
        type=int,
        help="Priority level (0=Critical, 1=High, 2=Medium, 3=Low, 4=Backlog)"
    )
    parser.add_argument(
        "--project",
        type=str,
        help="Project or team name"
    )
    parser.add_argument(
        "--type",
        type=str,
        choices=VALID_TYPES,
        help="Work type: bug, feature, task, epic, or chore"
    )

    # Optional arguments
    parser.add_argument(
        "--jira",
        type=str,
        help="Jira issue ID (e.g., 2110 or SYS-2110)"
    )
    parser.add_argument(
        "--github",
        type=str,
        help="GitHub issue number (e.g., 123)"
    )
    parser.add_argument(
        "--repo",
        type=str,
        help="GitHub repository in format user/repo (required if --github is provided)"
    )

    args = parser.parse_args()

    # Create validator and run validation
    validator = PropertyValidator()
    result = validator.validate_all(
        priority=args.priority,
        project=args.project,
        work_type=args.type,
        jira_issue=args.jira,
        github_issue=args.github,
        repo=args.repo
    )

    # Output result as JSON
    print(json.dumps(result, indent=2))

    # Exit with appropriate code
    sys.exit(0 if result["valid"] else 1)


if __name__ == "__main__":
    main()
