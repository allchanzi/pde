"""Workflow self-checks: use temporary repositories and fake provider CLIs only."""
from __future__ import annotations

from copy import deepcopy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("workflow", ROOT / "bin/core/pde/workflow.py")
workflow = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = workflow
spec.loader.exec_module(workflow)


def snapshot(head="abc"):
    return {"format": "pde.review/v1", "head_sha": head, "threads": [
        {"id": "T1", "resolved": False, "path": "x.py", "line": 1, "comments": [{"body": "fix the edge case"}]}
    ]}


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        self.env = {**os.environ, "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "test@example.invalid",
                    "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "test@example.invalid"}
        self.git("init", "-q", "-b", "main")
        self.git("remote", "add", "origin", "git@github.com:team/app.git")
        (self.root / "code.py").write_text("original\n")
        self.git("add", "code.py")
        self.git("commit", "-qm", "initial")
        self.app = workflow.Workflow(self.root)

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, env=self.env, text=True).strip()

    def ready(self):
        self.app.begin("Handle empty input")
        self.app.state["request"] = 7
        self.app.persist()
        current = snapshot(self.git("rev-parse", "HEAD"))
        proposals = {"threads": [{"id": "T1", "decision": "fix", "proposal": "Return early for empty input"}],
                     "feedback_id": workflow.feedback_id(current)}
        workflow.save(self.app.directory / "reviewed.json", current)
        workflow.save(self.app.directory / "proposals.json", proposals)
        return current

    def test_begin_preserves_code_ignores_artifacts_and_rejects_second_task(self):
        self.app.begin("Handle empty input; $(touch forbidden)")
        self.assertEqual((self.root / "code.py").read_text(), "original\n")
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertTrue(self.git("branch", "--show-current").startswith("pde/"))
        self.assertEqual(workflow.Workflow(self.root).state["task"], "Handle empty input; $(touch forbidden)")
        with self.assertRaises(RuntimeError):
            self.app.begin("another task")
        self.assertFalse((self.root / "forbidden").exists())

    def test_dirty_checkout_is_rejected_before_changing_branch(self):
        (self.root / "code.py").write_text("unsaved\n")
        with self.assertRaises(RuntimeError):
            self.app.begin("task")
        self.assertEqual(self.git("branch", "--show-current"), "main")
        self.assertFalse(self.app.directory.exists())

    def test_head_and_feedback_changes_block_apply(self):
        current = self.ready()
        changed = deepcopy(current)
        changed["threads"][0]["comments"][0]["body"] = "new feedback"
        with patch.object(workflow.Repository, "snapshot", return_value=changed), patch.object(self.app, "launch") as launch:
            with self.assertRaises(RuntimeError):
                self.app.apply()
            launch.assert_not_called()
        changed["head_sha"] = "newhead"
        with self.assertRaises(RuntimeError):
            self.app.at_reviewed_head(changed)

    def test_apply_requires_confirmation_and_passes_frozen_proposals(self):
        current = self.ready()
        with patch.object(workflow.Repository, "snapshot", return_value=current), patch.object(sys.stdin, "isatty", return_value=True), patch("builtins.input", return_value="no"), patch.object(self.app, "launch") as launch:
            self.app.apply()
            launch.assert_not_called()
        with patch.object(workflow.Repository, "snapshot", return_value=current), patch.object(sys.stdin, "isatty", return_value=True), patch("builtins.input", return_value="apply"), patch.object(self.app, "launch") as launch:
            self.app.apply()
            prompt = launch.call_args.args[0]
            self.assertIn("exact approved proposals", prompt)
            self.assertIn("Do not push", prompt)

    def test_feedback_arriving_during_confirmation_blocks_execution(self):
        current = self.ready()
        changed = deepcopy(current)
        changed["threads"][0]["comments"].append({"body": "additional review"})
        with patch.object(workflow.Repository, "snapshot", side_effect=[current, changed]), patch.object(sys.stdin, "isatty", return_value=True), patch("builtins.input", return_value="apply"), patch.object(self.app, "launch") as launch:
            with self.assertRaises(RuntimeError):
                self.app.apply()
            launch.assert_not_called()

    def test_only_one_operation_can_own_a_worktree(self):
        with self.app.guard("operation"):
            other = workflow.Workflow(self.root)
            with self.assertRaises(RuntimeError):
                with other.guard("operation"):
                    self.fail("Concurrent operation was admitted")

    def test_proposals_cover_each_thread_and_explain_rejections(self):
        current = snapshot()
        for invalid in ({"threads": []}, {"threads": [{"id": "T1", "decision": "reject", "proposal": ""}]},
                        {"threads": [{"id": "other", "decision": "fix", "proposal": "x"}]},
                        {"threads": [None]}):
            with self.assertRaises(RuntimeError):
                workflow.validate_proposals(current, invalid)
        workflow.validate_proposals(current, {"threads": [{"id": "T1", "decision": "reject", "proposal": "Already handled"}]})

    def test_reject_only_does_not_start_a_writable_agent(self):
        current = self.ready()
        proposals = {"threads": [{"id": "T1", "decision": "reject", "proposal": "The guard already exists"}],
                     "feedback_id": workflow.feedback_id(current)}
        workflow.save(self.app.directory / "proposals.json", proposals)
        with patch.object(workflow.Repository, "snapshot", return_value=current), patch.object(sys.stdin, "isatty", return_value=True), patch("builtins.input", return_value="apply"), patch.object(self.app, "launch") as launch:
            self.app.apply()
            launch.assert_not_called()
        result = json.loads((self.app.directory / "result.json").read_text())
        self.assertEqual(result["threads"][0]["status"], "rejected")

    def test_proposal_job_is_readonly_and_persists_its_exact_output(self):
        current = self.ready()
        original = subprocess.run
        def fake(args, **kwargs):
            if args[0] != "codex":
                return original(args, **kwargs)
            self.assertEqual(args[args.index("--sandbox") + 1], "read-only")
            self.assertIn('approval_policy="never"', args)
            workflow.save(Path(args[args.index("--output-last-message") + 1]), {
                "threads": [{"id": "T1", "decision": "fix", "proposal": "Add an early guard"}]})
            return subprocess.CompletedProcess(args, 0)
        with patch.object(workflow.Repository, "snapshot", return_value=current), patch.object(workflow.subprocess, "run", side_effect=fake):
            self.app.propose()
        saved = json.loads((self.app.directory / "proposals.json").read_text())
        self.assertEqual(saved["threads"][0]["proposal"], "Add an early guard")
        self.assertEqual(saved["feedback_id"], workflow.feedback_id(current))
        self.assertEqual((self.root / "code.py").read_text(), "original\n")

    def test_unknown_publish_outcome_is_not_created_twice(self):
        self.app.begin("task")
        (self.root / "code.py").write_text("changed\n")
        self.git("add", "code.py")
        self.git("commit", "-qm", "implement")
        original = self.app.git
        calls = []
        def git(*args):
            return "" if args[0] == "push" else original(*args)
        def api(method, endpoint, body=None):
            calls.append(method)
            if method == "GET":
                return []
            raise RuntimeError("outcome unknown")
        with patch.object(self.app, "git", side_effect=git), patch.object(workflow.Repository, "api", side_effect=api):
            with self.assertRaises(RuntimeError):
                self.app.publish()
            with self.assertRaises(RuntimeError):
                self.app.publish()
        self.assertEqual(calls.count("POST"), 1)
        self.assertTrue((self.app.directory / "publish-pending.json").exists())

    def assert_draft_publish(self, provider):
        host = "github.com" if provider == "github" else "gitlab.com"
        self.git("remote", "set-url", "origin", f"git@{host}:a/b.git")
        app = workflow.Workflow(self.root)
        app.begin("Implement the feature")
        (self.root / "code.py").write_text("implemented\n")
        self.git("add", "code.py")
        self.git("commit", "-qm", "implementation")
        original = app.git
        writes = []
        def git(*args):
            if args[0] == "push":
                self.assertNotIn("--force", args)
                return ""
            return original(*args)
        def api(method, endpoint, body=None):
            if method == "GET":
                return []
            writes.append(body)
            return {"number": 7, "iid": 7}
        with patch.object(app, "git", side_effect=git), patch.object(workflow.Repository, "api", side_effect=api):
            app.publish()
            app.publish()
        self.assertEqual(len(writes), 1)
        self.assertEqual(app.state["request"], 7)
        if provider == "github":
            self.assertTrue(writes[0]["draft"])
        else:
            self.assertTrue(writes[0]["title"].startswith("Draft: "))

    def test_github_draft_publication_is_idempotent(self):
        self.assert_draft_publish("github")

    def test_gitlab_draft_publication_is_idempotent(self):
        self.assert_draft_publish("gitlab")

    def test_repository_identity_and_api_paths(self):
        self.assertEqual(workflow.Repository.parse("git@gitlab.com:a/b/app.git").path, "a/b/app")
        self.assertEqual(workflow.Repository.parse("https://github.com/team/app").provider, "github")
        with self.assertRaises(RuntimeError):
            workflow.Repository.parse("git@private.example:team/app.git")
        self.assertEqual(workflow.Repository.parse("git@private.example:team/app.git", "gitlab").provider, "gitlab")
        request = self.root / "check.bru"
        request.write_text("meta {}")
        self.assertEqual(workflow.checked_request(self.root, "check.bru"), request)
        outside = Path(self.temp.name) / "outside.bru"
        outside.write_text("secret")
        (self.root / "link.bru").symlink_to(outside)
        for invalid in ("../outside.bru", "link.bru", "code.py"):
            with self.assertRaises(RuntimeError):
                workflow.checked_request(self.root, invalid)

    def test_api_tab_refreshes_and_opens_only_the_selected_request(self):
        self.ready()
        (self.root / "check.bru").write_text("meta {}")
        workflow.save(self.app.directory / "api-tests.json", [{"request": "check.bru", "purpose": "Check the feature"}])
        original = subprocess.run
        opened = []
        def fake(args, **kwargs):
            if args[0] != "rtui":
                return original(args, **kwargs)
            opened.append(args)
            return subprocess.CompletedProcess(args, 0)
        with patch("builtins.input", side_effect=["", "1", "p", "q"]), patch.object(workflow.subprocess, "run", side_effect=fake):
            self.app.api()
        self.assertEqual(opened, [["rtui", str(self.root), "--request", str(self.root / "check.bru")]])
        report = json.loads((self.app.directory / "test-result.json").read_text())
        self.assertEqual(report["source"], "developer-report")
        self.assertEqual(report["status"], "passed")

    def test_api_tab_survives_bad_input_and_partial_manifest(self):
        self.ready()
        (self.app.directory / "api-tests.json").write_text('[{"request": ')
        with patch("builtins.input", side_effect=["", "q"]):
            self.app.api()  # partial JSON is reported and waits for the developer
        (self.root / "check.bru").write_text("meta {}")
        workflow.save(self.app.directory / "api-tests.json", [{"request": "check.bru", "purpose": "Check"}])
        with patch("builtins.input", side_effect=["x", "", "9", "", "q"]):
            self.app.api()

    def test_existing_task_does_not_relaunch_agent_without_consent(self):
        self.app.begin("Handle empty input")
        app = workflow.Workflow(self.root)
        with patch("builtins.input", return_value=""), patch.object(app, "launch") as launch:
            app.implement()
            launch.assert_not_called()
        with patch("builtins.input", return_value="y"), patch.object(app, "launch") as launch:
            app.implement()
            launch.assert_called_once()


@unittest.skipUnless(os.environ.get("GTUI_WORKFLOW_BINARY"), "Set GTUI_WORKFLOW_BINARY for cross-tool CLI checks")
class GtuiBridgeTests(unittest.TestCase):
    def test_both_providers_export_and_comment_with_stale_head_protection(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            fake = root / "fake"
            fake.write_text(FAKE_PROVIDER)
            fake.chmod(0o755)
            for cli in ("gh", "glab"):
                (root / cli).symlink_to(fake)
            env = {**os.environ, "PATH": str(root) + os.pathsep + os.environ["PATH"], "POSTED": str(root / "posted.json")}
            binary = os.environ["GTUI_WORKFLOW_BINARY"]
            for provider, host in (("github", "github.com"), ("gitlab", "gitlab.com")):
                context = subprocess.run([binary, "--workflow-snapshot", "--provider", provider, "--repository",
                                          f"https://{host}/a/b", "--request", "7"], env=env, capture_output=True, text=True, check=True)
                data = json.loads(context.stdout)
                self.assertEqual(data["head_sha"], "abc")
                self.assertEqual(data["files"][0]["lines"][2]["new"], 8)
                self.assertEqual(data["threads"][0]["id"], "T1")
                saved = root / "snapshot.json"
                saved.write_text(json.dumps(data))
                body = root / "body.txt"
                body.write_text("Please check $(literal) text.")
                args = [binary, "--workflow-comment", "--snapshot", str(saved), "--file", "0", "--line", "2", "--body-file", str(body)]
                subprocess.run(args, env=env, capture_output=True, text=True, check=True)
                posted = json.loads((root / "posted.json").read_text())
                self.assertEqual(posted["body"], body.read_text())
                self.assertEqual(posted.get("commit_id", posted.get("position", {}).get("head_sha")), "abc")
                (root / "posted.json").unlink()
                stale = subprocess.run(args, env={**env, "FAKE_HEAD": "newhead"}, capture_output=True, text=True)
                self.assertNotEqual(stale.returncode, 0)
                self.assertFalse((root / "posted.json").exists())

@unittest.skipUnless(shutil.which("nvim"), "Neovim is not installed")
class NeovimRpcTests(unittest.TestCase):
    def test_review_opens_in_existing_editor_and_quotes_paths(self):
        with tempfile.TemporaryDirectory(prefix="pde-review-") as name:
            root = Path(name)
            socket = root / "editor.sock"
            server = subprocess.Popen(["nvim", "--headless", "-u", "NONE", "-i", "NONE", "--listen", str(socket)],
                                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                deadline = time.monotonic() + 5
                while not socket.exists() and server.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertTrue(socket.exists(), "Editor RPC did not start")
                data = {"format": "pde.review/v1", "repository": {"provider": "GitHub", "path": "a/b"},
                        "number": 7, "title": "Feature", "head_sha": "abc", "files": [], "threads": []}
                repository = workflow.Repository("github", "github.com", "a/b")
                with patch.object(workflow.Repository, "snapshot", return_value=data), patch.object(workflow, "session_socket", return_value=socket), patch.dict(os.environ, {"XDG_STATE_HOME": str(root / "state with ' quote")}):
                    workflow.review(repository, 7)
                filetype = subprocess.check_output(["nvim", "--server", str(socket), "--remote-expr", "&filetype"], text=True).strip()
                self.assertEqual(filetype, "diff")
            finally:
                server.terminate()
                server.wait(timeout=5)


FAKE_PROVIDER = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
head = os.environ.get("FAKE_HEAD", "abc")
patch = "@@ -4,2 +8,2 @@\n-before\n+after\n context"
if "--input" in args:
    body = json.loads(Path(args[args.index("--input") + 1]).read_text())
    Path(os.environ["POSTED"]).write_text(json.dumps(body))
    result = {"id": "comment", "html_url": "https://example.invalid/review"}
elif args[:2] == ["pr", "view"]:
    result = {"state": "OPEN", "title": "T", "headRefName": "feat", "baseRefName": "main", "headRefOid": head}
else:
    endpoint = next((a for a in args if a.startswith(("repos/", "projects/")) or a == "graphql"), "")
    if endpoint == "graphql":
        result = {"data": {"repository": {"pullRequest": {"reviewThreads": {
            "pageInfo": {"hasNextPage": False}, "nodes": [{"id": "T1", "path": "new.rs", "line": 8, "isResolved": False,
            "comments": {"nodes": [{"author": {"login": "reviewer"}, "body": "fix", "diffHunk": patch}]}}]}}}}}
    elif "/files?" in endpoint:
        result = [{"filename": "new.rs", "previous_filename": "old.rs", "patch": patch, "additions": 1, "deletions": 1}]
    elif "/diffs?" in endpoint:
        result = [{"new_path": "new.rs", "old_path": "old.rs", "diff": patch}]
    elif "/discussions?" in endpoint:
        result = [{"id": "T1", "notes": [{"id": 1, "resolvable": True, "resolved": False, "body": "fix",
            "author": {"username": "reviewer"}, "position": {"new_path": "new.rs", "old_path": "old.rs", "new_line": 8}}]}]
    elif endpoint.endswith("/approvals"):
        result = {"approved_by": []}
    else:
        result = {"state": "opened", "title": "T", "source_branch": "feat", "target_branch": "main", "sha": head,
                  "base": {"sha": "base"}, "head": {"sha": head},
                  "diff_refs": {"base_sha": "base", "start_sha": "start", "head_sha": head}}
print(json.dumps(result))
'''


if __name__ == "__main__":
    unittest.main()

