# nixos-config

My NixOS configurations

## Bootstrapping on WSL

TODO

## NixOS

Run:

```bash
 sudo nixos-rebuild switch --flake github:weiijiie/nixos-config/main#${HOSTNAME}
 ```

To apply the latest system configuration

## home-manager

Run:

```bash
home-manager switch --flake github:weiijiie/nixos-config/main#${USERNAME}@${HOSTNAME}
```

To apply the latest home-manager configuration. If you don't have home-manager installed, try running `nix --extra-experimental-features nix-command --extra-experimental-features flakes develop github:weiijiie/nixos-config/main` first.
