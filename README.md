# nxbooter

A simple NixOS module and library for netbooting a NixOS system using `pixiecore`.

## About

`nxbooter` provides a NixOS module that configures a systemd service to run `pixiecore`. This allows you to easily netboot a NixOS system over the network.

The module uses the system's built kernel and initrd to serve them via `pixiecore` on port 64172 with ProxyDHCP enabled by default.

## Module Usage

To use `nxbooter`, you can add it to your NixOS configuration as a module from this flake. You must also provide a package for the `nxbooter` service.

### Example NixOS Configuration

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nxbooter.url = "github:your-username/nxbooter"; # Replace with the actual URL
  };

  outputs = { self, nixpkgs, nxbooter }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        nxbooter.nixosModules.default
      ];
    };
  };
}
```

```nix
# configuration.nix
{
  services.nxbooter = {
    enable = true;
    package = nxbooter.lib.buildNxbooter {
      inherit pkgs;
      systemConfig = self.nixosConfigurations.my-machine;
    };
  };
}
```

## Library Usage

This flake also provides a small library of helper functions.

### `buildNxbooter`

A helper function that generates a script to run `pixiecore`. This function takes `pkgs` and `systemConfig` as arguments and returns a package that runs `pixiecore`.

#### Example `flake.nix`

Here is an example of how to use `buildNxbooter` to create a `devShell` with a `pxicore` package that serves the configuration of `my-machine`.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nxboot.url = "github:your-username/nxboot"; # Replace with the actual URL
  };

  outputs = { self, nixpkgs, nxboot }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          # Your other modules
        ];
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          (nxboot.lib.buildNxbooter {
            inherit pkgs;
            systemConfig = self.nixosConfigurations.my-machine;
          })
        ];
      };
    };
}
```

### `buildBtrfsRaid`

A helper function to configure `disko` for a BTRFS RAID setup.

#### Usage

```nix
{
  # ...
  imports = [
    (import (pkgs.path + "/nixos/modules/installer/disko/disko.nix"))
  ];

  # ...
  disko.devices = nxbooter.lib.buildBtrfsRaid {
    mainDisk = "/dev/sda";
    extraDisks = [ "/dev/sdb" ];
    raidLevel = "raid1";
  };
  # ...
}
```