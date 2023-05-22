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
in
{
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

  home = {
    username = "weijie";
    homeDirectory = "/home/weijie";
  };

  home.packages = [
    coreutils
    moreutils
    wget
    tree
    nginx
    jq
    yq-go
    tokei
    ranger
    docker
    kubectl
    ngrok
    terraform
    tldr
    gcc
  ];

  # Enable home-manager
  programs.home-manager.enable = true;

  programs = {
    git = {
      enable = true;
      userEmail = "43085321+weiijiie@users.noreply.github.com";
      userName = "Huang Weijie";

      aliases = {
        ll = "log --pretty=format:'%C(yellow)%h\ %C(green)%ad%Cred%d\ %Creset%s%Cblue\ [%cn]' --decorate --date=short --graph";
        l = "log --all --oneline --graph --decorate";
        cidiff = "log --date=format:\"%Y-%m-%d %H:%M\" --pretty=\"%C(cyan)%h%Creset %C(blue)[%ad]%Creset: %C(green)%s%Creset\"";
      };

      extraConfig = {
        merge = {
          conflictstyle = "diff3";
        };

        diff = {
          colorMoved = "default";
        };
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

      settings = {
        background = "dark";
      };

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
        outputs.packages."x86_64-linux".vim-colors-xcode
      ];

      extraConfig = ''
        syntax enable           " enable syntax processing
        set tabstop=4           " number of visual spaces per TAB
        set softtabstop=4       " number of spaces in tab when editing
        set expandtab           " tabs are spaces
        set showcmd             " show command in bottom bar
        set number              " show line numbers 
        set scrolloff=2
        
        set ai "Auto indent
        set si "Smart indent
        set wrap "Wrap lines
        
        filetype indent on      " load filetype-specific indent files
        set wildmenu            " visual autocomplete for command menu
        set lazyredraw          " redraw only when we need to.
        set showmatch           " highlight matching [{()}]
        
        set incsearch           " search as characters are entered
        set hlsearch            " highlight matches

        augroup qs_colors
          autocmd!
          autocmd ColorScheme * highlight QuickScopePrimary guifg='#afff5f' gui=underline ctermfg=155 cterm=underline
          autocmd ColorScheme * highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline
        augroup END

        set termguicolors
        colorscheme xcodedarkhc 

        " transparent background
        highlight Normal guibg=NONE ctermbg=NONE
        highlight NonText guibg=NONE ctermbg=NONE
        highlight EndOfBuffer guibg=NONE ctermbg=NONE

        " vim airline theme
        let g:airline_theme='bubblegum'

        let g:airline_powerline_fonts=1
        let g:airline_left_sep = "\uE0B8"
        let g:airline_right_sep = "\uE0BE"
        
        set guifont=Cascadia\ Mono\ PL

        " Enable completion where available.
        " This setting must be set before ALE is loaded.
        "
        " You should not turn this setting on if you wish to use ALE as a completion
        " source for other completion plugins, like Deoplete.
        let g:ale_completion_enabled = 1

        " Rainbow brackets config
        let g:rainbow_active = 1
        let g:rainbow_conf = {
        \	'guifgs': ['slateblue3', 'skyblue2', 'turquoise2', 'lightgreen'],
        \	'separately': {
        \		'nerdtree': 0,
        \	}
        \}

        " quick-scope config
        let g:qs_highlight_on_keys = ['f', 'F', 't', 'T']

        " Cursor in terminal
        " https://vim.fandom.com/wiki/Configuring_the_cursor
        " 1 or 0 -> blinking block
        " 2 solid block
        " 3 -> blinking underscore
        " 4 solid underscore
        " Recent versions of xterm (282 or above) also support
        " 5 -> blinking vertical bar
        " 6 -> solid vertical bar

        if &term =~ "xterm\\|rxvt"
          " normal mode
          let &t_EI .= "\<Esc>[1 q"
          " insert mode
          let &t_SI .= "\<Esc>[5 q"

          " Reset cursor on startup
          augroup ResetCursorShape
          au!
          autocmd VimEnter * normal! :startinsert :stopinsert
          augroup END
        endif
      '';
    };

    ssh = {
      enable = true;
      compression = true;
    };

    fzf = {
      enable = true;
    };

    bat = {
      enable = true;
      config = {
        theme = "Monokai Extended"; 
      };
    };

    exa = {
      enable = true;
      enableAliases = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv = {
        enable = true;
      };
    };

    autojump = {
      enable = true;
      enableZshIntegration = true;
    };

    go = {
      enable = true;
    };

    zsh = {
      enable = true;
      enableCompletion = true;

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

        # zsh-vi-mode
        source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh

        # addding helper functions to fpath
        fpath=( "${zshCustomDir}/helpers" "''${fpath[@]}" )
        autoload -Uz ${zshCustomDir}/helpers/*
      '';

      oh-my-zsh = {
        enable = true;
        extraConfig = ''
          ZSH_CUSTOM="${zshCustomDir}"
        '';

        plugins = [
          "git"
          "docker"
          "aws"
          "kubectl"
          "colored-man-pages"
        ];
      };

      plugins = [
        {
          name = "powerlevel10k-config";
          src = cleanSource ../dotfiles;
          file = ".p10k.zsh";
        }
      ];

      zplug = {
        enable = true;
        plugins = [
          {
            name = "djui/alias-tips";
          }
          {
            name = "romkatv/powerlevel10k";
            tags = [ as:theme depth:1 ];
          }
          {
            name = "zdharma-continuum/fast-syntax-highlighting";
          }
          {
            name = "zsh-users/zsh-autosuggestions";
          }
          {
            name = "reegnz/jq-zsh-plugin";
          }
          {
            name = "tribela/vim-transparent";
          }
        ];
      };
    };

    gpg.enable = true;
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "22.11";
}
