"""MCP server giving the agent narrow write access to the vault's git history.

Serves over stdio; the vault is the directory in the VAULT_PATH environment
variable.
"""

import os
import subprocess
from pathlib import Path

from mcp.server.fastmcp import FastMCP

GIT = "@git@"
VAULT = Path(os.environ["VAULT_PATH"]).resolve()

server = FastMCP("vault")


@server.tool()
def commit(message: str, paths: list[str]) -> str:
    """Commit files in the vault to git, with a message saying what changed.

    List every file this change created, edited, renamed or deleted, as paths
    relative to the vault root. Only those files are committed; other pending
    changes in the vault are left alone. Returns the new commit's short hash.
    """
    if not message.strip():
        raise ValueError("the commit message is empty")
    if not paths:
        raise ValueError("no paths given")

    relative = [_vault_relative(p) for p in paths]

    _git("add", "--all", "--", *relative)
    _git("commit", "--quiet", "--only", "--message", message, "--", *relative)
    return _git("rev-parse", "--short", "HEAD")


def _vault_relative(path: str) -> str:
    # resolve() follows symlinks, so a link pointing out of the vault is
    # refused along with ../ escapes.
    full = (VAULT / path).resolve()
    if VAULT not in full.parents:
        raise ValueError(f"{path} is not inside the vault")

    relative = full.relative_to(VAULT)
    if relative.parts[0] == ".git":
        raise ValueError(f"{path} is inside the git directory")
    return str(relative)


def _git(*args: str) -> str:
    result = subprocess.run(
        [GIT, *args],
        cwd=VAULT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


if __name__ == "__main__":
    server.run()
