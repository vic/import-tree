{
  inputs = {
    import-tree.url = "path:./..";
    nixpkgs.url = "github:nixos/nixpkgs/24.11";
    systems.url = "github:nix-systems/x86_64-linux";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    nix-unit.inputs.flake-parts.follows = "flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } ./.;

}
