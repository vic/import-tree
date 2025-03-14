# 🌲🌴 import-tree 🎄🌳

An small function producing a nix module that imports all `.nix` files in a tree.

Paths containing `/_` (an underscore starting any path segment) are ignored.


# Works with any nix module class: `nixos`, `nix-darwin`, `home-manager`, `flake-parts`, etc.

```nix
{config, ...} {
  imports = [  (import-tree ./modules)  ];
}
```

# Callable as a flake

```nix
{
  inputs.import-tree.url = "github:vic/import-tree";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs: inputs.flake-parts.mkFlake { inherit inputs; } (inputs.import-tree ./flakeModules);
}
```

## Function usage.

###### `import-tree`
This function expects a directory path as first argument or a list of directory paths.

```nix
# import-tree path_or_list_of_paths
import-tree ./someDir

import-tree [./oneDir otherDir]
```

The resulting value will be a module `{ imports = [...]; }`.

###### `import-tree.matching`

Same as `import-tree` function but this one takes a regular expression as first argument. The regex should match the full path for it being selected. Match is done with `lib.strings.match`;

```nix
# import-tree.matching regex path_or_list_of_paths

import-tree.matching ".*/[a-z]+@(foo|bar)\.nix" ./someDir
```

###### `import-tree.filtered`

Same as `import-tree` function but this one takes a filtering function `path -> bool` as first argument. This filter function should return true for any path that should be included in imports;

```nix
# import-tree.filtered predicate path_or_list_of_paths

import-tree.filtered (lib.hasSuffix "/options.nix") ./someDir
```

###### `import-tree.leafs` and `(import-tree.matching pred).leafs`

These functions return the list of files instead of creating a nix module. This can be handy when you just need to map over the files to produce another thing, like an attribute set of packages from those files.

The first parameter to `leafs` is a `lib` attrset (ie. `pkgs.lib`), the second parameter is the tree root.

```nix
# leafs lib path_or_list_of_paths
files = import-tree.leafs pkgs.lib ./someDir;

# our function returning a module is actually implemented like this:
module = path: { lib, ... }: { imports = leafs lib path; };
```

#### Why

Importing a tree of nix modules has some advantages:

##### [Pattern: each file is a flake-parts module](https://discourse.nixos.org/t/pattern-each-file-is-a-flake-parts-module/61271)

This pattern was the original inspiration for publishing this library. I recomend you to read how configs are structured at [Every Nix file is a flake-parts module](https://github.com/mightyiam/infra?tab=readme-ov-file#every-nix-file-is-a-flake-parts-module) ([discourse thread](https://discourse.nixos.org/t/pattern-each-file-is-a-flake-parts-module/61271))

- files (.nix modules) can be moved freely inside the tree. no fixed directory structure.
- since modules have options, you can use `enable` options to skip functionality even if all files are imported.

##### Sharing subtrees of modules as flake parts.

People could share sub-trees of modules as different sets of functionality. for example, by-feature layers in a neovim distribution.

```nix
# flake.nix (layered configs-distro)
{
  outputs = _: {
    flakeModules = {
      options = {inputs, ...}: inputs.import-tree ./flakeModules/options;
      minimal = {inputs, ...}: inputs.import-tree [./flakeModules/options ./flakeModules/minimal];
      maximal = {inputs, ...}: inputs.import-tree ./flakeModules;

      byFeature = featureName: {inputs, lib, ...}: inputs.import-tree.filtered (lib.hasSuffix "${featureName}.nix") ./flakeModules;
    };
  };
}
```

Note that in the previous example, the flake does not requires inputs. That's not actually a requirement of this library, the flake *could* define its own inputs just as any other flake does. However, this example can help illustrate another pattern:

##### Flakes with no inputs exposing just flakeModules.

This pattern (as illustrated by the flake code above) declares no inputs. Yet the exposed flakeModules have access to the final user's flake inputs.

This bypasses the `flake.lock` advantages - `nix flake lock` wont even generate a file-, and since the code has no guarantee on which version of the dependency inputs it will run using library code will probably break. So, clearly this pattern is not for every situation, but most likely for sharing modules. However, one advantage of this is that the dependency tree would be flat, having the final user's flake absolute control on what inputs are used, without having to worry if some third-party forgot to use `foo.inputs.nixpkgs.follows = "nixpkgs";` on any flake we are trying to re-use.
