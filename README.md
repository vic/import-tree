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

Same as `import-tree` function but this one takes a filtering function as first argument. This filter function should return true for any path that should be included in imports;

```
# import-tree.matching predicate path_or_list_of_paths

import-tree.matching (path: lib.hasSuffix "/options.nix") ./someDir
```


#### Why

Importing a tree of nix modules has some advantages:

- files (.nix modules) can be moved freely inside the tree. no fixed directory structure.
- since modules have options, you can use `enable` options to skip functionality even if all files are imported.
- people could share sub-trees of modules as different sets of functionality. for example, different layers in a neovim distribution.

```nix
# flake.nix (neovim-configs-distro)
{
  outputs = _: {
    flakeModules = {
      options = {inputs, ...}: inputs.import-tree ./flakeModules/options;
      minimal = {inputs, ...}: inputs.import-tree [./flakeModules/options ./flakeModules/minimal];
      maximal = {inputs, ...}: inputs.import-tree ./flakeModules;

      byFeature = featureName: {inputs, lib, ...}: inputs.import-tree.matching (lib.hasSuffix "${featureName}.nix") ./flakeModules;
    };
  };
}
```

#### Original inspiration

[Every Nix file is a flake-parts module](https://github.com/mightyiam/infra?tab=readme-ov-file#every-nix-file-is-a-flake-parts-module) ([discourse thread](https://discourse.nixos.org/t/pattern-each-file-is-a-flake-parts-module/61271))
