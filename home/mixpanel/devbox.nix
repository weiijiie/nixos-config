# disable some of the config because it has already been
# configured in the devbox during provisioning
{ pkgs, ... }@args:
((common:
  common // {
    home = common.home // {
      packages = with pkgs; [
        manix
        tree
        yq-go
        tokei
        ranger
        tldr
        bottom
        nil
        nixfmt-classic
        bazel-buildtools
      ];
    };

    programs = common.programs // {
      ssh.enable = false;
      go.enable = false;

      git = common.programs.git // { ignores = [ "/go/.editorconfig" ]; };

      zsh = common.programs.zsh // {
        initExtra = common.programs.zsh.initExtra + "\n" + ''
          # devbox setup
          source ~/.gcpdevbox
          source ~/analytics/google-cloud/scripts/kube.sh

          function gcloud() {
            if [[ "$1" == "compute" && "$2" == "ssh" ]]; then
                TERM=xterm-256color command gcloud "$@"
            else
                command gcloud "$@"
            fi
          }
        '';

        envExtra = ''
          source $HOME/analytics/.shellenv
        '';

        shellAliases = common.programs.zsh.shellAliases // {
          shadow =
            "kubectl get pods --selector role=lqs-shadow -o json | ${pkgs.jq}/bin/jq -r '.items[0].metadata.name'";
        };
      };
    };
  }) (import ../common.nix args))
