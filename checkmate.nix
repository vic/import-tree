# If formatting fails, run
#   nix run github:vic/checkmate#checkmate-treefmt
#
{ inputs, lib, ... }:
let
  # since we are tested by github:vic/checkmate
  it = inputs.target;
  lit = it.withLib lib;
in
{
  perSystem = (
    { ... }:
    {
      nix-unit.tests = {
        leafs."test fails if no lib has been set" = {
          expr = it.leafs ./trees;
          expectedError.type = "ThrownError";
        };

        leafs."test succeeds when lib has been set" = {
          expr = (it.withLib lib).leafs ./tree/hello;
          expected = [ ];
        };

        leafs."test only returns nix non-ignored files" = {
          expr = lit.leafs ./tree/a;
          expected = [
            ./tree/a/a_b.nix
            ./tree/a/b/b_a.nix
            ./tree/a/b/m.nix
          ];
        };

        filtered."test returns empty if no nix files with true predicate" = {
          expr = (lit.filtered (_: false)).leafs ./tree;
          expected = [ ];
        };

        filtered."test only returns nix files with true predicate" = {
          expr = (lit.filtered (lib.hasSuffix "m.nix")).leafs ./tree;
          expected = [ ./tree/a/b/m.nix ];
        };

        matching."test returns empty if no files matching regex" = {
          expr = (lit.matching "badregex").leafs ./tree;
          expected = [ ];
        };

        matching."test returns files matching regex" = {
          expr = (lit.matching ".*/[^/]+_[^/]+\.nix").leafs ./tree;
          expected = [
            ./tree/a/a_b.nix
            ./tree/a/b/b_a.nix
          ];
        };

        matching."test `filter` composes with `matching`" = {
          expr = ((lit.matching ".*/[^/]+_[^/]+\.nix").filtered (lib.hasSuffix "b.nix")).leafs ./tree;
          expected = [ ./tree/a/a_b.nix ];
        };

        mapWith."test transforms each matching file with function" = {
          expr = (lit.mapWith import).leafs ./tree/x;
          expected = [ "z" ];
        };

        mapWith."test multiple `mapWith`s compose" = {
          expr = ((lit.mapWith import).mapWith builtins.stringLength).leafs ./tree/x;
          expected = [ 1 ];
        };

        pipeTo."test pipes list into a function" = {
          expr = (lit.mapWith lib.pathType).pipeTo (lib.length) ./tree/x;
          expected = 1;
        };

        import-tree."test returns a module with a single imported nested module having leafs" = {
          expr =
            let
              oneElement = arr: if lib.length arr == 1 then lib.elemAt arr 0 else throw "Expected one element";
              module = it ./tree/x;
              inner = (oneElement module.imports) { inherit lib; };
            in
            oneElement inner.imports;
          expected = ./tree/x/y.nix;
        };
      };

    }
  );
}
