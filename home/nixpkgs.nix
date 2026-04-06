# Standalone nixpkgs configuration for home-manager configs
# that are NOT embedded in a NixOS/darwin host.
# (Embedded configs use useGlobalPkgs instead.)
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
