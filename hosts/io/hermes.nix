# The agent runtime (SPEC sections 3 and 6).
#
# Upstream ships the NixOS module, so this only supplies policy: which model,
# which credentials, which directory the agent works in, and what it is
# allowed to do from Telegram.
{
  inputs,
  config,
  pkgs,
  ...
}:
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  # Decision 19: the vault is reached through group membership rather than by
  # running the agent as the vault owner.
  users.users.hermes.extraGroups = [ config.services.vaultGit.group ];

  services.hermes-agent = {
    enable = true;

    # Upstream's default pre-builds every optional integration -- DingTalk,
    # Feishu, Matrix, Vercel, a speech stack -- for an agent that is 82 MB
    # itself. Taking the minimal build with only the groups this hub uses, and
    # the headless ffmpeg (whose full build reaches clang and llvm for another
    # 1.4 GB), is 1.6 GB against the default's 4.2 GB.
    package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal.override {
      ffmpeg = pkgs.ffmpeg-headless;
      extraDependencyGroups = [
        "anthropic"
        "messaging"
      ];
    };

    # Deployed out of band (decision 18); a Nix path literal would copy the
    # secrets into the world-readable store.
    environmentFiles = [ "/var/lib/secrets/hermes.env" ];

    settings = {
      # Where the file and terminal tools operate. Set here rather than via
      # workingDirectory, which the upstream module chowns to the agent's own
      # user and group -- that would lock the vault user out of the vault and
      # stop both the snapshot timer and Obsidian Sync.
      terminal.cwd = config.services.vaultGit.path;

      model = {
        default = "anthropic/claude-opus-4.6";
        # Direct Anthropic rather than a reseller, so the key we hold is the
        # one being billed and capped.
        provider = "anthropic";
      };

      # A skill file is a persistent instruction store that untrusted input
      # can reach, so the agent does not get nudged into writing them while
      # the review loop is still unproven (SPEC section 6).
      skills.creation_nudge_interval = 0;

      # Telegram is the only inbound human channel and the likeliest path for
      # injected instructions, so it starts without a shell, without skill
      # authoring and without cron. Widen once the review loop has earned it.
      platform_toolsets.telegram = [
        "web"
        "vision"
        "file"
        "todo"
      ];
    };
  };

  # The module only grants the sandbox write access to workingDirectory.
  systemd.services.hermes-agent.serviceConfig.ReadWritePaths = [
    config.services.vaultGit.path
  ];
}
