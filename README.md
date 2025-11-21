<p align="right">
  <a href="https://github.com/sponsors/vic"><img src="https://img.shields.io/badge/sponsor-vic-white?logo=githubsponsors&logoColor=white&labelColor=%23FF0000" alt="Sponsor Vic"/>
  </a>
  <a href="https://vic.github.io/dendrix/Dendritic-Ecosystem.html#vics-dendritic-libraries"> <img src="https://img.shields.io/badge/Dendritic-Nix-informational?logo=nixos&logoColor=white" alt="Dendritic Nix"/> </a>
  <a href="LICENSE"> <img src="https://img.shields.io/github/license/vic/import-tree" alt="License"/> </a>
  <a href="https://github.com/vic/import-tree/actions">
  <img src="https://github.com/vic/import-tree/actions/workflows/test.yml/badge.svg" alt="CI Status"/> </a>
</p>

> `import-tree` and [vic](https://bsky.app/profile/oeiuwq.bsky.social)'s [dendritic libs](https://vic.github.io/dendrix/Dendritic-Ecosystem.html#vics-dendritic-libraries) made for you with Love++ and AI--. If you like my work, consider [sponsoring](https://github.com/sponsors/vic)

# 🌲🌴 import-tree 🎄🌳

> Recursively import [Nix modules](https://nix.dev/tutorials/module-system/) from a directory, with a simple, extensible API.

## Quick Start (flake-parts)

Import all nix files inside `./modules` in your flake:

```nix
{
  inputs.import-tree.url = "github:vic/import-tree";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; }
   (inputs.import-tree ./modules);
}
```

> By default, paths having `/_` are ignored.

## Features

🌳 Works with NixOS, nix-darwin, home-manager, flake-parts, NixVim, etc.\
🌲 Callable as a deps-free Flake or nix lib.\
🌴 Sensible defaults and configurable behaviour.\
🌵 API for listing custom file types with filters and transformations.\
🎄 Extensible: add your own API methods to tailor import-tree objects.\
🌿 Useful on [Dendritic Pattern](https://github.com/mightyiam/dendritic) setups.\
🌱 [Growing](https://github.com/search?q=language%3ANix+import-tree&type=code) [community](https://vic.github.io/dendrix/Dendrix-Trees.html) [adoption](https://github.com/vic/flake-file)

## Other Usage (outside module evaluation)

Get a list of nix files programmatically:

```nix
(import-tree.withLib pkgs.lib).leafs ./modules
```

<details>
<summary>Advanced Usage, API, and Rationale</summary>

### Ignored files

By default, paths having a component that begins with an underscore (`/_`) are ignored. This can be changed by using `.initFilter` API.

### API usage

The following goes recursively through `./modules` and imports all `.nix` files.

```nix
{config, ...} {
  imports = [  (import-tree ./modules)  ];
}
```

For more advanced usage, `import-tree` can be configured via its extensible API.

---

#### Obtaining the API

When used as a flake, the flake outputs attrset is the primary callable. Otherwise, importing the `default.nix` at the root of this repository will evaluate into the same attrset. This callable attrset is referred to as `import-tree` in this documentation.

#### `import-tree`

Takes a single argument: path or deeply nested list of path. Returns a module that imports the discovered files. For example, given the following file tree:

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

If given a deeply nested list of paths the list will be flattened and results concatenated. The following is valid usage:

```nix
{lib, config, ...} {
  imports = [ (import-tree [./a [./b]]) ];
}
```

Other import-tree objects can also be given as arguments (or in lists) as if they were paths.

As a special case, when the single argument given to an `import-tree` object is an attribute-set containing an `options` attribute, the `import-tree` object assumes it is being evaluated as a module. This way, a pre-configured `import-tree` object can also be used directly in a list of module imports.

#### Configurable behavior

`import-tree` objects with custom behavior can be obtained using a builder pattern. For example:

```nix
lib.pipe import-tree [
  (i: i.map lib.traceVal)
  (i: i.filter (lib.hasInfix ".mod."))
  (i: i ./modules)
]
```

Or, in a simpler but less readable way:

```nix
((import-tree.map lib.traceVal).filter (lib.hasInfix ".mod.")) ./modules
```

##### 🌲 `import-tree.filter` and `import-tree.filterNot`

`filter` takes a predicate function `path -> bool`. Only files with suffix `.nix` are candidates.

```nix
import-tree.filter (lib.hasInfix ".mod.") ./some-dir
```

Multiple filters can be combined, results must match all of them.

##### 🌳 `import-tree.match` and `import-tree.matchNot`

`match` takes a regular expression. The regex should match the full path for the path to be selected. Matching is done with `builtins.match`.

```nix
import-tree.match ".*/[a-z]+@(foo|bar)\.nix" ./some-dir
```

Multiple match filters can be added, results must match all of them.

##### 🌴 `import-tree.map`

`map` can be used to transform each path by providing a function.

```nix
# generate a custom module from path
import-tree.map (path: { imports = [ path ]; })
```

Outside modules evaluation, you can transform paths into something else:

```nix
lib.pipe import-tree [
  (i: i.map builtins.readFile)
  (i: i.withLib lib)
  (i: i.leafs ./dir)
]
# => list of contents of all files.
```

##### 🌵 `import-tree.addPath`

`addPath` can be used to prepend paths to be filtered as a setup for import-tree.

```nix
(import-tree.addPath ./vendor) ./modules
import-tree [./vendor ./modules]
```

##### 🎄 `import-tree.addAPI`

`addAPI` extends the current import-tree object with new methods.

```nix
import-tree.addAPI {
  maximal = self: self.addPath ./modules;
  feature = self: infix: self.maximal.filter (lib.hasInfix infix);
  minimal = self: self.feature "minimal";
}
```

##### 🌿 `import-tree.withLib`

`withLib` is required prior to invocation of any of `.leafs` or `.pipeTo` when not used as part of a nix modules evaluation.

```nix
import-tree.withLib pkgs.lib
```

##### 🌱 `import-tree.pipeTo`

`pipeTo` takes a function that will receive the list of paths.

```nix
import-tree.pipeTo lib.id # equivalent to  `.leafs`
```

##### 🍃 `import-tree.leafs`

`leafs` takes no arguments, it is equivalent to calling `import-tree.pipeTo lib.id`.

```nix
import-tree.leafs
```

##### 🌲 `import-tree.new`

Returns a fresh import-tree with empty state.

##### 🌳 `import-tree.initFilter`

_Replaces_ the initial filter which defaults to: Include files with `.nix` suffix and not having `/_` infix.

```nix
import-tree.initFilter (p: lib.hasSuffix ".nix" p && !lib.hasInfix "/ignored/" p)
import-tree.initFilter (lib.hasSuffix ".md")
```

##### 🌴 `import-tree.files`

A shorthand for `import-tree.leafs.result`. Returns a list of matching files.

```nix
lib.pipe import-tree [
  (i: i.initFilter (lib.hasSuffix ".js"))
  (i: i.addPath ./out)
  (i: i.withLib lib)
  (i: i.files)
]
```

##### 🌵 `import-tree.result`

Exactly the same as calling the import-tree object with an empty list `[ ]`.

```nix
(import-tree.addPath ./modules).result
(import-tree.addPath ./modules) [ ]
```

---

## Why

Importing a tree of nix modules has some advantages:

### Dendritic Pattern: each file is a flake-parts module

[That pattern](https://github.com/mightyiam/dendritic) was the original inspiration for this library.
See [@mightyiam's post](https://discourse.nixos.org/t/pattern-each-file-is-a-flake-parts-module/61271),
[@drupol's blog post](https://not-a-number.io/2025/refactoring-my-infrastructure-as-code-configurations/) and
[@vic's reply](https://discourse.nixos.org/t/how-do-you-structure-your-nixos-configs/65851/8)
to learn about the Dendritic pattern advantages.

### Sharing pre-configured subtrees of modules

Since the import-tree API is _extensible_ and lets you add paths or
filters at configuration time, configuration-library authors can
provide custom import-tree instances with an API suited for their
particular idioms.

@vic is using this on [Dendrix](https://github.com/vic/dendrix) for [community conventions](https://github.com/vic/dendrix/blob/main/dev/modules/community/_pipeline.nix) on tagging files.

This would allow us to have community-driven _sets_ of configurations,
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

---

## Testing

`import-tree` uses [`checkmate`](https://github.com/vic/checkmate) for testing.

The test suite can be found in [`checkmate.nix`](checkmate.nix). To run it locally:

```sh
nix flake check github:vic/checkmate --override-input target path:.
```

Run the following to format files:

```sh
nix run github:vic/checkmate#fmt
```

</details>
