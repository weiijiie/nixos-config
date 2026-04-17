{ pkgs, ... }:
let
  zellij-zellaude = pkgs.fetchurl {
    url = "https://github.com/ishefi/zellaude/releases/latest/download/zellaude.wasm";
    hash = "sha256-HWtHklUKLQgzpr8ndxhOz5urQWwXi0nDF7XhsM2ELCQ=";
  };
in
{
  programs.zellij = {
    enable = true;
    # enableZshIntegration = true;
    # attachExistingSession = true;
    # exitShellOnExit = true;
    settings = {
      default_mode = "locked";
      default_shell = "zsh";
    };
    extraConfig = ''
      // Overrides: bare keys for mode switching, actions return to locked
      keybinds {
        pane {
          bind "p" { SwitchToMode "normal"; }
          bind "d" { NewPane "Down"; SwitchToMode "locked"; }
          bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "locked"; }
          bind "f" { ToggleFocusFullscreen; SwitchToMode "locked"; }
          bind "i" { TogglePanePinned; SwitchToMode "locked"; }
          bind "n" { NewPane; SwitchToMode "locked"; }
          bind "r" { NewPane "Right"; SwitchToMode "locked"; }
          bind "w" { ToggleFloatingPanes; SwitchToMode "locked"; }
          bind "x" { CloseFocus; SwitchToMode "locked"; }
          bind "z" { TogglePaneFrames; SwitchToMode "locked"; }
        }
        tab {
          bind "t" { SwitchToMode "normal"; }
          bind "1" { GoToTab 1; SwitchToMode "locked"; }
          bind "2" { GoToTab 2; SwitchToMode "locked"; }
          bind "3" { GoToTab 3; SwitchToMode "locked"; }
          bind "4" { GoToTab 4; SwitchToMode "locked"; }
          bind "5" { GoToTab 5; SwitchToMode "locked"; }
          bind "6" { GoToTab 6; SwitchToMode "locked"; }
          bind "7" { GoToTab 7; SwitchToMode "locked"; }
          bind "8" { GoToTab 8; SwitchToMode "locked"; }
          bind "9" { GoToTab 9; SwitchToMode "locked"; }
          bind "[" { BreakPaneLeft; SwitchToMode "locked"; }
          bind "]" { BreakPaneRight; SwitchToMode "locked"; }
          bind "b" { BreakPane; SwitchToMode "locked"; }
          bind "n" { NewTab; SwitchToMode "locked"; }
          bind "s" { ToggleActiveSyncTab; SwitchToMode "locked"; }
          bind "x" { CloseTab; SwitchToMode "locked"; }
        }
        resize {
          bind "r" { SwitchToMode "normal"; }
        }
        move {
          bind "m" { SwitchToMode "normal"; }
        }
        scroll {
          bind "s" { SwitchToMode "normal"; }
          bind "e" { EditScrollback; SwitchToMode "locked"; }
        }
        session {
          bind "o" { SwitchToMode "normal"; }
          bind "a" {
            LaunchOrFocusPlugin "zellij:about" {
              floating true
              move_to_focused_tab true
            }
            SwitchToMode "locked"
          }
          bind "c" {
            LaunchOrFocusPlugin "configuration" {
              floating true
              move_to_focused_tab true
            }
            SwitchToMode "locked"
          }
          bind "p" {
            LaunchOrFocusPlugin "plugin-manager" {
              floating true
              move_to_focused_tab true
            }
            SwitchToMode "locked"
          }
          bind "w" {
            LaunchOrFocusPlugin "session-manager" {
              floating true
              move_to_focused_tab true
            }
            SwitchToMode "locked"
          }
        }
        shared_except "locked" "entersearch" {
          bind "enter" { SwitchToMode "locked"; }
        }
        shared_except "locked" "entersearch" "renametab" "renamepane" {
          bind "esc" { SwitchToMode "locked"; }
        }
        shared_except "locked" "entersearch" "renametab" "renamepane" {
          bind "w" { ToggleFloatingPanes; SwitchToMode "locked"; }
        }
        shared_except "locked" "entersearch" "renametab" "renamepane" "move" {
          bind "m" { SwitchToMode "move"; }
        }
        shared_except "locked" "entersearch" "search" "renametab" "renamepane" "session" {
          bind "o" { SwitchToMode "session"; }
        }
        shared_except "locked" "tab" "entersearch" "renametab" "renamepane" {
          bind "t" { SwitchToMode "tab"; }
        }
        shared_except "locked" "tab" "scroll" "entersearch" "renametab" "renamepane" {
          bind "s" { SwitchToMode "scroll"; }
        }
        shared_among "normal" "resize" "tab" "scroll" "prompt" "tmux" {
          bind "p" { SwitchToMode "pane"; }
        }
        shared_except "locked" "resize" "pane" "tab" "entersearch" "renametab" "renamepane" {
          bind "r" { SwitchToMode "resize"; }
        }
        shared_among "scroll" "search" {
          bind "Ctrl c" { ScrollToBottom; SwitchToMode "locked"; }
        }
        // Ctrl+h/l for zellij pane navigation in all modes
        locked {
          bind "Ctrl h" { MoveFocusOrTab "left"; }
          bind "Ctrl l" { MoveFocusOrTab "right"; }
        }
        shared_except "locked" {
          bind "Ctrl h" { MoveFocusOrTab "left"; }
          bind "Ctrl j" { MoveFocus "down"; }
          bind "Ctrl k" { MoveFocus "up"; }
          bind "Ctrl l" { MoveFocusOrTab "right"; }
        }
      }
    '';
  };

  # Zellij layout with zellaude tab bar
  xdg.configFile."zellij/layouts/default.kdl".text = ''
    layout {
      default_tab_template {
        pane size=1 borderless=true {
          plugin location="file:${zellij-zellaude}"
        }
        children
        pane size=1 borderless=true {
          plugin location="status-bar"
        }
      }
    }
  '';
}
