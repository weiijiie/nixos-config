{ inputs, outputs, lib, config, pkgs, ... }:
with pkgs;
with lib;
let
  zshCustomDir = stdenv.mkDerivation {
    name = "ohmyzsh-custom-dir";
    src = ../dotfiles/ohmyzsh-custom;
    installPhase = ''
      mkdir -p $out/
      cp -rv $src/* $out/
    '';
  };
  # custom packages
  customPkgs = import ../pkgs { inherit pkgs; };
in {
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = (_: true);
    };
  };

  home.packages = [
    coreutils
    moreutils
    manix
    wget
    dig
    tree
    jq
    yq-go
    tokei
    ranger
    docker
    kubectl
    ngrok
    tldr
    gcc
    bottom
    grpc
    gotools
    delve
    nil
    nixfmt-classic
  ];

  # Enable home-manager
  programs.home-manager.enable = true;

  programs = {
    git = {
      enable = true;

      aliases = {
        ll =
          "log --pretty=format:'%C(yellow)%h %C(green)%ad%Cred%d %Creset%s%Cblue [%cn]' --decorate --date=short --graph";
        l = "log --all --oneline --graph --decorate";
        cidiff = ''
          log --date=format:"%Y-%m-%d %H:%M" --pretty="%C(cyan)%h%Creset %C(blue)[%ad]%Creset: %C(green)%s%Creset"'';
      };

      extraConfig = {
        merge = { conflictstyle = "diff3"; };

        diff = { colorMoved = "default"; };
      };

      delta = {
        enable = true;

        options = {
          navigate = true;
          side-by-side = true;
          theme = "Monokai Extended";
          features = "decorations";

          decorations = {
            file-style = "lightcoral bold ul";
            file-decoration-style = "blue ul";
            file-modified-label = "#";
            hunk-header-style = "line-number syntax bold";
            hunk-header-decoration-style = "lightcoral box";
            hunk-header-line-number-style = "lightcoral ul";
            hunk-label = "";
            line-numbers-zero-style = "lightslategray";
          };
        };
      };
    };

    vim = {
      enable = true;

      settings = { background = "dark"; };

      plugins = with pkgs.vimPlugins; [
        vim-airline
        vim-airline-themes
        vim-numbertoggle
        vim-surround
        vim-commentary
        vim-go
        vim-nix
        quick-scope
        rainbow
        ale
        nerdtree
        customPkgs.vim-colors-xcode
      ];

      extraConfig = builtins.readFile ../dotfiles/.vimrc;
    };

    ssh = {
      enable = true;
      compression = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    bat = {
      enable = true;
      config = { theme = "Monokai Extended"; };
    };

    eza = { enable = true; };

    direnv = {
      enable = true;
      stdlib = ''
        : "''${XDG_CACHE_HOME:="''${HOME}/.cache"}"
        declare -A direnv_layout_dirs
        direnv_layout_dir() {
            local hash path
            echo "''${direnv_layout_dirs[$PWD]:=$(
                hash="$(sha1sum - <<< "$PWD")"
                path="''${PWD//[^a-zA-Z0-9]/-}"
                echo "''${XDG_CACHE_HOME}/direnv/layouts/''${hash}''${path}"
            )}"
        }
      '';
      enableZshIntegration = true;
      nix-direnv = { enable = true; };
    };

    autojump = {
      enable = true;
      enableZshIntegration = true;
    };

    go = { enable = true; };

    zsh = {
      enable = true;
      enableCompletion = false;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      shellAliases = { };

      initExtraFirst = ''
        # resolve issues where zsh-vi-mode overrides fzf key bindings
        zvm_after_init() {
          if [[ $options[zle] = on ]]; then
            . ${fzf}/share/fzf/completion.zsh
            . ${fzf}/share/fzf/key-bindings.zsh
          fi
        }
      '';

      initExtra = ''
        if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then . $HOME/.nix-profile/etc/profile.d/nix.sh; fi

        path+=("''${HOME}/.local/bin")
        path+=("''${HOME}/go/bin")

        # zsh-autosuggestions configuration
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"
        ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=25

        # addding helper functions to fpath
        fpath=( "${zshCustomDir}/helpers" "''${fpath[@]}" )
        autoload -Uz ${zshCustomDir}/helpers/*

        # ctrl+j for "jq-zsh-plugin": https://github.com/reegnz/jq-zsh-plugin
        bindkey -v '^j' jq-complete

        # fix for zsh-autocomplete: https://nixos.wiki/wiki/Zsh#Troubleshooting
        if [[ "''${terminfo[kcuu1]}" != "" ]]; then
          bindkey -v "''${terminfo[kcuu1]}" up-line-or-search
        else
          bindkey -v '^[[A' up-line-or-search
        fi 

        # customize zsh-autocomplete tab behavior
        # adding `-v` to these commands (and to other bindkeys above) so that
        # they are added to zle `viins` keymap instead of `emacs`. probably
        # there is a better way of doing this
        bindkey -v              '^I'         menu-complete
        bindkey -v "$terminfo[kcbt]" reverse-menu-complete

        # kitty SSH issue workaround: https://wiki.archlinux.org/title/Kitty#Terminal_issues_with_SSH
        [ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"
      '';

      oh-my-zsh = {
        enable = true;
        extraConfig = ''
          ZSH_CUSTOM="${zshCustomDir}"
        '';

        plugins = [ "git" "docker" "aws" "gcloud" "kubectl" "colored-man-pages" ];
      };

      plugins = [
        {
          name = "vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
        {
          name = "powerlevel10k-config";
          src = cleanSource ../dotfiles;
          file = ".p10k.zsh";
        }
        {
          name = "zsh-autocomplete";
          src = pkgs.fetchFromGitHub {
            owner = "marlonrichert";
            repo = "zsh-autocomplete";
            rev = "762afacbf227ecd173e899d10a28a478b4c84a3f";
            sha256 = "sha256-o8IQszQ4/PLX1FlUvJpowR2Tev59N8lI20VymZ+Hp4w=";
          };
          file = "zsh-autocomplete.plugin.zsh";
        }
        {
          name = "you-should-use";
          src = pkgs.zsh-you-should-use;
          file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
        }
        {
          name = "jq-zsh-plugin";
          src = pkgs.fetchFromGitHub {
            owner = "reegnz";
            repo = "jq-zsh-plugin";
            rev = "48befbcd91229e48171d4aac5215da205c1f497e";
            sha256 = "sha256-q/xQZ850kifmd8rCMW+aAEhuA43vB9ZAW22sss9e4SE=";
          };
          file = "jq.plugin.zsh";
        }
      ];
    };

    gpg.enable = true;
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
