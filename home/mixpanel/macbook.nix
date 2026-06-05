{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bazel
    google-cloud-sdk
  ];

  programs = {
    git.settings.user = {
      email = "weijie.huang@mixpanel.com";
      name = "weijie-mxpl";
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings = {
        "*" = {
          IgnoreUnknown = "UseKeychain";
          UseKeychain = "yes";
          Compression = true;
          AddKeysToAgent = "yes";
          ControlPath = "~/.ssh/ctrl/%C";
          ControlMaster = "auto";
          ControlPersist = "yes";
          ServerAliveInterval = 5;
          ServerAliveCountMax = 2;
        };

        "us-central1-b-oslogin-bastion" = {
          HostName = "central-oslogin-v2-bastion.mixpanel.org";
          User = "weijie_huang";
        };

        "us-east4-a-oslogin-bastion" = {
          HostName = "east-oslogin-v2-bastion.mixpanel.org";
          User = "weijie_huang";
        };

        "europe-west4-a-oslogin-bastion" = {
          HostName = "eu-oslogin-v2-bastion.mixpanel.org";
          User = "weijie_huang";
        };

        "asia-south1-a-oslogin-bastion" = {
          HostName = "in-dev-bastion.mixpanel.org";
          User = "weijie_huang";
        };

        "us-west2-a-oslogin-bastion" = {
          HostName = "west-oslogin-v2-bastion.mixpanel.org";
          User = "weijie_huang";
        };

        devbox = {
          HostName = "devbox-7700";
          User = "weijie_huang";
          ForwardAgent = true;
          LocalForward = {
            bind.address = "localhost";
            bind.port = 8080;
            host.address = "localhost";
            host.port = 8080;
          };
          ProxyCommand = "gcloud compute start-iap-tunnel %h %p --listen-on-stdin --project=mixpanel-dev-1 --zone=us-west2-a --quiet";
        };

        devbox-spare = {
          HostName = "devbox-9983";
          User = "weijie_huang";
          ForwardAgent = true;
          ProxyCommand = "gcloud compute start-iap-tunnel %h %p --listen-on-stdin --project=mixpanel-dev-1 --zone=us-west2-a --quiet";
        };

        devbox-arm = {
          HostName = "devbox-5924";
          User = "weijie_huang";
          ForwardAgent = true;
          ProxyCommand = "gcloud compute start-iap-tunnel %h %p --listen-on-stdin --project=mixpanel-dev-1 --zone=us-central1-b --quiet";
        };
      };
    };

    zsh.shellAliases = {
      devbox = "ssh -t devbox 'cd ~/analytics && zsh -l'";
      devbox-spare = "ssh -t devbox-spare 'cd ~/analytics && zsh -l'";
      devbox-arm = "ssh -t devbox-arm 'cd ~/analytics && zsh -l'";
    };
  };
}
