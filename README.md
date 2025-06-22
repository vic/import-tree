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

The following goes recursively through the provided `./modules` path and imports the files whose names end with `.nix`.

```nix
{config, ...} {
  imports = [  (import-tree ./modules)  ];
}
```

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

## Configurable behavior

`import-tree` functions with custom behavior can be obtained using a builder pattern.
For example:

```nix
lib.pipe import-tree [
  (i: i.mapWith lib.traceVal) # trace all paths
  (i: i.filtered (lib.hasInfix ".mod.")) # filter nix files by some predicate
  (i: i ./modules) # finally, call the configured callable with a path
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

</details>

## Why

Importing a tree of nix modules has some advantages:

### Dendritic Pattern: each file is a flake-parts module

[That pattern](https://discourse.nixos.org/t/pattern-each-file-is-a-flake-parts-module/61271) was the original inspiration for publishing this library.
Some of the benefits are [described in the author's personal infrastructure repository](https://github.com/mightyiam/infra#every-nix-file-is-a-flake-parts-module)
and [@drupol's blog post](https://not-a-number.io/2025/refactoring-my-infrastructure-as-code-configurations/)

### Sharing subtrees of modules as flake parts

People could share sub-trees of modules as different sets of functionality.
for example, by-feature layers in a neovim distribution.

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

Note that in the previous example, the flake does not requires inputs.
That's not actually a requirement of this library, the flake *could* define its own inputs just as any other flake does.
However, this example can help illustrate another pattern:

### Flakes with no inputs exposing just `flakeModules`

This pattern (as illustrated by the flake code above) declares no inputs.
Yet the exposed flakeModules have access to the final user's flake inputs.

This bypasses the `flake.lock` advantages--`nix flake lock` wont even generate a file--
and since the code has no guarantee on which version of the dependency inputs it will run using library code will probably break.
So, clearly this pattern is not for every situation, but most likely for sharing modules.
However, one advantage of this is that the dependency tree would be flat,
giving the final user's flake absolute control on what inputs are used,
without having to worry whether some third-party forgot to use `foo.inputs.nixpkgs.follows = "nixpkgs";` on any flake we are trying to re-use.

## Testing

`import-tree` uses [`checkmate`](https://github.com/vic/checkmate) for testing.

The test suite can be found in [`checkmate.nix`](checkmate.nix). To run it locally:

```sh
nix flake check path:checkmate --override-input target path:.
```
