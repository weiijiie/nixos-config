"""Narrow git access to the vault for the agent.

Serves the MCP `commit` tool, handles Hermes shell-hook events and commits
from the command line; run `vault-tools --help`.
"""

import argparse
import datetime
import re
import subprocess
from pathlib import Path

GIT = "@git@"

CHANGES_DIR = Path("agent/changes")


class Vault:
    """A vault checkout, committed to under one git identity."""

    def __init__(self, root, identity):
        self.root = Path(root).resolve()
        name, email = _parse_identity(identity)
        self._config = ["-c", f"user.name={name}", "-c", f"user.email={email}"]

    def relative(self, path):
        """The path relative to the vault root.

        Relative paths resolve against the vault root, and resolve() follows
        symlinks, so a link pointing out of the vault or into a blocked
        folder is judged by where it leads.
        """
        full = (self.root / path).resolve()
        if self.root not in full.parents:
            raise ValueError(f"{path} is not inside the vault")
        return full.relative_to(self.root)

    def commit(self, message, paths):
        """Commit the named files and log the commit in agent/changes/.

        Returns the new commit's short hash, or None when the named files
        hold no changes.
        """
        if not message.strip():
            raise ValueError("the commit message is empty")
        if not paths:
            raise ValueError("no paths given")
        relative = [self._committable(p) for p in paths]

        self._git("add", "--all", "--", *relative)
        if self._run("diff", "--cached", "--quiet", "--", *relative).returncode == 0:
            return None

        changes = self._log_change(message, relative)
        self._git("add", "--", changes)
        self._git("commit", "--quiet", "--only", "--message", message,
                  "--", *relative, changes)
        return self._git("rev-parse", "--short", "HEAD")

    def _committable(self, path):
        relative = self.relative(path)
        if relative.parts[0] == ".git":
            raise ValueError(f"{path} is inside the git directory")
        return relative.as_posix()

    def _log_change(self, message, relative):
        now = datetime.datetime.now().astimezone()
        log = self.root / CHANGES_DIR / f"{now:%Y-%m}.md"
        log.parent.mkdir(parents=True, exist_ok=True)

        summary = " ".join(message.split())
        with log.open("a", encoding="utf-8") as f:
            f.write(f"- {now:%Y-%m-%d %H:%M} · {summary} · "
                    f"{', '.join(relative)}\n")
        return log.relative_to(self.root).as_posix()

    def _git(self, *args):
        result = self._run(*args)
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip())
        return result.stdout.strip()

    def _run(self, *args):
        # Literal pathspecs, so a note named "draft [1].md" is not a glob.
        return subprocess.run(
            [GIT, "--literal-pathspecs", *self._config, *args],
            cwd=self.root,
            capture_output=True,
            text=True,
        )


def _parse_identity(identity):
    match = re.fullmatch(r"\s*(.+?)\s*<([^>]+)>\s*", identity)
    if not match:
        raise ValueError(f'identity must be "Name <email>", got {identity!r}')
    return match.group(1), match.group(2)


def main(argv=None):
    parser = argparse.ArgumentParser(prog="vault-tools")
    parser.parse_args(argv)


if __name__ == "__main__":
    main()
