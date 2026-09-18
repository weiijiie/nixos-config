#!/usr/bin/env python3
"""Check Vim input at startup using the installed Pi and tmux.

Run manually: python3 home/tests/pi-vim-startup.py
"""

import pathlib
import shlex
import shutil
import subprocess
import tempfile
import time


def main():
    pi_path = shutil.which("pi")
    assert pi_path, "pi must be installed"
    with tempfile.TemporaryDirectory(prefix="pi-vim-startup-") as test_dir:
        socket_path = str(pathlib.Path(test_dir) / "tmux.sock")

        def tmux(*args):
            return subprocess.run(
                ["tmux", "-S", socket_path, *args],
                check=True, capture_output=True, text=True,
            ).stdout

        def wait_for(predicate, description):
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                screen = tmux("capture-pane", "-p", "-t", "vim-test")
                if predicate(screen):
                    return
                time.sleep(0.1)
            raise AssertionError(f"Timed out waiting for {description}:\n{screen}")

        def type_text(text):
            tmux("send-keys", "-t", "vim-test", "-l", text)

        try:
            tmux(
                "new-session", "-d", "-s", "vim-test", "-x", "160", "-y", "45",
                shlex.join([pi_path, "--offline", "--no-session"]),
            )
            wait_for(
                lambda screen: any(
                    "vim" in [item.strip() for item in line.split("·")]
                    for line in screen.splitlines()
                ),
                "Vim status in the ready footer",
            )
            type_text("alpha beta")
            wait_for(lambda screen: "alpha beta" in screen, "inserted text")
            # CSI-u distinguishes Escape from an Alt prefix.
            type_text("\x1b[27u")
            wait_for(lambda screen: "NORMAL" in screen, "Escape to enter normal mode")
            type_text("0dw")
            wait_for(
                lambda screen: "NORMAL" in screen and "beta" in screen.splitlines(),
                "Esc + 0dw to delete the first word without toggling Vim",
            )
            type_text("iworks ")
            wait_for(
                lambda screen: "INSERT" in screen and "works beta" in screen.splitlines(),
                "i to return to insert mode",
            )
            print("PASS: Vim motions and insert mode work immediately after startup")
        finally:
            subprocess.run(
                ["tmux", "-S", socket_path, "kill-server"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )


if __name__ == "__main__":
    main()
