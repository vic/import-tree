# 🌲🌴 import-tree 🎄🌳

An small function producing a nix module that imports all `.nix` files in a tree.

Paths containing `/_` (an underscore starting any path segment) are ignored.


# Works with any nix module class: `nixos`, `nix-darwin`, `home-manager`, `flake-parts`, etc.

```nix
{lib, ...}: {
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


#### Why

Importing a tree of nix modules has some advantages:

- files (.nix modules) can be moved freely inside the tree. no fixed directory structure.
- since modules have options, you can use `enable` options to skip functionality even if all files are imported.

#### Original inspiration

[Every Nix file is a flake-parts module](https://github.com/mightyiam/infra?tab=readme-ov-file#every-nix-file-is-a-flake-parts-module) ([discourse thread](https://discourse.nixos.org/t/pattern-each-file-is-a-flake-parts-module/61271))
