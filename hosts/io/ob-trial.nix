# Trial of Obsidian Sync as the vault transport (SPEC §4, decision 21),
# against a scratch vault so the Syncthing mesh stays untouched. The unit is
# dormant until the arming file exists; bootstrap steps are in
# docs/personal-agent/OB-TRIAL.md.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.custom.obsidian-headless ];

  systemd.tmpfiles.rules = [
    "d /var/lib/ob-trial 0750 vault vault -"
    "d /var/lib/ob-trial/vault 0750 vault vault -"
  ];

  systemd.services.ob-sync-trial = {
    description = "Obsidian Sync continuous sync (trial vault)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    # Armed by hand once `ob login` and `ob sync-setup` have run; keeps the
    # unit inert on deploys that precede the account.
    unitConfig.ConditionPathExists = "/var/lib/ob-trial/armed";
    serviceConfig = {
      User = "vault";
      Group = "vault";
      StateDirectory = "ob-trial";
      # ob keeps its auth token and per-path sync config under $HOME.
      Environment = "HOME=/var/lib/ob-trial";
      ExecStart = "${pkgs.custom.obsidian-headless}/bin/ob sync --continuous --path /var/lib/ob-trial/vault";
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
}
