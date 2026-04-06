# Shared nixpkgs configuration (overlays + allowUnfree).
# Imported by host configs and standalone home-manager configs.
{ outputs, ... }:
{
  nixpkgs = {
    overlays = [
      outputs.overlays.custom
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      outputs.overlays.llm-agents
    ];
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };
}
