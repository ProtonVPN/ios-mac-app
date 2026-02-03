#!/usr/bin/env python3
"""
Ensemble reviewer prediction combining:
1. Relevance score (TF-IDF + file-path matching)
2. Fairness score (exponential penalty based on recent Approved-by history)

The fairness component looks at recent Approved-by trailers and applies
exponential decay to reviewers who have approved many recent changes,
encouraging distribution of review load.

NB: this code is entirely AI-generated, so I claim zero credit.

Since the model supports incremental updates, it should improve independently
of the commit window if stored as a build cache artifact.
"""

import argparse
import hashlib
import math
import os
import re
import sqlite3
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
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


# --- Tokenization ---

_ENGLISH_STOP_WORDS = frozenset([
    'the', 'be', 'to', 'of', 'and', 'in', 'that', 'have', 'it', 'for',
    'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at', 'this', 'but',
    'his', 'from', 'they', 'we', 'say', 'her', 'she', 'or', 'an', 'will',
    'my', 'one', 'all', 'would', 'there', 'their', 'what', 'so', 'up',
    'out', 'if', 'about', 'who', 'get', 'which', 'go', 'me', 'when',
    'can', 'like', 'just', 'him', 'know', 'take', 'people', 'into',
    'year', 'your', 'good', 'some', 'could', 'them', 'see', 'other',
    'than', 'then', 'now', 'look', 'only', 'come', 'its', 'over', 'think',
    'also', 'back', 'after', 'use', 'two', 'how', 'our', 'work', 'first',
    'well', 'way', 'even', 'new', 'want', 'because', 'any', 'these',
    'give', 'day', 'most', 'us', 'is', 'are', 'was', 'were', 'been',
    'being', 'has', 'had', 'does', 'did', 'done', 'doing', 'by', 'no',
])

MESSAGE_STOP_WORDS = _ENGLISH_STOP_WORDS | frozenset([
    # Git trailers and metadata
    'merge', 'branch', 'into', 'request', 'reviewed', 'approved', 'by',
    'co', 'authored', 'signed', 'off', 'acked',
    # Email/domain parts
    'proton', 'ch', 'gitlab', 'github', 'com', 'org', 'net', 'io',
    # Jira and conventional commit prefixes
    'id', 'jira', 'vpnappl', 'fix', 'feat', 'chore', 'refactor',
    # Common generic terms
    'add', 'remove', 'test', 'tests', 'update', 'upgrade', 'build',
    'connection', 'server', 'state', 'error', 'user', 'ui', 'port',
    # Platform names
    'ios', 'macos', 'tvos', 'vpn', 'app', 'apple', 'tv',
    # CI/tooling (very common, not discriminative)
    'swiftformat', 'ci', 'cp', 'i18n', 'crowdin', 'translations',
    # Generic dev terms
    'move', 'change', 'make', 'show', 'view', 'settings', 'extension',
    'feature', 'features', 'comments', 'errors', 'dependency', 'dependencies',
    'local', 'agent', 'rule', 'don', 'ensure', 'avoid', 'prevent',
    'forwarding', 'certificate', 'redesign', 'enable', 'available',
])

SOURCE_STOP_WORDS = _ENGLISH_STOP_WORDS | frozenset([
    # License boilerplate
    'license', 'licensed', 'gnu', 'general', 'public', 'free', 'software',
    'foundation', 'copyright', 'warranty', 'merchantability', 'fitness',
    'redistribute', 'modify', 'published', 'version', 'either', 'later',
    'without', 'implied', 'particular', 'purpose', 'terms', 'conditions',
    'apache', 'mit', 'bsd', 'rights', 'reserved', 'permission', 'granted',
    'notice', 'including', 'limited', 'warranties', 'noninfringement',
    'licenses',
    # Swift/programming keywords
    'let', 'var', 'func', 'return', 'import', 'case', 'static', 'private',
    'public', 'init', 'self', 'nil', 'true', 'false', 'else', 'try', 'guard',
    'await', 'string', 'data', 'swift', 'class', 'void', 'protocol', 'bool',
    'result', 'option', 'throws', 'struct', 'enum', 'switch', 'default',
    'weak', 'strong', 'lazy', 'override', 'final', 'open', 'internal',
    # Generic programming terms
    'id', 'key', 'name', 'path', 'error', 'title', 'state', 'store',
    'text', 'value', 'type', 'connection', 'log', 'action', 'details',
    'should', 'more', 'message', 'description', 'info', 'status',
    'exch', 'pop', 'dup', 'obj', 'endobj', 'dict',
    # UI/View terms (appear everywhere)
    'view', 'screen', 'button', 'settings', 'extension', 'server',
    'color', 'width', 'height', 'fill', 'label', 'alert',
    'viewmodel', 'completion', 'configuration', 'config', 'manager',
    # Localization
    'localizable', 'localization', 'en', 'de', 'translated', 'stringunit',
    # URL/network
    'https', 'www', 'com', 'org', 'url', 'http',
    # Platform terms
    'ios', 'macos', 'tvos', 'tv', 'mac', 'proton', 'protonvpn', 'vpn',
    'os', 'app', 'protonmail', 'ch',
    # Testing
    'xctassertequal', 'xctassert', 'expect', 'test', 'tests', 'mock',
    # Very common non-discriminative terms from data analysis
    'feature', 'features', 'user', 'domain', 'under', 'send', 'yes',
    'country', 'int', 'ag', 'shown', 'plan', 'copy', 'profile', 'sub',
    'stop', 'received', 'code', 'ip', 'created', 'receive', 'add',
    'endif', 'debug', 'ison',
    # UI color/attribute terms
    'uicolor', 'nsmutableattributedstring', 'attributedstring',
    'bundleid', 'appgroup', 'asmainappbundleidentifier',
])

PATH_STOP_WORDS = frozenset([
    # Common directory names
    'libraries', 'sources', 'apps', 'resources', 'tests', 'features',
    'shared', 'assets', 'contents', 'views', 'services', 'models',
    'viewmodels', 'viewcontrollers', 'package', 'management', 'common',
    # Platform/project specific
    'swift', 'legacycommon', 'protonvpn', 'foundations', 'ios', 'macos',
    'tvos', 'core', 'domain', 'nehelper', 'ios_app',
    # Localization and assets
    'strings', 'theme', 'scenes', 'xcassets', 'png', 'imageset', 'lproj',
    'localizable', 'localization', 'json', 'flags', 'en',
    # State-related
    'home', 'connection', 'disconnected', 'connected',
    # Snapshot testing (very common, not discriminative)
    '__snapshots__', 'snapshots', 'homeslowsnapshottests',
    'disconnectedcountriessnapshots', 'connectedcitiessnapshots',
    # Common subdirs from data analysis
    'settings', 'modals', 'commonnetworking', 'api', 'svg', 'pdf',
    'protonvpnuitests', 'extensions', 'ergonomics', 'tv',
    'persistence', 'legacycommontests', 'colors', 'sidebar',
    'profiles', 'mocks', 'colorset', 'media', 'xcodeproj',
    'extension', 'countries', 'search',
])


def make_bigrams(tokens: list[str]) -> list[str]:
    """Generate bigrams from a list of tokens, prefixed with 'B:' to distinguish from unigrams."""
    if len(tokens) < 2:
        return []
    return [f"B:{tokens[i]}_{tokens[i+1]}" for i in range(len(tokens) - 1)]


def tokenize_message(text: str) -> list[str]:
    tokens = re.findall(r'[a-zA-Z_][a-zA-Z0-9_]*', text.lower())
    unigrams = [t for t in tokens if len(t) >= 2 and t not in MESSAGE_STOP_WORDS]
    return make_bigrams(unigrams)


def tokenize_source(text: str) -> list[str]:
    tokens = re.findall(r'[a-zA-Z_][a-zA-Z0-9_]*', text.lower())
    unigrams = [t for t in tokens if len(t) >= 2 and t not in SOURCE_STOP_WORDS]
    return make_bigrams(unigrams)


def tokenize_path(path: str) -> list[str]:
    tokens = []
    parts = path.replace('\\', '/').split('/')
    for part in parts:
        sub_tokens = re.findall(r'[a-zA-Z_][a-zA-Z0-9_]*', part.lower())
        tokens.extend(sub_tokens)
    unigrams = [t for t in tokens if len(t) >= 2 and t not in PATH_STOP_WORDS]
    return make_bigrams(unigrams)


def get_path_components(file_path: str) -> list[str]:
    """Get all path prefixes, filtering stop words."""
    parts = file_path.split('/')
    components = []
    for i in range(1, len(parts) + 1):
        path = '/'.join(parts[:i])
        last_part = parts[i-1].lower()
        if '.' in last_part:
            last_part = last_part.rsplit('.', 1)[0]
        if last_part not in PATH_STOP_WORDS:
            components.append(path)
    return components


# --- Feature Extraction ---

def extract_merge_features(
    repo: pygit2.Repository,
    merge_commit: pygit2.Commit,
    submodule_paths: set[str],
) -> tuple[dict[str, list[str]], list[str]]:
    """Extract features from a merge commit. Returns (tokens_dict, file_paths)."""
    features = {
        'filenames': [],
        'source': [],
        'messages': [],
    }
    file_paths = []

    if len(merge_commit.parents) < 2:
        return features, file_paths

    first_parent = merge_commit.parents[0]
    second_parent = merge_commit.parents[1]

    try:
        merge_base = repo.merge_base(first_parent.id, second_parent.id)
    except pygit2.GitError:
        return features, file_paths

    # Collect commit messages
    walker = repo.walk(second_parent.id, pygit2.GIT_SORT_TOPOLOGICAL)
    for commit in walker:
        if commit.id == merge_base:
            break
        features['messages'].extend(tokenize_message(commit.message))

    # Extract file changes
    try:
        diff = repo.diff(first_parent, merge_commit, context_lines=0)
    except pygit2.GitError:
        return features, file_paths

    for patch in diff:
        file_path = patch.delta.new_file.path or patch.delta.old_file.path

        if is_in_submodule(file_path, submodule_paths):
            continue

        file_paths.append(file_path)
        features['filenames'].extend(tokenize_path(file_path))

        try:
            for hunk in patch.hunks:
                for line in hunk.lines:
                    if line.origin in ('+', '-'):
                        features['source'].extend(tokenize_source(line.content))
        except (pygit2.GitError, UnicodeDecodeError):
            pass

    return features, file_paths


def extract_approver(
    commit: pygit2.Commit,
    mailmap: pygit2.Mailmap,
    valid_emails: set[str],
) -> str | None:
    """Extract the approver (Approved-by only) from a commit."""
    approved_pattern = re.compile(r"Approved-by:\s*([^<]*)<([^>]+)>", re.IGNORECASE)

    for match in approved_pattern.finditer(commit.message):
        name, email = match.group(1).strip(), match.group(2).strip()
        try:
            _, resolved_email = mailmap.resolve(name, email)
            resolved_email = resolved_email.lower()
        except pygit2.GitError:
            resolved_email = email.lower()
        if resolved_email in valid_emails:
            return resolved_email

    return None


def extract_reviewers(
    commit: pygit2.Commit,
    mailmap: pygit2.Mailmap,
    valid_emails: set[str],
) -> dict[str, float]:
    """Extract reviewers with weights (Approved-by=1.0, Reviewed-by=0.5)."""
    reviewers = {}

    approved_pattern = re.compile(r"Approved-by:\s*([^<]*)<([^>]+)>", re.IGNORECASE)
    reviewed_pattern = re.compile(r"Reviewed-by:\s*([^<]*)<([^>]+)>", re.IGNORECASE)

    for match in approved_pattern.finditer(commit.message):
        name, email = match.group(1).strip(), match.group(2).strip()
        try:
            _, resolved_email = mailmap.resolve(name, email)
            resolved_email = resolved_email.lower()
        except pygit2.GitError:
            resolved_email = email.lower()
        if resolved_email in valid_emails:
            reviewers[resolved_email] = 1.0

    for match in reviewed_pattern.finditer(commit.message):
        name, email = match.group(1).strip(), match.group(2).strip()
        try:
            _, resolved_email = mailmap.resolve(name, email)
            resolved_email = resolved_email.lower()
        except pygit2.GitError:
            resolved_email = email.lower()
        if resolved_email in valid_emails and resolved_email not in reviewers:
            reviewers[resolved_email] = 0.5

    return reviewers


# --- Fairness: Recent Approvals ---

def get_recent_approvals(
    repo: pygit2.Repository,
    mailmap: pygit2.Mailmap,
    valid_emails: set[str],
    before_commit: pygit2.Commit,
    lookback: int = 30,
) -> dict[str, int]:
    """
    Count recent Approved-by occurrences for each reviewer.
    Looks at the last `lookback` merge commits before `before_commit`.
    Returns dict mapping email -> approval count.
    """
    approval_counts = defaultdict(int)

    walker = repo.walk(before_commit.parents[0].id, pygit2.GIT_SORT_TOPOLOGICAL)
    walker.simplify_first_parent()

    count = 0
    for commit in walker:
        if len(commit.parents) >= 2:
            approver = extract_approver(commit, mailmap, valid_emails)
            if approver:
                approval_counts[approver] += 1
                count += 1
                if count >= lookback:
                    break

    return dict(approval_counts)


# --- Database Schema ---

def init_database(db_path: str) -> sqlite3.Connection:
    """Initialize SQLite database with all required tables."""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # TF-IDF tables
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS token_counts (
            reviewer TEXT NOT NULL,
            feature_type TEXT NOT NULL,
            token TEXT NOT NULL,
            count REAL NOT NULL DEFAULT 0,
            PRIMARY KEY (reviewer, feature_type, token)
        )
    ''')

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS reviewer_totals (
            reviewer TEXT NOT NULL,
            feature_type TEXT NOT NULL,
            total_tokens REAL NOT NULL DEFAULT 0,
            PRIMARY KEY (reviewer, feature_type)
        )
    ''')

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS reviewer_doc_counts (
            reviewer TEXT PRIMARY KEY,
            doc_count REAL NOT NULL DEFAULT 0
        )
    ''')

    # File-path tables
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS path_reviewers (
            path TEXT NOT NULL,
            reviewer TEXT NOT NULL,
            weight REAL NOT NULL DEFAULT 0,
            PRIMARY KEY (path, reviewer)
        )
    ''')

    cursor.execute('''
        CREATE INDEX IF NOT EXISTS idx_path_reviewers_path
        ON path_reviewers (path)
    ''')

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS path_reviewer_totals (
            reviewer TEXT PRIMARY KEY,
            total_weight REAL NOT NULL DEFAULT 0
        )
    ''')

    # Metadata
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS metadata (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    ''')

    # Processed commits
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS processed_commits (
            commit_hash TEXT PRIMARY KEY
        )
    ''')

    conn.commit()
    return conn


# --- Training ---

def process_merge_for_training(
    repo_path: str,
    commit_id: str,
    submodule_paths: set[str],
    valid_emails: set[str],
) -> tuple[dict[str, list[str]], list[str], dict[str, float]] | None:
    """Process a single merge commit for training."""
    try:
        repo = pygit2.Repository(repo_path)
        commit = repo.get(commit_id)

        if not commit or len(commit.parents) < 2:
            return None

        mailmap = pygit2.Mailmap.from_repository(repo)

        features, file_paths = extract_merge_features(repo, commit, submodule_paths)
        reviewers = extract_reviewers(commit, mailmap, valid_emails)

        if not reviewers:
            return None

        return features, file_paths, reviewers
    except (pygit2.GitError, Exception):
        return None


def train(
    repo: pygit2.Repository,
    db_path: str,
    max_commits: int = 0,
    max_workers: int = None,
):
    """Train the model (relevance scoring only - fairness is computed at prediction time)."""
    if max_workers is None:
        max_workers = os.cpu_count() + 1 or 5

    print(f"Training from repository: {repo.workdir}", file=sys.stderr)

    contributors, email_to_gitlab = parse_mailmap(repo)
    valid_emails = set(email_to_gitlab.keys())

    if not valid_emails:
        print("Error: No contributors with gitlab handles found", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(valid_emails)} contributors with gitlab handles", file=sys.stderr)

    submodule_paths = get_submodule_paths(repo)

    conn = init_database(db_path)
    cursor = conn.cursor()

    cursor.execute("SELECT commit_hash FROM processed_commits")
    already_processed = {row[0] for row in cursor.fetchall()}
    print(f"Found {len(already_processed)} already-processed commits", file=sys.stderr)

    # Check for training-cutoff tag
    cutoff_id = None
    try:
        cutoff_ref = repo.revparse_single("training-cutoff")
        if isinstance(cutoff_ref, pygit2.Tag):
            cutoff_id = cutoff_ref.peel(pygit2.Commit).id
        else:
            cutoff_id = cutoff_ref.id
        print(f"Found training-cutoff tag", file=sys.stderr)
    except (pygit2.GitError, KeyError):
        pass

    # Collect merge commits
    print("Collecting merge commits...", file=sys.stderr)
    merge_commits = []

    try:
        head = repo.head.peel(pygit2.Commit)
    except pygit2.GitError:
        print("Error: Could not find HEAD", file=sys.stderr)
        sys.exit(1)

    walker = repo.walk(head.id, pygit2.GIT_SORT_TOPOLOGICAL)
    walker.simplify_first_parent()

    for commit in walker:
        if cutoff_id and commit.id == cutoff_id:
            print(f"Reached training-cutoff", file=sys.stderr)
            break

        if len(commit.parents) >= 2:
            commit_hash = str(commit.id)
            if commit_hash not in already_processed:
                merge_commits.append(commit_hash)
            if max_commits and len(merge_commits) + len(already_processed) >= max_commits:
                break

    if not merge_commits:
        print("No new merge commits to process", file=sys.stderr)
        conn.close()
        return

    print(f"Found {len(merge_commits)} new merge commits", file=sys.stderr)

    # Process merges in parallel
    print("Processing merge commits...", file=sys.stderr)

    # Aggregators
    token_counts = defaultdict(lambda: defaultdict(lambda: defaultdict(float)))
    reviewer_totals = defaultdict(lambda: defaultdict(float))
    reviewer_doc_counts = defaultdict(float)
    path_reviewer_weights = defaultdict(lambda: defaultdict(float))
    path_reviewer_totals = defaultdict(float)
    newly_processed = []

    repo_path = repo.path

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(
                process_merge_for_training,
                repo_path,
                commit_id,
                submodule_paths,
                valid_emails,
            ): commit_id
            for commit_id in merge_commits
        }

        processed = 0
        for future in as_completed(futures):
            commit_id = futures[future]
            result = future.result()

            newly_processed.append(commit_id)

            if result is None:
                continue

            features, file_paths, reviewers = result

            for reviewer, weight in reviewers.items():
                reviewer_doc_counts[reviewer] += weight

                # TF-IDF tokens
                for feature_type, tokens in features.items():
                    for token in tokens:
                        token_counts[reviewer][feature_type][token] += weight
                        reviewer_totals[reviewer][feature_type] += weight

                # File paths
                for file_path in file_paths:
                    for path_component in get_path_components(file_path):
                        path_reviewer_weights[path_component][reviewer] += weight
                        path_reviewer_totals[reviewer] += weight

            processed += 1
            if processed % 100 == 0:
                print(f"  Processed {processed} merges...", file=sys.stderr)

    print(f"Processed {processed} merges with reviewers", file=sys.stderr)

    # Write to database
    print("Updating database...", file=sys.stderr)

    # TF-IDF data
    for reviewer, feature_types in token_counts.items():
        for feature_type, tokens in feature_types.items():
            for token, count in tokens.items():
                cursor.execute('''
                    INSERT INTO token_counts (reviewer, feature_type, token, count)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(reviewer, feature_type, token)
                    DO UPDATE SET count = count + excluded.count
                ''', (reviewer, feature_type, token, count))

    for reviewer, feature_types in reviewer_totals.items():
        for feature_type, total in feature_types.items():
            cursor.execute('''
                INSERT INTO reviewer_totals (reviewer, feature_type, total_tokens)
                VALUES (?, ?, ?)
                ON CONFLICT(reviewer, feature_type)
                DO UPDATE SET total_tokens = total_tokens + excluded.total_tokens
            ''', (reviewer, feature_type, total))

    for reviewer, count in reviewer_doc_counts.items():
        cursor.execute('''
            INSERT INTO reviewer_doc_counts (reviewer, doc_count)
            VALUES (?, ?)
            ON CONFLICT(reviewer)
            DO UPDATE SET doc_count = doc_count + excluded.doc_count
        ''', (reviewer, count))

    # File-path data
    for path, reviewers in path_reviewer_weights.items():
        for reviewer, weight in reviewers.items():
            cursor.execute('''
                INSERT INTO path_reviewers (path, reviewer, weight)
                VALUES (?, ?, ?)
                ON CONFLICT(path, reviewer)
                DO UPDATE SET weight = weight + excluded.weight
            ''', (path, reviewer, weight))

    for reviewer, total in path_reviewer_totals.items():
        cursor.execute('''
            INSERT INTO path_reviewer_totals (reviewer, total_weight)
            VALUES (?, ?)
            ON CONFLICT(reviewer)
            DO UPDATE SET total_weight = total_weight + excluded.total_weight
        ''', (reviewer, total))

    # Processed commits
    cursor.executemany(
        "INSERT OR IGNORE INTO processed_commits (commit_hash) VALUES (?)",
        [(ch,) for ch in newly_processed]
    )

    # Update total docs
    cursor.execute("SELECT value FROM metadata WHERE key = 'total_docs'")
    row = cursor.fetchone()
    existing = int(row[0]) if row else 0
    cursor.execute('''
        INSERT INTO metadata (key, value) VALUES ('total_docs', ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
    ''', (str(existing + processed),))

    conn.commit()
    conn.close()

    print(f"Training complete. Database saved to {db_path}", file=sys.stderr)


# --- Prediction ---

def predict(
    repo: pygit2.Repository,
    db_path: str,
    merge_commit_ref: str,
    fairness_lookback: int = 30,
    fairness_decay: float = 0.3,
    relevance_weight: float = 0.5,
    fairness_weight: float = 0.5,
    fuzz: float = 0.1,
) -> tuple[str, float] | None:
    """
    Predict the best reviewer using relevance + fairness scoring.

    Args:
        fairness_lookback: Number of recent merges to consider for fairness
        fairness_decay: Exponential decay factor (higher = stronger penalty for repeat approvers)
        relevance_weight: Weight for relevance score (TF-IDF + file paths)
        fairness_weight: Weight for fairness score
        fuzz: Small amount of hash-driven randomness for tie-breaking
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

    # Get authors to exclude
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

    # Extract features
    submodule_paths = get_submodule_paths(repo)
    features, file_paths = extract_merge_features(repo, commit, submodule_paths)

    # Load from database
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}", file=sys.stderr)
        return None

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Get metadata
    cursor.execute("SELECT value FROM metadata WHERE key = 'total_docs'")
    row = cursor.fetchone()
    if not row:
        print("Error: Database not trained", file=sys.stderr)
        conn.close()
        return None
    total_docs = int(row[0])

    # Get reviewer doc counts
    cursor.execute("SELECT reviewer, doc_count FROM reviewer_doc_counts")
    reviewer_doc_counts = {row[0]: row[1] for row in cursor.fetchall()}

    # Eligible reviewers
    eligible_reviewers = valid_emails - merge_authors
    eligible_reviewers = {r for r in eligible_reviewers if r in reviewer_doc_counts}

    if not eligible_reviewers:
        print("Error: No eligible reviewers found", file=sys.stderr)
        conn.close()
        return None

    # === RELEVANCE SCORE ===
    # Combines TF-IDF and file-path matching

    # Get reviewer totals for TF-IDF
    cursor.execute("SELECT reviewer, feature_type, total_tokens FROM reviewer_totals")
    reviewer_totals = defaultdict(dict)
    for row in cursor.fetchall():
        reviewer_totals[row[0]][row[1]] = row[2]

    # Get IDF values
    all_tokens = set()
    for tokens in features.values():
        all_tokens.update(tokens)

    token_doc_freq = defaultdict(int)
    if all_tokens:
        placeholders = ','.join('?' * len(all_tokens))
        cursor.execute(
            f"SELECT token, COUNT(DISTINCT reviewer) FROM token_counts WHERE token IN ({placeholders}) GROUP BY token",
            list(all_tokens)
        )
        for row in cursor.fetchall():
            token_doc_freq[row[0]] = row[1]

    feature_weights = {'filenames': 3.0, 'source': 1.0, 'messages': 2.0}

    # Bulk load token counts for all tokens we need (much faster than per-reviewer queries)
    token_counts_bulk = defaultdict(lambda: defaultdict(lambda: defaultdict(float)))
    if all_tokens:
        placeholders = ','.join('?' * len(all_tokens))
        cursor.execute(
            f"SELECT reviewer, feature_type, token, count FROM token_counts WHERE token IN ({placeholders})",
            list(all_tokens)
        )
        for reviewer, feature_type, token, count in cursor.fetchall():
            token_counts_bulk[reviewer][feature_type][token] = count

    tfidf_scores = {}
    for reviewer in eligible_reviewers:
        doc_count = reviewer_doc_counts.get(reviewer, 0)
        if doc_count == 0:
            tfidf_scores[reviewer] = 0.0
            continue

        score = 0.0
        score += 0.1 * math.log(doc_count / total_docs + 0.01)

        for feature_type, tokens in features.items():
            if not tokens:
                continue

            weight = feature_weights.get(feature_type, 1.0)
            total_tokens = reviewer_totals.get(reviewer, {}).get(feature_type, 0)
            if total_tokens == 0:
                continue

            token_map = token_counts_bulk[reviewer][feature_type]

            token_counts_input = defaultdict(int)
            for token in tokens:
                token_counts_input[token] += 1

            for token, input_count in token_counts_input.items():
                reviewer_count = token_map.get(token, 0)
                if reviewer_count == 0:
                    continue

                tf = reviewer_count / total_tokens
                doc_freq = token_doc_freq.get(token, 1)
                idf = math.log((len(reviewer_doc_counts) + 1) / (doc_freq + 1)) + 1
                score += weight * input_count * tf * idf

        tfidf_scores[reviewer] = score

    # File-path scores
    cursor.execute("SELECT reviewer, total_weight FROM path_reviewer_totals")
    path_totals = {row[0]: row[1] for row in cursor.fetchall()}

    all_paths = set()
    for file_path in file_paths:
        all_paths.update(get_path_components(file_path))

    path_weights_db = defaultdict(lambda: defaultdict(float))
    if all_paths:
        placeholders = ','.join('?' * len(all_paths))
        cursor.execute(
            f"SELECT path, reviewer, weight FROM path_reviewers WHERE path IN ({placeholders})",
            list(all_paths)
        )
        for path, reviewer, weight in cursor.fetchall():
            path_weights_db[path][reviewer] = weight

    path_scores = {}
    for reviewer in eligible_reviewers:
        reviewer_total = path_totals.get(reviewer, 1)
        score = 0.0

        for file_path in file_paths:
            for path_component in get_path_components(file_path):
                if reviewer in path_weights_db[path_component]:
                    depth = path_component.count('/') + 1
                    raw_weight = path_weights_db[path_component][reviewer]
                    score += (raw_weight / reviewer_total) * depth

        path_scores[reviewer] = score

    conn.close()

    # Combine TF-IDF and path scores into relevance
    def normalize(scores: dict[str, float]) -> dict[str, float]:
        """Normalize scores to [0, 1] range."""
        vals = list(scores.values())
        min_v, max_v = min(vals), max(vals)
        range_v = max_v - min_v if max_v > min_v else 1.0
        return {k: (v - min_v) / range_v for k, v in scores.items()}

    def normalize_with_floor(scores: dict[str, float], floor: float = 0.1) -> dict[str, float]:
        """Normalize scores to [floor, 1.0] range so no one is completely unsuitable."""
        vals = list(scores.values())
        min_v, max_v = min(vals), max(vals)
        range_v = max_v - min_v if max_v > min_v else 1.0
        # Map to [0, 1] then compress to [floor, 1]
        normalized = {}
        for k, v in scores.items():
            norm_01 = (v - min_v) / range_v
            normalized[k] = floor + (1.0 - floor) * norm_01
        return normalized

    norm_tfidf = normalize(tfidf_scores)
    norm_path = normalize(path_scores)

    relevance_scores = {}
    for reviewer in eligible_reviewers:
        # Weight path matching higher (more specific signal)
        relevance_scores[reviewer] = 0.4 * norm_tfidf[reviewer] + 0.6 * norm_path[reviewer]

    # === FAIRNESS SCORE ===
    # Based on recent Approved-by trailers - exponential penalty for frequent approvers

    recent_approvals = get_recent_approvals(
        repo, mailmap, valid_emails, commit, lookback=fairness_lookback
    )

    # Calculate fairness: fewer recent approvals = higher fairness score
    # Use exponential decay: score = exp(-decay * approval_count)
    fairness_scores = {}
    for reviewer in eligible_reviewers:
        approval_count = recent_approvals.get(reviewer, 0)
        fairness_scores[reviewer] = math.exp(-fairness_decay * approval_count)

    # Normalize fairness scores
    norm_fairness = normalize(fairness_scores)

    # === COMBINED SCORE ===
    final_scores = {}
    for reviewer in eligible_reviewers:
        final_scores[reviewer] = (
            relevance_weight * relevance_scores[reviewer] +
            fairness_weight * norm_fairness[reviewer]
        )

    # Apply small fuzz for deterministic tie-breaking
    if fuzz > 0:
        commit_hash = str(commit.id)
        score_range = max(final_scores.values()) - min(final_scores.values())
        score_range = max(score_range, 0.1)

        fuzzed_scores = {}
        for reviewer, score in final_scores.items():
            seed = hashlib.md5(f"{commit_hash}:{reviewer}".encode()).hexdigest()
            noise = (int(seed[:8], 16) / 0xFFFFFFFF) - 0.5
            fuzzed_scores[reviewer] = score + fuzz * score_range * noise

        final_scores = fuzzed_scores

    best_reviewer = max(final_scores, key=final_scores.get)
    best_score = final_scores[best_reviewer]

    gitlab_handle = email_to_gitlab.get(best_reviewer, best_reviewer)
    return gitlab_handle, best_score


def main():
    parser = argparse.ArgumentParser(
        description="Reviewer prediction combining relevance and fairness."
    )
    parser.add_argument(
        "repo_path",
        nargs="?",
        default=".",
        help="Path to the repository"
    )
    parser.add_argument(
        "--train",
        action="store_true",
        help="Train the model"
    )
    parser.add_argument(
        "--predict",
        metavar="COMMIT",
        help="Predict reviewer for a merge commit"
    )
    parser.add_argument(
        "--db",
        default="final_reviewer_model.db",
        help="Path to the database"
    )
    parser.add_argument(
        "--max-commits",
        type=int,
        default=0,
        help="Maximum commits to process"
    )
    parser.add_argument(
        "--jobs", "-j",
        type=int,
        default=os.cpu_count() + 1 or 5,
        help="Number of workers"
    )
    parser.add_argument(
        "--fuzz",
        type=float,
        default=0.1,
        help="Fuzz factor for tie-breaking (0.0-1.0)"
    )
    parser.add_argument(
        "--fairness-lookback",
        type=int,
        default=18,
        help="Number of recent merges to consider for fairness (default: 18)"
    )
    parser.add_argument(
        "--fairness-decay",
        type=float,
        default=0.3,
        help="Exponential decay for fairness (higher = stronger penalty)"
    )
    parser.add_argument(
        "--relevance-weight",
        type=float,
        default=0.35,
        help="Weight for relevance score (default: 0.35)"
    )
    parser.add_argument(
        "--fairness-weight",
        type=float,
        default=0.65,
        help="Weight for fairness score (default: 0.65)"
    )

    args = parser.parse_args()

    try:
        repo = pygit2.Repository(args.repo_path)
    except pygit2.GitError as e:
        print(f"Error opening repository: {e}", file=sys.stderr)
        sys.exit(1)

    if args.train:
        train(repo, args.db, args.max_commits, args.jobs)
    elif args.predict:
        result = predict(
            repo, args.db, args.predict,
            fairness_lookback=args.fairness_lookback,
            fairness_decay=args.fairness_decay,
            relevance_weight=args.relevance_weight,
            fairness_weight=args.fairness_weight,
            fuzz=args.fuzz,
        )
        if result:
            gitlab_handle, score = result
            print(f"{gitlab_handle}")
        else:
            sys.exit(1)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
