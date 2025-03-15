{
  inputs.target.url = "github:vic/import-tree?dir=checks";
  inputs.checkmate.url = "github:vic/checkmate";
  inputs.checkmate.inputs.target.follows = "target";

  outputs = inputs: {
    flakeModules.nix-unit = ./flakeModule.nix;
  };

  #outputs =
  #  inputs:
  #  inputs.checkmate.outputs
  #  // {
  #    flakeModules.nix-unit = ./flakeModule.nix;
  #  };
}
