{
  inputs.import-tree.url = "github:vic/import-tree";

  outputs = _: {
    flakeModules.nix-unit = ./flakeModule.nix;
  };
}
