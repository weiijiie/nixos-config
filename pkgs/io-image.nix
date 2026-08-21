# The hub's NixOS system as an OCI image for exe.dev.
#
# Layers come straight from the store closure, so no filesystem tree is
# materialized on the way. exe.dev runs its exe-init shim and then /init,
# NixOS's stage-2, which runs activation and execs systemd as PID 1.
{
  dockerTools,
  toplevel,
}:
dockerTools.streamLayeredImage {
  name = "io";
  tag = "latest";

  contents = [ toplevel ];

  # Register the closure in the Nix database; without it every nix invocation
  # on the box, activation included, rejects the store paths as invalid.
  includeNixDB = true;

  # exe-init runs before NixOS activation, so everything it touches has to
  # exist in the image already:
  #  - /etc must be a real, writable directory (toplevel links it into the
  #    store), because exe-init writes resolv.conf, hostname and hosts;
  #  - /etc/passwd needs the login user and its sshd's privilege-separation
  #    account;
  #  - login shells resolve through /bin before /run/current-system exists.
  fakeRootCommands = ''
    rm -f etc
    mkdir -p proc sys dev etc bin home/wj root var/empty

    printf '%s\n' \
      'root:x:0:0:System administrator:/root:/bin/exe-shell' \
      'sshd:x:22:22:SSH privilege separation user:/var/empty:/bin/sh' \
      'wj:x:1000:100:wj:/home/wj:/bin/exe-shell' \
      > etc/passwd
    printf '%s\n' \
      'root:x:0:' \
      'wheel:x:1:wj' \
      'sshd:x:22:' \
      'users:x:100:wj' \
      > etc/group
    : > etc/machine-id

    ln -s /sw/bin/exe-shell bin/exe-shell
    ln -s exe-shell bin/sh
    ln -s exe-shell bin/bash

    chown 1000:100 home/wj
  '';

  config = {
    Cmd = [ "/init" ];
    Env = [
      "container=oci"
      "PATH=/run/current-system/sw/bin:/sw/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    ];
    WorkingDir = "/home/wj";
    # exe.dev picks its proxy target from the exposed ports.
    ExposedPorts."8000/tcp" = { };
    Labels."exe.dev/login-user" = "wj";
  };
}
