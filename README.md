# 🌲🌴 import-tree 🎄🌳

> Helper functions for import of [Nixpkgs module system](https://nix.dev/tutorials/module-system/) modules under a directory recursively

- Flake callable; Easy to use, intuitive for the most common use case: `inputs.import-tree ./modules`
- Module class agnostic; can be used for NixOS, nix-darwin, home-manager, flake-parts, NixVim.
- Can be used outside flakes as a dependencies-free lib; Just import our `./default.nix`.
- Can be used to list other file types, not just `.nix`. See `.initFilter`, `.files` API.
- Extensible API. import-tree objects are customizable. See `.addAPI`.
- Useful for implementing the [Dendritic Pattern](https://github.com/mightyiam/dendritic).

## Quick Usage (with flake-parts)

This example shows how to load all nix files inside `./modules`, on [Dendritic](https://vic.github.io/dendrix/Dendritic.html) setups. (see also [flake-file's dendritic template](https://github.com/vic/flake-file?tab=readme-ov-file#flakemodulesdendritic))

```nix
{
  inputs.import-tree.url = "github:vic/import-tree";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
```

## Quick Usage (outside a modules evaluation)

If you want to get a list of nix files programmatically outside of a modules evaluation,
you can use the import-tree API (read below for more).

```nix
(import-tree.withLib pkgs.lib).leafs ./modules # => list of .nix files
```

## Ignored files

By default, paths having a component that begins with an underscore (`/_`) are ignored.

This can be changed by using `.initFilter` API.

<details>
  <summary>

## API usage

The following goes recursively through `./modules` and imports all `.nix` files.

```nix
# Usage as part of any nix module system.
{config, ...} {
  imports = [  (import-tree ./modules)  ];
}
```

For more advanced usage, `import-tree` can be configured via its extensible API.

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

Other import-tree objects can also be given as arguments (or in lists) as if they were paths.

As an special case, when the single argument given to an `import-tree` object is an
attribute-set containing an `options` attribute, the `import-tree` object
assumes it is being evaluated as a module. This way, a pre-configured `import-tree` can
also be used directly in a list of module imports.

This is useful for authors exposing pre-configured `import-tree`s that users can directly
add to their import list or continue configuring themselves using its API.

```nix
let
  # imagine this configured tree comes from some author's flake or library.
  # library author can extend an import-tree with custom API methods
  # according to the library's directory and file naming conventions.
  configured-tree = import-tree.addAPI {
    # the knowledge of where modules are located inside the library structure
    # or which filters/regexes/transformations to apply are abstracted 
    # from the user by the author providing a meaningful API.
    maximal = self: self.addPath ./modules;
    minimal = self: self.maximal.filter (lib.hasInfix "minimal");
  };
in {
  # the library user can directly import or further configure an import-tree.
  imports = [ configured-tree.minimal ];
}
```

## Configurable behavior

`import-tree` objects with custom behavior can be obtained using a builder pattern.
For example:

```nix
lib.pipe import-tree [
  (i: i.map lib.traceVal) # trace all paths. useful for debugging what is being imported.
  (i: i.filter (lib.hasInfix ".mod.")) # filter nix files by some predicate
  (i: i ./modules) # finally, call the configured import-tree with a path
]
```

Here is a simpler but less readable equivalent:

```nix
((import-tree.map lib.traceVal).filter (lib.hasInfix ".mod.")) ./modules
```

### `import-tree.filter` and `import-tree.filterNot`

`filter` takes a predicate function `path -> bool`. Only paths for which the filter returns `true` are selected:

> \[!NOTE\]
> Only files with suffix `.nix` are candidates.

```nix
# import-tree.filter : (path -> bool) -> import-tree

import-tree.filter (lib.hasInfix ".mod.") ./some-dir
```

`filter` can be applied multiple times, in which case only the files matching _all_ filters will be selected:

```nix
lib.pipe import-tree [
  (i: i.filter (lib.hasInfix ".mod."))
  (i: i.filter (lib.hasSuffix "default.nix"))
  (i: i ./some-dir)
]
```

Or, in a simpler but less readable way:

```nix
(import-tree.filter (lib.hasInfix ".mod.")).filter (lib.hasSuffix "default.nix") ./some-dir
```

See also `import-tree.initFilter`.

### `import-tree.match` and `import-tree.matchNot`

`match` takes a regular expression. The regex should match the full path for the path to be selected. Matching is done with `builtins.match`.

```nix
# import-tree.match : regex -> import-tree

import-tree.match ".*/[a-z]+@(foo|bar)\.nix" ./some-dir
```

`match` can be applied multiple times, in which case only the paths matching _all_ regex patterns will be selected, and can be combined with any number of `filter`, in any order.

### `import-tree.map`

`map` can be used to transform each path by providing a function.

e.g. to convert the path into a module explicitly:

```nix
# import-tree.map : (path -> any) -> import-tree

import-tree.map (path: {
  imports = [ path ];
  # assuming such an option is declared
  automaticallyImportedPaths = [ path ];
})
```

`map` can be applied multiple times, composing the transformations:

```nix
lib.pipe import-tree [
  (i: i.map (lib.removeSuffix ".nix"))
  (i: i.map builtins.stringLength)
] ./some-dir
```

The above example first removes the `.nix` suffix from all selected paths, then takes their lengths.

Or, in a simpler but less readable way:

```nix
((import-tree.map (lib.removeSuffix ".nix")).map builtins.stringLength) ./some-dir
```

`map` can be combined with any number of `filter` and `match` calls, in any order, but the (composed) transformation is applied _after_ the filters, and only to the paths that match all of them.

### `import-tree.addPath`

`addPath` can be used to prepend paths to be filter as a setup for import-tree.
This function can be applied multiple times.

```nix
# import-tree.addPath : (path_or_list_of_paths) -> import-tree

# Both of these result in the same imported files.
# however, the first adds ./vendor as a *pre-configured* path.
# and the final user can supply ./modules or [] empty.
(import-tree.addPath ./vendor) ./modules
import-tree [./vendor ./modules]
```

### `import-tree.addAPI`

`addAPI` extends the current import-tree object with new methods.
The API is cumulative, meaning that this function can be called multiple times.

`addAPI` takes an attribute set of functions taking a single argument:
`self` which is the current import-tree object.

```nix
# import-tree.addAPI : api-attr-set -> import-tree

import-tree.addAPI {
  maximal = self: self.addPath ./modules;
  feature = self: featureName: self.maximal.filter (lib.hasInfix feature);
  minimal = self: self.feature "minimal";
}
```

on the previous API, users can call `import-tree.feature "+vim"` or `import-tree.minimal`, etc.

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

### `import-tree.new`

Returns a fresh import-tree with empty state. If you previously had any path, lib, filter, etc,
you might need to set them on the new empty tree.

### `import-tree.initFilter`

*Replaces* the initial filter which defaults to: Include files with `.nix` suffix and not having `/_` infix.

_NOTE_: initFilter is non-accumulating and is the *first* filter to run before those accumulated via `filter`/`match`.

You can use this to make import-tree scan for other file types or change the ignore convention.

```nix
# import-tree.initFilter : (path -> bool) -> import-tree

import-tree.initFilter (p: lib.hasSuffix ".nix" p && !lib.hasInfix "/ignored/") # nix files not inside /ignored/
import-tree.initFilter (lib.hasSuffix ".md")  # scan for .md files everywhere, nothing ignored.
```

### `import-tree.files`

A shorthand for `import-tree.leafs.result`. Returns a list of matching files.

This can be used when you don't want to import the tree, but just get a list of files from it.

Useful for listing files other than `.nix`, for example, for passing all `.js` files to a minifier:

_TIP_: remember to use `withLib` when *not* using import-tree as a module import.

```nix
# import-tree.files : [ <list-of-files> ]

# paths to give to uglify-js
lib.pipe import-tree [
  (i: i.initFilter (lib.hasSuffix ".js")) # look for .js files. ignore nothing.
  (i: i.addPath ./out) # under the typescript compiler outDir
  (i: i.withLib lib) # set lib since we are not importing modules.
  (i: i.files)
]
# => list of all .js files
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

<details>
<summary>

Since the import-tree API is _extensible_ and lets you add paths or
filters at configuration time, configuration-library authors can
provide custom import-tree instances with an API suited for their
particular idioms.

@vic is using this on [Dendrix](https://github.com/vic/dendrix) for [community conventions](https://github.com/vic/dendrix/blob/main/dev/modules/community/_pipeline.nix) on tagging files.

</summary>

This would allow us to have community-driven *sets* of configurations,
much like those popular for editors: spacemacs/lazy-vim distributions.

Imagine an editor distribution exposing the following flake output:

```nix
# editor-distro's flakeModule
{inputs, lib, ...}:
let 
  flake.lib.modules-tree = lib.pipe inputs.import-tree [
    (i: i.addPath ./modules)
    (i: i.addAPI { inherit on off exclusive; })
    (i: i.addAPI { ruby = self: self.on "ruby"; })
    (i: i.addAPI { python = self: self.on "python"; })
    (i: i.addAPI { old-school = self: self.off "copilot"; })
    (i: i.addAPI { vim-btw = self: self.exclusive "vim" "emacs"; })
  ];

  on = self: flag: self.filter (lib.hasInfix "+${flag}");
  off = self: flag: self.filterNot (lib.hasInfix "+${flag}");
  exclusive = self: onFlag: offFlag: lib.pipe self [
    (self: on self onFlag)
    (self: off self offFlag)
  ];
in
{
  inherit flake;
}
```

Users of such distribution can do:

```nix
# consumer flakeModule
{inputs, lib, ...}: let
  ed-tree = inputs.editor-distro.lib.modules-tree;
in {
  imports = [
    (ed-tree.vim-btw.old-school.on "rust")
  ];
}
```

</details>

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
