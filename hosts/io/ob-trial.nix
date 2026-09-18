# Trial of Obsidian Sync as the vault transport (SPEC §4, decision 21),
# against a scratch vault so the Syncthing mesh stays untouched. The unit is
# dormant until the arming file exists; bootstrap steps are in
# docs/personal-agent/OB-TRIAL.md.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.custom.obsidian-headless ];

  # Obsidian Sync keeps version history server-side and reachable only from
  # the app, so the hub gets no audit trail from the transport itself. Point
  # the snapshot timer at the trial vault to supply one; dot-directories are
  # never uploaded, so .git stays hub-local without any exclusion config.
  services.vaultGit.path = "/var/lib/ob-trial/vault";

  # Setgid on the vault so everything created inside it lands in the vault
  # group, which is how the agent gets at files the sync daemon wrote.
  systemd.tmpfiles.rules = [
    "d /var/lib/ob-trial 0750 vault vault -"
    "d /var/lib/ob-trial/vault 2770 vault vault -"
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
      # Group-writable downloads, so the agent can edit a note the sync
      # daemon fetched rather than only replace it.
      UMask = "0007";
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
}
