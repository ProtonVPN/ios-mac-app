#!/usr/bin/env python3
"""
Pick a random reviewer from the mailmap, seeded by the HEAD commit hash,
excluding authors of commits in the merge branch being reviewed.
"""

import argparse
import random
import re
import sys
from pathlib import Path

import pygit2

# --- Mailmap and GitLab Handle Parsing ---


def parse_mailmap(repo: pygit2.Repository) -> tuple[set[str], dict[str, str]]:
    """Parse .mailmap file and return (contributors, email_to_gitlab)."""
    contributors = set()
    email_to_gitlab = {}

    mailmap_path = Path(repo.workdir) / ".mailmap" if repo.workdir else None
    mailmap_content = None

    if mailmap_path and mailmap_path.exists():
        mailmap_content = mailmap_path.read_text()
    else:
        try:
            obj = repo.revparse_single("HEAD:.mailmap")
            if isinstance(obj, pygit2.Blob):
                mailmap_content = obj.data.decode("utf-8", errors="replace")
        except (KeyError, pygit2.GitError):
            pass

    if mailmap_content is None:
        return contributors, email_to_gitlab

    email_pattern = re.compile(r"<([^>]+)>")
    gitlab_pattern = re.compile(r"<([^@>]+)@gitlab>")

    for line in mailmap_content.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        emails = email_pattern.findall(line)
        if emails:
            canonical_email = emails[0].lower()
            contributors.add(canonical_email)

            gitlab_match = gitlab_pattern.search(line)
            if gitlab_match:
                email_to_gitlab[canonical_email] = gitlab_match.group(1)

    return contributors, email_to_gitlab


# --- Submodule Handling ---


def get_submodule_paths(repo: pygit2.Repository) -> set[str]:
    """Get submodule paths."""
    submodule_paths = set()
    try:
        for submodule in repo.listall_submodules():
            submodule_paths.add(submodule)
    except (pygit2.GitError, AttributeError):
        pass
    return submodule_paths


def is_in_submodule(file_path: str, submodule_paths: set[str]) -> bool:
    """Check if a file path is within a submodule."""
    for submodule_path in submodule_paths:
        if file_path == submodule_path or file_path.startswith(submodule_path + "/"):
            return True
    return False


# --- Reviewer Selection ---


def pick_reviewer(repo: pygit2.Repository, merge_commit_ref: str) -> str | None:
    """
    Pick a random reviewer for the given merge commit, seeded by that commit's hash.
    Excludes authors of commits in the merge branch.
    """
    contributors, email_to_gitlab = parse_mailmap(repo)
    valid_emails = set(email_to_gitlab.keys())

    if not valid_emails:
        print("Error: No contributors with gitlab handles found", file=sys.stderr)
        return None

    try:
        commit = repo.revparse_single(merge_commit_ref)
        if isinstance(commit, pygit2.Tag):
            commit = commit.peel(pygit2.Commit)
    except pygit2.GitError as e:
        print(f"Error resolving commit: {e}", file=sys.stderr)
        return None

    if len(commit.parents) < 2:
        print(f"Error: {merge_commit_ref} is not a merge commit", file=sys.stderr)
        return None

    # Collect authors from the merge branch to exclude them
    mailmap = pygit2.Mailmap.from_repository(repo)
    first_parent = commit.parents[0]
    second_parent = commit.parents[1]

    try:
        merge_base = repo.merge_base(first_parent.id, second_parent.id)
    except pygit2.GitError:
        merge_base = None

    merge_authors = set()
    if merge_base:
        walker = repo.walk(second_parent.id, pygit2.GIT_SORT_TOPOLOGICAL)
        for mc in walker:
            if mc.id == merge_base:
                break
            try:
                _, author_email = mailmap.resolve(mc.author.name, mc.author.email)
                merge_authors.add(author_email.lower())
            except pygit2.GitError:
                merge_authors.add(mc.author.email.lower())

    eligible = sorted(valid_emails - merge_authors)
    if not eligible:
        print("Error: No eligible reviewers found", file=sys.stderr)
        return None

    # Seed RNG with the merge commit's hash for deterministic-per-commit selection
    rng = random.Random(str(commit.id))
    chosen_email = rng.choice(eligible)
    return email_to_gitlab[chosen_email]


def main():
    parser = argparse.ArgumentParser(
        description="Pick a random reviewer seeded by the merge commit's hash."
    )
    parser.add_argument(
        "repo_path", nargs="?", default=".", help="Path to the repository"
    )
    parser.add_argument(
        "--predict",
        metavar="COMMIT",
        default="HEAD",
        help="Pick a reviewer for a merge commit (default: HEAD)",
    )

    args = parser.parse_args()

    try:
        repo = pygit2.Repository(args.repo_path)
    except pygit2.GitError as e:
        print(f"Error opening repository: {e}", file=sys.stderr)
        sys.exit(1)

    handle = pick_reviewer(repo, args.predict)
    if handle:
        print(handle)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
