{
  inputs.import-tree.url = "github:vic/import-tree";
  inputs.checkmate.url = "github:vic/checkmate";
  outputs = inputs: inputs.checkmate inputs.self ./flakeModule.nix;
}
