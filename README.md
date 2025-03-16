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

### `import-tree`

This is the protagonist function of this library. It expects to be called with a directory path as first argument or a list of directory paths.

```nix
# import-tree path_or_list_of_paths
import-tree ./someDir

import-tree [./oneDir [nestedListOfDirs]]
```

The resulting value will be a module `{ imports = [...]; }` containing nix files found on dir.

> That's all you need in most use cases. Just give the result of `import-tree` to any module evaluation of yours.

### Advanced `import-tree.*` config functions. (for libraries using import-tree)

`import-tree` also contains config functions (*see their documentation bellow*) you can use before calling with a directory tree.

Invoking one of these config functions will return a new `import-tree` functor,
and invoking another config function on it will return yet another functor. This is somewhat similar to the builder pattern in other languages. When you have configured `import-tree` as you want, you can
call it passing a path as in the heading example.

The following code configures using `.withLib`, `.filtered`, `.leafs` before calling `import-tree` with a path:

```nix
# not as pretty to read
(((import-tree.withLib lib).filtered (lib.hasSuffix "a.nix"))).leafs ./someDir;
> [ ... ]

# piping might be much better
lib.pipe import-tree [
  (f: f.leafs) # dont produce modules, just return the list of results
  (f: f.mapWith import) # instead of returning files, import each of them
  (f: f.withLib lib) # specify a pkgs.lib, since this flake has no dependencies
  (f: f.filtered (lib.hasSuffix "a.nix")) # filter nix files by some predicate
  (f: f ./someDir) # finally call the configured functor with a path
]
> [ ... ]
```

###### `import-tree.withLib`

Calling `.withLib` is *only needed* if you will invoke `.leafs` or `.pipeTo` instead of using `import-tree` to produce nix config modules.

> The reason is that when working _inside_ of a nix modules evaluation, each module has access to `{lib, ...}` and `import-tree` will automatically use that `lib`. However, outside of a nix modules evaluation you need to specify which lib to use since this flake prefers not to depend on `nixpkgs` nor `nixpkgs-lib` flakes.

```nix
# import-tree.withLib : lib -> import-tree

import-tree.withLib pkgs.lib
```

###### `import-tree.filtered`

`filtered` takes a predicate function `path -> bool` as first argument. Predicate should return true for any nix file to be included.

```nix
# import-tree.filtered : (path -> bool) -> import-tree

import-tree.filtered (lib.hasSuffix "/options.nix") ./someDir
```

###### `import-tree.matching`

`matching` takes a regular expression as first argument. The regex should match the full path for the path to be selected. Match is done with `lib.strings.match`;

```nix
# import-tree.matching : regex -> import-tree

import-tree.matching ".*/[a-z]+@(foo|bar)\.nix" ./someDir
```

###### `import-tree.mapWith`

`mapWith` takes a transformation function that you can use to map each selected path into something else.
You can use it to take the file path and create a custom nix module from it as you see fit.

```nix
# import-tree.mapWith : (path -> any) -> import-tree

import-tree.mapWith (import)
```

###### `import-tree.pipeTo`

`pipeTo` takes a function that will recieve the list of paths. When configured with this, `import-tree` will not return a nix module but the result of the function being piped to.

```nix
# import-tree.pipeTo : ([paths] -> any) -> import-tree

import-tree.pipeTo (identity) # the same as .leafs
```

###### `import-tree.leafs`

`leafs` takes no arguments, it is equivalent to calling `pipeTo identity`, that is, instead of producing a nix module, just return the list of results.

```nix
# import-tree.leafs : import-tree

import-tree.leafs
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
