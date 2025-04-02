{
  inputs.target.url = "path:..";
  inputs.checkmate.url = "github:vic/checkmate";
  inputs.checkmate.inputs.target.follows = "target";
  outputs = inputs: inputs.checkmate.lib.newFlake;
}
