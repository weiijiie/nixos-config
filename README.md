# nixos-config

My NixOS configurations

## Bootstrapping

1. Clone this repository

2. Install nix. [This](https://determinate.systems/posts/determinate-nix-installer/) installer works well.

3. Run `nix develop` inside the repository root. That should install most of the utilities needed to do further bootstrapping bepending on the system.

### WSL

This sets up a full NixOS system inside WSL using [NixOS-WSL](https://github.com/nix-community/NixOS-WSL).

#### Prerequisites

- Windows 10 (build 2004+) or Windows 11
- WSL enabled (`wsl --install` from an admin PowerShell if not already)

#### Steps

1. Download the latest NixOS-WSL tarball from the [NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases) page (the `nixos-wsl.tar.gz` file).

2. Import it as a new WSL distro from PowerShell:

   ```powershell
   wsl --import NixOS $env:USERPROFILE\NixOS nixos-wsl.tar.gz
   ```

3. Launch the distro:

   ```powershell
   wsl -d NixOS
   ```

4. Inside the NixOS shell, clone this repo and apply the system configuration:

   ```bash
   nix-shell -p git
   git clone https://github.com/weiijiie/nixos-config.git ~/nixos-config
   cd ~/nixos-config
   sudo nixos-rebuild switch --flake .#${HOSTNAME}
   ```

5. Restart the distro from PowerShell to pick up all changes:

   ```powershell
   wsl --terminate NixOS
   wsl -d NixOS
   ```

### NixOS

```bash
sudo nixos-rebuild switch --flake github:weiijiie/nixos-config/main#${HOSTNAME}
```

This applies both the system and home-manager configuration.

### nix-darwin

To bootstrap:

```bash
nix run nix-darwin -- switch --flake github:weiijiie/nixos-config/main#${HOSTNAME}
```

After setup:

```bash
darwin-rebuild switch --flake github:weiijiie/nixos-config/main#${HOSTNAME}
```

This applies both the system and home-manager configuration.

### home-manager (standalone)

For hosts that don't run NixOS or nix-darwin (e.g. devboxes):

```bash
home-manager switch --flake github:weiijiie/nixos-config/main#${USERNAME}@${HOSTNAME}
```

If you don't have home-manager installed, run `nix --extra-experimental-features nix-command --extra-experimental-features flakes develop github:weiijiie/nixos-config/main` first.
