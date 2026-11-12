import datetime
import subprocess

import pytest

import vault_tools
from vault_tools import Vault

IDENTITY = "Hermes <hermes@io>"


@pytest.fixture
def vault(tmp_path):
    root = tmp_path / "vault"
    root.mkdir()
    subprocess.run([vault_tools.GIT, "init", "-q", "-b", "main"], cwd=root, check=True)
    (root / "keep.md").write_text("a\n")
    (root / "gone.md").write_text("b\n")
    v = Vault(root, IDENTITY)
    v._git("add", "keep.md", "gone.md")
    v._git("commit", "-q", "-m", "init")
    return v


def head_files(v):
    return sorted(v._git("show", "--name-only", "--format=", "HEAD").splitlines())


def changes_log(v):
    month = datetime.datetime.now().astimezone().strftime("%Y-%m")
    return f"agent/changes/{month}.md"


def test_commits_only_named_files(vault):
    (vault.root / "new.md").write_text("x\n")
    (vault.root / "keep.md").write_text("pending\n")
    (vault.root / "gone.md").unlink()

    assert vault.commit("Add new, drop gone", ["new.md", "gone.md"])

    assert head_files(vault) == sorted([changes_log(vault), "gone.md", "new.md"])
    assert vault._git("status", "--porcelain") == "M keep.md"
    assert vault._git("log", "-1", "--format=%an <%ae>") == IDENTITY


def test_logs_each_commit(vault):
    (vault.root / "new.md").write_text("x\n")

    vault.commit("Add new\nwith a second line", ["new.md"])

    line = (vault.root / changes_log(vault)).read_text().splitlines()[-1]
    assert line.endswith(" · Add new with a second line · new.md")
    assert line.startswith("- ")


def test_unchanged_files_make_no_commit(vault):
    before = vault._git("rev-parse", "HEAD")

    assert vault.commit("Nothing", ["keep.md"]) is None

    assert vault._git("rev-parse", "HEAD") == before
    assert not (vault.root / "agent").exists()


def test_names_are_literal_not_globs(vault):
    (vault.root / "draft [1].md").write_text("x\n")
    (vault.root / "draft 1.md").write_text("y\n")

    vault.commit("Add bracketed draft", ["draft [1].md"])

    assert "draft [1].md" in head_files(vault)
    assert "draft 1.md" not in head_files(vault)


@pytest.mark.parametrize(
    "message, paths, error",
    [
        ("  ", ["keep.md"], "message is empty"),
        ("x", [], "no paths"),
        ("x", ["../outside.md"], "not inside the vault"),
        ("x", [".git/config"], "inside the git directory"),
    ],
)
def test_rejects_bad_requests(vault, message, paths, error):
    with pytest.raises(ValueError, match=error):
        vault.commit(message, paths)


def test_cli_commit(vault, capsys):
    (vault.root / "new.md").write_text("x\n")

    vault_tools.main(["--vault", str(vault.root), "--identity", IDENTITY,
                      "commit", "--message", "Add new", "new.md"])

    assert capsys.readouterr().out.strip() == vault._git("rev-parse", "--short", "HEAD")
    assert "new.md" in head_files(vault)


from vault_tools import guard


@pytest.mark.parametrize(
    "path, action",
    [
        ("Notion/a.md", "block"),
        ("notion-attachments/x.png", "block"),
        (".obsidian/app.json", "block"),
        (".git/config", "block"),
        ("agent/changes/2026-09.md", "block"),
        ("agent/memory/USER.md", "block"),
        ("agent/memory/MEMORY.md", "block"),
        ("AGENTS.md", "approve"),
        ("journal/2026-09-25.md", None),
        ("agent/memory/people.md", None),
        ("Notionish.md", None),
        ("/etc/passwd", None),
    ],
)
def test_guard(vault, path, action):
    decision = guard(vault, path)
    assert (decision or {}).get("action") == action


def test_guard_absolute_path_inside_vault(vault):
    assert guard(vault, str(vault.root / "Notion" / "a.md"))["action"] == "block"


def test_guard_follows_symlinks(vault):
    (vault.root / "Notion").mkdir()
    (vault.root / "sneaky").symlink_to(vault.root / "Notion")
    assert guard(vault, "sneaky/a.md")["action"] == "block"
