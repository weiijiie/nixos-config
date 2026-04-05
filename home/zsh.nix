{
  lib,
  pkgs,
  ...
}:
let
  zshCustomDir = pkgs.stdenv.mkDerivation {
    name = "ohmyzsh-custom-dir";
    src = ../dotfiles/ohmyzsh-custom;
    installPhase = ''
      mkdir -p $out/
      cp -rv $src/* $out/
    '';
  };
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history.size = 65536;

    shellAliases = { };

    initContent = lib.mkMerge [
      (
        with pkgs;
        lib.mkBefore ''
          # resolve issues where zsh-vi-mode overrides fzf key bindings
          zvm_after_init() {
            if [[ $options[zle] = on ]]; then
              . ${fzf}/share/fzf/completion.zsh
              . ${fzf}/share/fzf/key-bindings.zsh
            fi

            source ${zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
          }
        ''
      )

      (lib.mkAfter ''
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

        # kitty SSH issue workaround: https://wiki.archlinux.org/title/Kitty#Terminal_issues_with_SSH
        [ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"

        compdef __fnmcd=cd
      '')
    ];

    oh-my-zsh = {
      enable = true;
      extraConfig = ''
        ZSH_CUSTOM="${zshCustomDir}"
      '';

      plugins = [
        "git"
        "docker"
        "aws"
        "gcloud"
        "kubectl"
        "colored-man-pages"
        "fzf"
        "gh"
      ];
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
        src = lib.cleanSource ../dotfiles;
        file = ".p10k.zsh";
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
}
