{ pkgs, ... }:
{
  home.packages = [ pkgs.bazel ];

  programs = {
    git.settings.user = {
      email = "weijie.huang@mixpanel.com";
      name = "weijie-mxpl";
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;

      extraConfig = ''
        IgnoreUnknown UseKeychain
        UseKeychain yes
      '';

      matchBlocks = {
        "*" = {
          compression = true;
          extraOptions = {
            AddKeysToAgent = "yes";
            ControlPath = "~/.ssh/ctrl/%C";
            ControlMaster = "auto";
            ControlPersist = "yes";
            ServerAliveInterval = "5";
            ServerAliveCountMax = "2";
          };
        };

        "us-central1-b-oslogin-bastion" = {
          hostname = "central-oslogin-v2-bastion.mixpanel.org";
          user = "weijie_huang";
        };

        "us-east4-a-oslogin-bastion" = {
          hostname = "east-oslogin-v2-bastion.mixpanel.org";
          user = "weijie_huang";
        };

        "europe-west4-a-oslogin-bastion" = {
          hostname = "eu-oslogin-v2-bastion.mixpanel.org";
          user = "weijie_huang";
        };

        "asia-south1-a-oslogin-bastion" = {
          hostname = "in-dev-bastion.mixpanel.org";
          user = "weijie_huang";
        };

        "us-west2-a-oslogin-bastion" = {
          hostname = "west-oslogin-v2-bastion.mixpanel.org";
          user = "weijie_huang";
        };

        devbox-old = {
          hostname = "devbox-5372";
          user = "weijie_huang";
          forwardAgent = true;
          extraOptions = {
            ProxyJump = "us-west2-a-oslogin-bastion";
          };
        };

        devbox = {
          hostname = "devbox-7700";
          user = "weijie_huang";
          forwardAgent = true;
          localForwards = [
            {
              bind.address = "localhost";
              bind.port = 8080;
              host.address = "localhost";
              host.port = 8080;
            }
          ];
          extraOptions = {
            ProxyJump = "us-west2-a-oslogin-bastion";
          };
        };

        devbox-spare = {
          hostname = "devbox-9983";
          user = "weijie_huang";
          forwardAgent = true;
          extraOptions = {
            ProxyJump = "us-west2-a-oslogin-bastion";
          };
        };

        devbox-arm = {
          hostname = "devbox-5924";
          user = "weijie_huang";
          forwardAgent = true;
          extraOptions = {
            ProxyJump = "us-central1-b-oslogin-bastion";
          };
        };
      };
    };

    zsh.shellAliases = {
      devbox-old = "ssh -t devbox-old 'cd analytics && zsh -l'";
      devbox = "ssh -t devbox 'cd ~/analytics && zsh -l'";
      devbox-spare = "ssh -t devbox-spare 'cd ~/analytics && zsh -l'";
      devbox-arm = "ssh -t devbox-arm 'cd ~/analytics && zsh -l'";
    };
  };
}
