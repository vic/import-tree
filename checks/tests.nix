{ inputs, lib, ... }:
let
  it = inputs.import-tree;
  lit = it.withLib lib;
in
{
  perSystem = (
    { ... }:
    {
      nix-unit = {
        inherit inputs;

        tests = {
          leafs."test fails if no lib has been set" = {
            expr = it.leafs ./tree;
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

          mapWith."test transforms each matching file with function" = {
            expr = (lit.mapWith import).leafs ./tree/x;
            expected = [ "z" ];
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
      };

    }
  );
}
