{ inputs, ... }:
{
  perSystem = (
    { pkgs, ... }:
    let
      treefmt = inputs.treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
        programs.nixfmt.excludes = [ ".direnv" ];
        programs.deadnix.enable = true;
        programs.mdformat.enable = true;
        programs.yamlfmt.enable = true;
      };
      treefmt-wrapper = treefmt.config.build.wrapper;
      treefmt-checks = treefmt.config.build.check inputs.self;
      treefmt-import-tree = treefmt.config.build.check inputs.import-tree;
    in
    {
      packages.treefmt = treefmt-wrapper;
      checks = {
        inherit treefmt-checks;
        inherit treefmt-import-tree;
      };
    }
  );
}
