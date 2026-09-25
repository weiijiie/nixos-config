# Scheduled agent jobs every deployment of the hub should have.
#
# Hermes' scheduler owns cron/jobs.json and records run state in it, so the
# flake declares jobs here and a deploy-time step brings the scheduler in line
# through the `hermes cron` CLI. Jobs created from chat are left alone.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.hermes-agent;
  service = config.systemd.services.hermes-agent;
  hermesHome = "${cfg.stateDir}/.hermes";

  # name -> { schedule, prompt, skills ? [ ] }. Every job runs in the vault,
  # so it loads AGENTS.md, and reports to the Telegram home channel.
  jobs = { };

  declared = pkgs.writeText "hermes-cron-jobs.json" (builtins.toJSON jobs);

  syncJobs = pkgs.writeShellApplication {
    name = "hermes-cron-sync";
    runtimeInputs = [
      cfg.package
      pkgs.jq
    ];
    text = ''
      jobs_file=${hermesHome}/cron/jobs.json
      # Names this step has created, so a job dropped from the flake is
      # removed without touching jobs created from chat.
      managed=${hermesHome}/cron/nix-managed.json

      job_id() {
        [ -e "$jobs_file" ] || return 0
        jq -r --arg n "$1" '.jobs[] | select(.name == $n) | .id' "$jobs_file" | head -n 1
      }

      while IFS= read -r name; do
        job=$(jq -c --arg n "$name" '.[$n]' ${declared})
        schedule=$(jq -r '.schedule' <<<"$job")
        prompt=$(jq -r '.prompt' <<<"$job")

        flags=(--deliver telegram --workdir ${lib.escapeShellArg config.services.vaultGit.path})
        while IFS= read -r skill; do
          flags+=(--skill "$skill")
        done < <(jq -r '.skills // [] | .[]' <<<"$job")

        id=$(job_id "$name")
        if [ -n "$id" ]; then
          if [ "$(jq '.skills // [] | length' <<<"$job")" -eq 0 ]; then
            flags+=(--clear-skills)
          fi
          hermes cron edit "$id" --schedule "$schedule" --prompt "$prompt" "''${flags[@]}"
        else
          hermes cron create "$schedule" "$prompt" --name "$name" "''${flags[@]}"
        fi
      done < <(jq -r 'keys[]' ${declared})

      if [ -e "$managed" ]; then
        while IFS= read -r name; do
          if jq -e --arg n "$name" 'has($n)' ${declared} >/dev/null; then
            continue
          fi
          id=$(job_id "$name")
          if [ -n "$id" ]; then
            hermes cron remove "$id"
          fi
        done < <(jq -r '.[]' "$managed")
      fi

      jq 'keys' ${declared} >"$managed"
    '';
  };
in
{
  services.hermes-agent.settings = {
    # Left unset, a scheduled job gets Hermes' full default toolset, shell
    # included. Jobs read the day's conversations and the vault, and commit
    # what they write.
    platform_toolsets.cron = [
      "file"
      "session_search"
      "vault"
    ];
  };

  # Reruns whenever the declared jobs change, since they are part of ExecStart.
  systemd.services.hermes-cron-sync = {
    description = "Bring Hermes' scheduled jobs in line with the flake";
    wantedBy = [ "multi-user.target" ];
    after = [ "hermes-agent.service" ];

    # The same environment the gateway runs with, so the CLI finds the same
    # HERMES_HOME. PATH comes from `path` rather than being copied.
    environment = lib.removeAttrs service.environment [ "PATH" ];
    inherit (service) path;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = cfg.user;
      Group = cfg.group;
      ExecStart = lib.getExe syncJobs;
    };
  };
}
