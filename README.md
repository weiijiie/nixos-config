# nixos-config

My NixOS configurations

## Bootstrapping on WSL

TODO

## NixOS

Run:

```bash
 sudo nixos-rebuild switch --flake github:weiijiie/nixos-config/main#hostname
 ```

To apply the latest system configuration

## home-manager

Run:

```bash
home-manager switch --flake github:weiijiie/nixos-config/main#username@hostname
```

To apply the latest home-manager configuration. If you don't have home-manager installed, try running `nix develop github:weiijiie/nixos-config/main` first.