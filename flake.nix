{
  description = "A simlpe netboot script";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    {
      nixpkgs,
    }:
    {
      lib = import ./lib/lib.nix { };
      nixosModules.default = import ./modules/nxbooter;
    };
}

