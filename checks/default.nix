{ inputs, ... }:
{
  imports = [
    inputs.nix-unit.modules.flake.default
    ./tests.nix
    ./treefmt.nix
  ];
  systems = import inputs.systems;
}
