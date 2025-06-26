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

        filter."test returns empty if no nix files with true predicate" = {
          expr = (lit.filter (_: false)).leafs ./tree;
          expected = [ ];
        };

        filter."test only returns nix files with true predicate" = {
          expr = (lit.filter (lib.hasSuffix "m.nix")).leafs ./tree;
          expected = [ ./tree/a/b/m.nix ];
        };

        filter."test multiple `filter`s compose" = {
          expr = ((lit.filter (lib.hasInfix "b/")).filter (lib.hasInfix "_")).leafs ./tree;
          expected = [ ./tree/a/b/b_a.nix ];
        };

        match."test returns empty if no files match regex" = {
          expr = (lit.match "badregex").leafs ./tree;
          expected = [ ];
        };

        match."test returns files matching regex" = {
          expr = (lit.match ".*/[^/]+_[^/]+\.nix").leafs ./tree;
          expected = [
            ./tree/a/a_b.nix
            ./tree/a/b/b_a.nix
          ];
        };

        matchNot."test returns files not matching regex" = {
          expr = (lit.matchNot ".*/[^/]+_[^/]+\.nix").leafs ./tree/a/b;
          expected = [
            ./tree/a/b/m.nix
          ];
        };

        match."test `match` composes with `filter`" = {
          expr = ((lit.match ".*/[^/]+_[^/]+\.nix").filter (lib.hasSuffix "b.nix")).leafs ./tree;
          expected = [ ./tree/a/a_b.nix ];
        };

        match."test multiple `match`s compose" = {
          expr = ((lit.match ".*/[^/]+_[^/]+\.nix").match ".*b\.nix").leafs ./tree;
          expected = [ ./tree/a/a_b.nix ];
        };

        map."test transforms each matching file with function" = {
          expr = (lit.map import).leafs ./tree/x;
          expected = [ "z" ];
        };

        map."test `map` composes with `filter`" = {
          expr = ((lit.filter (lib.hasInfix "/x")).map import).leafs ./tree;
          expected = [ "z" ];
        };

        map."test multiple `map`s compose" = {
          expr = ((lit.map import).map builtins.stringLength).leafs ./tree/x;
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
          expr = (lit.map lib.pathType).pipeTo (lib.length) ./tree/x;
          expected = 1;
        };

        import-tree."test does not break if given a path to a file instead of a directory." = {
          expr = lit.leafs ./tree/x/y.nix;
          expected = [ ./tree/x/y.nix ];
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

        import-tree."test can take other import-trees as if they were paths" = {
          expr = (lit.filter (lib.hasInfix "mod")).leafs [
            (it.addPath ./tree/modules/hello-option)
            ./tree/modules/hello-world
          ];
          expected = [
            ./tree/modules/hello-option/mod.nix
            ./tree/modules/hello-world/mod.nix
          ];
        };
      };

    }
  );
}
