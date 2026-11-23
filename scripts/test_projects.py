"""Self-check: deleting the `main` worktree must never delete the main checkout."""

import importlib.machinery
import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader("projects", str(ROOT / "bin/core/pde/projects"))
spec = importlib.util.spec_from_loader("projects", loader)
projects = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = projects
loader.exec_module(projects)

env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}

with tempfile.TemporaryDirectory() as tmp:
    repo = Path(tmp) / "repo"
    repo.mkdir()
    for command in (["init", "-q", "-b", "main"], ["commit", "-q", "--allow-empty", "-m", "x"], ["worktree", "add", "-q", "../repo-feat", "-b", "feat"]):
        subprocess.run(["git", *command], cwd=repo, env=env, check=True)

    try:
        projects.delete_worktree(repo, "main")
        raise AssertionError("deleting the main checkout must fail")
    except SystemExit:
        pass
    assert (repo / ".git").is_dir(), "main checkout was deleted"

    projects.delete_worktree(repo, "feat")
    assert not (Path(tmp) / "repo-feat").exists(), "linked worktree was not removed"

print("ok")
