# nixos-config

My NixOS configurations

## Bootstrapping

1. Clone this repository

2. Install nix. [This](https://determinate.systems/posts/determinate-nix-installer/) installer works well.

3. Run `nix develop` inside the repository root. That should install most of the utilities needed to do further bootstrapping bepending on the system.

### WSL

TODO

### NixOS

Run:

```bash
 sudo nixos-rebuild switch --flake github:weiijiie/nixos-config/main#${HOSTNAME}
 ```

To apply the latest system configuration

### nix-darwin

To bootstrap:

```bash
nix run nix-darwin -- switch --flake github:weiijiie/nixos-config/main#${HOSTNAME}
```

After setup:

```bash
darwin-rebuild switch --flake github:weiijiie/nixos-config/main#${HOSTNAME}
```

### home-manager

Run:

```bash
home-manager switch --flake github:weiijiie/nixos-config/main#${USERNAME}@${HOSTNAME}
```

To apply the latest home-manager configuration. If you don't have home-manager installed, try running `nix --extra-experimental-features nix-command --extra-experimental-features flakes develop github:weiijiie/nixos-config/main` first.
