{
  description = "A simple netboot script";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
    }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      lib = import ./lib/lib.nix { };
      nixosModules.default = import ./modules/nxbooter;

      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          disko-partition-helper = pkgs.callPackage ./pkgs/disko-partition-helper { };
          default = self.packages.${system}.disko-partition-helper;
        });
    };
}
