# 🌲🌴 import-tree 🎄🌳

> Helper functions for import of [Nixpkgs module system](https://nix.dev/tutorials/module-system/) modules under a directory recursively

Module class agnostic; can be used for NixOS, nix-darwin, home-manager, flake-parts, NixVim.

## Quick Usage (with flake-parts)

This example shows how to load all nix files inside `./modules`, following the
[Dendritic Pattern](https://github.com/mightyiam/dendritic)

```nix
{
  inputs.import-tree.url = "github:vic/import-tree";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
```

## Ignored files

Paths that have a component that begins with an underscore are ignored.

<details>
  <summary>

## API usage

The following goes recursively through `./modules` and imports all `.nix` files.

```nix
{config, ...} {
  imports = [  (import-tree ./modules)  ];
}
```

For more advanced usage, `import-tree` can be configured via its builder API.
This means that the result of calling a function on an `import-tree` object
is itself another `import-tree` object.

</summary>

## Obtaining the API

When used as a flake, the flake outputs attrset is the primary callable.
Otherwise, importing the `default.nix` that is at the root of this repository will evaluate into the same attrset.
This callable attrset is referred to as `import-tree` in this documentation.

## `import-tree`

Takes a single argument: path or deeply nested list of path.
Returns a module that imports the discovered files.
For example, given the following file tree:

```
default.nix
modules/
  a.nix
  subdir/
    b.nix
```

The following

```nix
{lib, config, ...} {
  imports = [ (import-tree ./modules) ];
}
```

Is similar to

```nix
{lib, config, ...} {
  imports = [
    {
      imports = [
        ./modules/a.nix
        ./modules/subdir/b.nix
      ];
    }
  ];
}
```

If given a deeply nested list of paths the list will be flattened and results concatenated.
The following is valid usage:

```nix
{lib, config, ...} {
  imports = [ (import-tree [./a [./b]]) ];
}
```

As an special case, when the single argument given to an `import-tree` object is an
attribute-set *meaning it is _NOT_ a path or list of paths*, the `import-tree` object
assumes it is being imported as a module. This way, a pre-configured `import-tree` can
also be used directly in a list of module imports.

This is useful for authors exposing pre-configured `import-tree`s that users can direcly
add to their import list or continue configuring themselves using the API.

```nix
let
  # imagine this configured tree is actually provided by some flake or library.
  # users can directly import it or continue using API methods on it.
  configured-tree = import-tree.addPath [./a [./b]]; # paths are configured by library author.
in {
  imports = [ configured-tree ]; # but then imported or further configured by the library user.
}
```

## Configurable behavior

`import-tree` objects with custom behavior can be obtained using a builder pattern.
For example:

```nix
lib.pipe import-tree [
  (i: i.mapWith lib.traceVal) # trace all paths. useful for debugging what is being imported.
  (i: i.filtered (lib.hasInfix ".mod.")) # filter nix files by some predicate
  (i: i ./modules) # finally, call the configured import-tree with a path
]
```

Here is a simpler but less readable equivalent:

```nix
((import-tree.mapWith lib.traceVal).filtered (lib.hasInfix ".mod.")) ./modules
```

### `import-tree.filtered`

`filtered` takes a predicate function `path -> bool`. Only paths for which the filter returns `true` are selected:

> \[!NOTE\]
> Only files with suffix `.nix` are candidates.

```nix
# import-tree.filtered : (path -> bool) -> import-tree

import-tree.filtered (lib.hasInfix ".mod.") ./some-dir
```

`filtered` can be applied multiple times, in which case only the files matching _all_ filters will be selected:

```nix
lib.pipe import-tree [
  (i: i.filtered (lib.hasInfix ".mod."))
  (i: i.filtered (lib.hasSuffix "default.nix"))
  (i: i ./some-dir)
]
```

Or, in a simpler but less readable way:

```nix
(import-tree.filtered (lib.hasInfix ".mod.")).filtered (lib.hasSuffix "default.nix") ./some-dir
```

### `import-tree.matching`

`matching` takes a regular expression. The regex should match the full path for the path to be selected. Matching is done with `builtins.match`.

```nix
# import-tree.matching : regex -> import-tree

import-tree.matching ".*/[a-z]+@(foo|bar)\.nix" ./some-dir
```

`matching` can be applied multiple times, in which case only the paths matching _all_ regex patterns will be selected, and can be combined with any number of `filtered`, in any order.

### `import-tree.mapWith`

`mapWith` can be used to transform each path by providing a function.

e.g. to convert the path into a module explicitly:

```nix
# import-tree.mapWith : (path -> any) -> import-tree

import-tree.mapWith (path: {
  imports = [ path ];
  # assuming such an option is declared
  automaticallyImportedPaths = [ path ];
})
```

`mapWith` can be applied multiple times, composing the transformations:

```nix
lib.pipe import-tree [
  (i: i.mapWith (lib.removeSuffix ".nix"))
  (i: i.mapWith builtins.stringLength)
] ./some-dir
```

The above example first removes the `.nix` suffix from all selected paths, then takes their lengths.

Or, in a simpler but less readable way:

```nix
((import-tree.mapWith (lib.removeSuffix ".nix")).mapWith builtins.stringLength) ./some-dir
```

`mapWith` can be combined with any number of `filtered` and `matching` calls, in any order, but the (composed) transformation is applied _after_ the filters, and only to the paths that match all of them.

### `import-tree.addPath`

`addPath` can be used to prepend paths to be filtered as a setup for import-tree.
This function can be applied multiple times.

```nix
# import-tree.addPath : (path_or_list_of_paths) -> import-tree

# Both of these result in the same imported files.
# however, the first adds ./vendor as a *pre-configured* path.
# and the final user can supply ./modules or [] empty.
(import-tree.addPath ./vendor) ./modules
import-tree [./vendor ./modules]
```

### `import-tree.withLib`

> \[!NOTE\]
> `withLib` is required prior to invocation of any of `.leafs` or `.pipeTo`.
> Because with the use of those functions the implementation does not have access to a `lib` that is provided as a module argument.

```nix
# import-tree.withLib : lib -> import-tree

import-tree.withLib pkgs.lib
```

### `import-tree.pipeTo`

`pipeTo` takes a function that will receive the list of paths.
When configured with this, `import-tree` will not return a nix module but the result of the function being piped to.

```nix
# import-tree.pipeTo : ([paths] -> any) -> import-tree

import-tree.pipeTo lib.id # equivalent to  `.leafs`
```

### `import-tree.leafs`

`leafs` takes no arguments, it is equivalent to calling `import-tree.pipeTo lib.id`. That is, instead of producing a nix module, just return the list of results.

```nix
# import-tree.leafs : import-tree

import-tree.leafs
```

### `import-tree.result`

Exactly the same as calling the import-tree object with an empty list `[ ]`.
This is useful for import-tree objects that already have paths configured via `.addPath`.

```nix
# import-tree.result : <module-or-piped-result>

# these two are exactly the same:
(import-tree.addPath ./modules).result
(import-tree.addPath ./modules) [ ]
```

</details>

## Why

Importing a tree of nix modules has some advantages:

### Dendritic Pattern: each file is a flake-parts module

[That pattern](https://github.com/mightyiam/dendritic) was the original inspiration for this library.
See [@mightyiam's post](https://discourse.nixos.org/t/pattern-each-file-is-a-flake-parts-module/61271),
[@drupol's blog post](https://not-a-number.io/2025/refactoring-my-infrastructure-as-code-configurations/) and
[@vic's reply](https://discourse.nixos.org/t/how-do-you-structure-your-nixos-configs/65851/8)
to learn about the Dendritic pattern advantages.

### Sharing pre-configured subtrees of modules

Since the import-tree API lets you prepend paths and filter which files to include,
you could have flakes that output different sets of pre-configured trees.

This would allow us to have community-driven *sets* of configurations,
much like those popular for editors: spacemacs/lazy-vim distributions.

Imagine an editor distribution exposing the following `lib.trees` flake output:

```nix
# editor-distro's flakeModule
{inputs, lib, ...}:
let 
  flake.lib.trees = {
    inherit root on off xor;
  };

  root = inputs.import-tree.addPath ./modules;

  on = flag: tree: tree.filter (lib.hasInfix "/+${flag}/");
  off = flag: tree: tree.filter (lib.hasInfix "/-${flag}/");
in
{
  inherit flake;
}
```

Users of such distribution can do:

```nix
# consumer flakeModule
{inputs, lib, ...}: let
  inherit (inputs.editor-distro.lib.trees) on off root;
in {
  imports = [
    # files inside +vim -emacs directories
    (lib.pipe root [(on "vim") (off "emacs") (i: i.result)])
  ];
}
```

## Testing

`import-tree` uses [`checkmate`](https://github.com/vic/checkmate) for testing.

The test suite can be found in [`checkmate.nix`](checkmate.nix). To run it locally:

```sh
nix flake check path:checkmate --override-input target path:.
```

Run the following to format files:

```sh
nix run github:vic/checkmate#fmt
```
