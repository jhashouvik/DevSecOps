#!/usr/bin/env python3

import json
import os
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


def sync_repository(repository: dict) -> None:
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

    print(f"DONE: {repository['full_name']}")


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
            sync_repository(repository)
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
    print("=" * 80)

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
