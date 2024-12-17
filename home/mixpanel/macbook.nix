{ pkgs, ...}: {
  home.packages = [ pkgs.bazel ];

  programs = {
    git = {
      userEmail = "weijie.huang@mixpanel.com";
      userName = "weijie-mxpl";
    };

    ssh = {
      enable = true;
      compression = true;

      addKeysToAgent = "yes";
      controlPath = "~/.ssh/ctrl/%C";
      controlMaster = "auto";
      controlPersist = "yes";
      serverAliveInterval = 5;
      serverAliveCountMax = 2;

      extraConfig = ''
        UseKeychain yes
        ServerAliveCountMax 2
      '';

      matchBlocks = {
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

        devbox = {
          hostname = "devbox-5372";
          user = "weijie_huang";
          forwardAgent = true;
          extraOptions = {
            ProxyJump = "us-west2-a-oslogin-bastion";
          };
        };
      };
    };

    zsh.shellAliases = {
      devbox = "ssh -t devbox 'zsh -l'";
    };
  };
}
