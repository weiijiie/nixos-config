# disable some of the config because it has already been
# configured in the devbox during provisioning
{
  outputs,
  lib,
  pkgs,
  ...
}@args:
(
  (
    common:
    common
    // {
      home = common.home // {
        packages =
          (with pkgs; [
            manix
            tree
            yq-go
            tokei
            tldr
            bottom
            bazel-buildtools
            delve
            nixd
            nixfmt-rfc-style
            cachix
            custom.code2prompt
          ])
          ++ [ outputs.packages.${pkgs.stdenv.hostPlatform.system}.nvim ];
      };

      programs = common.programs // {
        ssh.enable = false;
        go.enable = false;

        git = common.programs.git // {
          ignores = [ "/go/.editorconfig" ];
        };

        zsh = common.programs.zsh // {
          initContent = lib.mkMerge [
            common.programs.zsh.initContent
            (lib.mkAfter ''
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
            '')
          ];

          envExtra = ''
            source $HOME/analytics/.shellenv
          '';

          shellAliases = common.programs.zsh.shellAliases // {
            bat = "${pkgs.bat}/bin/bat";
            shadow = "kubectl get pods --selector role=lqs-shadow -o json | ${pkgs.jq}/bin/jq -r '.items[0].metadata.name'";
            "perfflame.sh" = "~/analytics/tools/marcus/perfflame.sh";
            arb = "~/analytics/backend/arb/reader/arb";
          };
        };
      };
    }
  )
  (import ../common.nix args)
)
