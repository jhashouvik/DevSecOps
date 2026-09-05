#!/usr/bin/env python3

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import requests


GITHUB_API = "https://api.github.com"
ROOT_DIR = Path(__file__).resolve().parents[1]
CONFIG_FILE = ROOT_DIR / "config" / "config.json"

TOKEN = os.getenv("SOURCE_GITHUB_TOKEN")
SOURCE_ORG = os.getenv("SOURCE_ORG")


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def load_config() -> dict:
    if not CONFIG_FILE.exists():
        fail(f"Configuration file not found: {CONFIG_FILE}")

    with CONFIG_FILE.open("r", encoding="utf-8") as file:
        return json.load(file)


def create_session() -> requests.Session:
    if not TOKEN:
        fail("SOURCE_GITHUB_TOKEN environment variable is not set.")

    session = requests.Session()
    session.headers.update(
        {
            "Authorization": f"Bearer {TOKEN}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
    )
    return session


def github_get(session: requests.Session, url: str, params: dict | None = None):
    response = session.get(url, params=params, timeout=60)

    if response.status_code != 200:
        # Do not print the token or authenticated URL.
        fail(
            f"GitHub API request failed: "
            f"{response.status_code} {response.text[:500]}"
        )

    return response.json()


def discover_repositories(session: requests.Session, organization: str) -> list[dict]:
    repositories = []
    page = 1

    while True:
        url = f"{GITHUB_API}/orgs/{organization}/repos"
        params = {
            "type": "all",
            "per_page": 100,
            "page": page,
        }

        data = github_get(session, url, params)

        if not data:
            break

        repositories.extend(data)

        if len(data) < 100:
            break

        page += 1

    return repositories


def should_sync(repository: dict, config: dict) -> bool:
    name = repository["name"]

    if repository["archived"] and not config.get("include_archived", False):
        print(f"SKIP archived repository: {name}")
        return False

    if repository["fork"] and not config.get("include_forks", True):
        print(f"SKIP fork: {name}")
        return False

    allow = set(config.get("allow_repositories", []))
    exclude = set(config.get("exclude_repositories", []))

    if allow and name not in allow:
        print(f"SKIP not in allow-list: {name}")
        return False

    if name in exclude:
        print(f"SKIP excluded repository: {name}")
        return False

    return True


def authenticated_clone_url(clone_url: str) -> str:
    # The token is only placed in the temporary git remote URL.
    # It is never printed.
    return clone_url.replace(
        "https://github.com/",
        f"https://x-access-token:{TOKEN}@github.com/",
        1,
    )


def run_git(command: list[str], cwd: Path | None = None) -> None:
    subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


# Source repositories belong to other teams and sometimes contain literal
# credentials. GitHub push protection rejects the aggregator push when those
# values reach a commit here, so mirrored content is scrubbed before it is
# written into the destination tree.

MAX_SCAN_BYTES = 5 * 1024 * 1024

REDACTION_RULES = [
    (
        "aws-access-key-id",
        re.compile(r"(?<![A-Z0-9])(?:AKIA|ASIA|ABIA|ACCA)[A-Z0-9]{16}(?![A-Z0-9])"),
        "AWS_ACCESS_KEY_ID_REDACTED_BY_SYNC",
    ),
    (
        "aws-secret-access-key",
        re.compile(
            r"(?i)(aws[_-]?secret[_-]?access[_-]?key\s*[:=]\s*[\"']?)"
            r"[A-Za-z0-9/+=]{40}"
        ),
        r"\1AWS_SECRET_ACCESS_KEY_REDACTED_BY_SYNC",
    ),
    (
        "github-token",
        re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b"),
        "GITHUB_TOKEN_REDACTED_BY_SYNC",
    ),
    (
        "github-fine-grained-token",
        re.compile(r"\bgithub_pat_[A-Za-z0-9_]{22,}\b"),
        "GITHUB_TOKEN_REDACTED_BY_SYNC",
    ),
    (
        "private-key-block",
        re.compile(
            r"-----BEGIN [A-Z ]*PRIVATE KEY-----"
            r".*?"
            r"-----END [A-Z ]*PRIVATE KEY-----",
            re.DOTALL,
        ),
        "PRIVATE_KEY_REDACTED_BY_SYNC",
    ),
]


def redact_tree(root: Path) -> dict[str, int]:
    totals: dict[str, int] = {}

    for path in sorted(root.rglob("*")):
        if path.is_symlink() or not path.is_file():
            continue

        try:
            if path.stat().st_size > MAX_SCAN_BYTES:
                continue
            raw = path.read_bytes()
        except OSError as exc:
            print(f"WARN unreadable during redaction: {path}: {exc}")
            continue

        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            # Binary payload. Nothing to scrub textually.
            continue

        redacted = text
        hits: dict[str, int] = {}

        for rule, pattern, replacement in REDACTION_RULES:
            redacted, count = pattern.subn(replacement, redacted)
            if count:
                hits[rule] = count

        if not hits:
            continue

        path.write_bytes(redacted.encode("utf-8"))

        detail = ", ".join(f"{r} x{c}" for r, c in sorted(hits.items()))
        print(f"REDACT {root.name}/{path.relative_to(root).as_posix()}: {detail}")

        for rule, count in hits.items():
            totals[rule] = totals.get(rule, 0) + count

    return totals


def sync_repository(repository: dict) -> dict[str, int]:
    name = repository["name"]
    destination = ROOT_DIR / name

    print(f"SYNC: {repository['full_name']}")

    with tempfile.TemporaryDirectory(prefix="repo-sync-") as temp_dir:
        temp_root = Path(temp_dir)
        source_dir = temp_root / name

        clone_url = authenticated_clone_url(repository["clone_url"])

        try:
            run_git(
                [
                    "git",
                    "clone",
                    "--depth",
                    "1",
                    clone_url,
                    str(source_dir),
                ]
            )
        except subprocess.CalledProcessError as exc:
            fail(
                f"Unable to clone {repository['full_name']}: "
                f"{exc.stderr[-1000:]}"
            )

        # Remove source Git metadata. The destination remains one Git repository.
        source_git_dir = source_dir / ".git"
        if source_git_dir.exists():
            shutil.rmtree(source_git_dir)

        # Replace the destination folder with the latest source contents.
        if destination.exists():
            shutil.rmtree(destination)

        shutil.copytree(
            source_dir,
            destination,
            symlinks=False,
        )

    redactions = redact_tree(destination)

    print(f"DONE: {repository['full_name']}")

    return redactions


def main() -> None:
    config = load_config()

    organization = SOURCE_ORG or config.get("source_org")
    if not organization:
        fail("Set SOURCE_ORG or configure source_org in config/config.json.")

    session = create_session()

    print("=" * 80)
    print("GitHub Repository Aggregator")
    print("=" * 80)
    print(f"Source organization: {organization}")

    repositories = discover_repositories(session, organization)

    print(f"Repositories discovered: {len(repositories)}")

    destination_repo = os.getenv("DESTINATION_REPO", "").lower()

    synced = 0
    skipped = 0
    failed = 0
    redactions: dict[str, int] = {}

    for repository in repositories:
        full_name = repository["full_name"].lower()

        # Prevent accidental recursion if destination is inside the same org.
        if destination_repo and full_name == destination_repo:
            print(f"SKIP destination repository: {repository['full_name']}")
            skipped += 1
            continue

        if not should_sync(repository, config):
            skipped += 1
            continue

        try:
            for rule, count in sync_repository(repository).items():
                redactions[rule] = redactions.get(rule, 0) + count
            synced += 1
        except Exception as exc:
            failed += 1
            print(
                f"FAILED: {repository['full_name']}: {exc}",
                file=sys.stderr,
            )

    print("=" * 80)
    print(
        f"Summary: discovered={len(repositories)}, "
        f"synced={synced}, skipped={skipped}, failed={failed}"
    )

    if redactions:
        detail = ", ".join(f"{r}={c}" for r, c in sorted(redactions.items()))
        print(f"Secrets redacted before commit: {detail}")
    else:
        print("Secrets redacted before commit: none")

    print("=" * 80)

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
