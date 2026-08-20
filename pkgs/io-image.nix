# The hub's NixOS system as an OCI image.
#
# Layers come straight from the store closure, so no filesystem tree is
# materialized on the way. /init is NixOS's stage-2: it prepares the mounts,
# runs activation, and execs systemd as PID 1.
{
  dockerTools,
  toplevel,
}:
dockerTools.streamLayeredImage {
  name = "io";
  tag = "latest";

  contents = [ toplevel ];

  # systemd populates these at boot but will not create them.
  extraCommands = "mkdir -p proc sys dev";

  config.Entrypoint = [ "/init" ];
}
