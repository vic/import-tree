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

        filtered."test multiple `filtered`s compose" = {
          expr = ((lit.filtered (lib.hasInfix "b/")).filtered (lib.hasInfix "_")).leafs ./tree;
          expected = [ ./tree/a/b/b_a.nix ];
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

        matching."test `matching` composes with `filtered`" = {
          expr = ((lit.matching ".*/[^/]+_[^/]+\.nix").filtered (lib.hasSuffix "b.nix")).leafs ./tree;
          expected = [ ./tree/a/a_b.nix ];
        };

        matching."test multiple `matching`s compose" = {
          expr = ((lit.matching ".*/[^/]+_[^/]+\.nix").matching ".*b\.nix").leafs ./tree;
          expected = [ ./tree/a/a_b.nix ];
        };

        mapWith."test transforms each matching file with function" = {
          expr = (lit.mapWith import).leafs ./tree/x;
          expected = [ "z" ];
        };

        mapWith."test `mapWith` composes with `filtered`" = {
          expr = ((lit.filtered (lib.hasInfix "/x")).mapWith import).leafs ./tree;
          expected = [ "z" ];
        };

        mapWith."test multiple `mapWith`s compose" = {
          expr = ((lit.mapWith import).mapWith builtins.stringLength).leafs ./tree/x;
          expected = [ 1 ];
        };

        addPath."test `addPath` prepends a path to filter" = {
          expr = (lit.addPath ./tree/x).leafs.result;
          expected = [ ./tree/x/y.nix ];
        };

        addPath."test `addPath` can be called multiple times" = {
          expr = ((lit.addPath ./tree/x).addPath ./tree/a/b).leafs.result;
          expected = [
            ./tree/x/y.nix
            ./tree/a/b/b_a.nix
            ./tree/a/b/m.nix
          ];
        };

        addPath."test `addPath` identity" = {
          expr = ((lit.addPath ./tree/x).addPath ./tree/a/b).leafs.result;
          expected = lit.leafs [
            ./tree/x
            ./tree/a/b
          ];
        };

        addAPI."test extends the API available on an import-tree object" = {
          expr =
            let
              extended = lit.addAPI { helloOption = self: self.addPath ./tree/modules/hello-option; };
            in
            extended.helloOption.leafs.result;
          expected = [ ./tree/modules/hello-option/mod.nix ];
        };

        addAPI."test preserves previous API extensions on an import-tree object" = {
          expr =
            let
              first = lit.addAPI { helloOption = self: self.addPath ./tree/modules/hello-option; };
              second = first.addAPI { helloWorld = self: self.addPath ./tree/modules/hello-world; };
              extended = second.addAPI { res = self: self.helloOption.leafs.result; };
            in
            extended.res;
          expected = [ ./tree/modules/hello-option/mod.nix ];
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

        import-tree."test evaluates returned module as part of module-eval" = {
          expr =
            let
              res = lib.modules.evalModules { modules = [ (it ./tree/modules) ]; };
            in
            res.config.hello;
          expected = "world";
        };

        import-tree."test can itself be used as a module" = {
          expr =
            let
              res = lib.modules.evalModules { modules = [ (it.addPath ./tree/modules) ]; };
            in
            res.config.hello;
          expected = "world";
        };
      };

    }
  );
}
