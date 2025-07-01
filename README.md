# 🌲🌴 import-tree 🎄🌳

> **Powerful and extensible helper for importing [Nixpkgs module system](https://nix.dev/tutorials/module-system/) modules from directory trees**

[![Build Status](https://github.com/vic/import-tree/actions/workflows/test.yml/badge.svg)](https://github.com/vic/import-tree/actions/workflows/test.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)


**import-tree** simplifies the management of Nix module collections by automatically discovering and importing `.nix` files from directory structures. Whether you're organizing NixOS configurations, home-manager setups, or flake-parts modules, import-tree provides an intuitive and extensible API to streamline your module imports.

Perfect for implementing the [Dendritic Pattern](https://github.com/mightyiam/dendritic) where each file represents a discrete, composable module, making your Nix configurations more modular and maintainable.

```nix
{
  inputs = {
    import-tree.url = "github:vic/import-tree";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs: 
    inputs.flake-parts.lib.mkFlake { inherit inputs; } 
      # This imports all .nix files from ./modules recursively
      (inputs.import-tree ./modules);
}
```

By default, any path containing `/_` is ignored.

## Understanding the Default Behavior

### File Discovery

By default, import-tree:
- **Recursively scans** directories for `.nix` files
- **Ignores paths** containing components that start with underscore (`/_`)
- **Returns a module** that imports all discovered files

### Default Ignore Pattern

Files and directories starting with underscore are ignored by default:
- `_private.nix` ❌ (ignored)
- `modules/_internal/config.nix` ❌ (ignored)
- `modules/public.nix` ✅ (included)

This convention allows you to keep private/internal files alongside public modules without accidentally importing them.



<details>
<summary>
🔍🥦 Explore more.

> Advanced Features: filters, transforms, list other file types, extensible API.
</summary>

- [Features at a Glance](#features-at-a-glance)
- [Quick Start](#quick-start)
  - [For Flake Users](#for-flake-users)
  - [For Non-Flake Users](#for-non-flake-users)
  - [Basic Usage in Module Systems](#basic-usage-in-module-systems)
- [Understanding the Default Behavior](#understanding-the-default-behavior)
  - [File Discovery](#file-discovery)
  - [Default Ignore Pattern](#default-ignore-pattern)
- [Advanced Usage & API](#advanced-usage--api)
  - [Filtering Files](#filtering-files)
  - [Using Regular Expressions](#using-regular-expressions)
  - [Transforming Files](#transforming-files)
  - [Working with File Lists](#working-with-file-lists)
  - [Pre-configuring Paths](#pre-configuring-paths)
  - [Custom API Extensions](#custom-api-extensions)
- [Why Use import-tree?](#why-use-import-tree)
  - [The Dendritic Pattern](#the-dendritic-pattern)
  - [Library Distribution & Community Configurations](#library-distribution--community-configurations)
- [API Reference](#api-reference)
  - [Core Methods](#core-methods)
  - [Configuration Methods](#configuration-methods)
  - [Extension Methods](#extension-methods)
  - [Output Methods](#output-methods)
- [Testing](#testing)
  - [Running Tests](#running-tests)
  - [Test Structure](#test-structure)
- [Contributing](#contributing)
  - [Development Setup](#development-setup)
  - [Making Changes](#making-changes)
  - [Submitting Contributions](#submitting-contributions)
- [License](#license)


## Features at a Glance

### 🚀 **Easy to Use**
- **One-liner imports**: `inputs.import-tree ./modules` for the most common use case
- **Flake-ready**: Works seamlessly with modern Nix flakes
- **Zero dependencies**: Can be used outside flakes by importing `./default.nix`

### 🎯 **Universal Compatibility**
- **Module system agnostic**: Works with NixOS, nix-darwin, home-manager, flake-parts, NixVim
- **Path flexible**: Accepts files, directories, or nested lists of paths
- **Mixed usage**: Can list other file types beyond `.nix` files

### 🔧 **Highly Customizable**
- **Extensible API**: Add custom methods with `.addAPI`
- **Smart filtering**: Built-in filters with customizable patterns
- **Transformation support**: Map functions over discovered files
- **Ignore patterns**: Sensible defaults with full customization

### 📦 **Library-Friendly**
- **Pre-configured trees**: Library authors can ship ready-to-use configurations
- **Community conventions**: Support for domain-specific naming and organization patterns
- **API composition**: Chain and combine multiple import-tree instances

## Quick Start

### For Flake Users

The simplest way to use import-tree with flake-parts to import all modules from a directory:

```nix
{
  inputs = {
    import-tree.url = "github:vic/import-tree";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs: 
    inputs.flake-parts.lib.mkFlake { inherit inputs; } 
      # This imports all .nix files from ./modules recursively
      (inputs.import-tree ./modules);
}
```

### For Non-Flake Users

You can use import-tree in traditional Nix setups by importing the library directly:

```nix
let
  # Import the library
  import-tree = import (pkgs.fetchzip {
    url = "https://github.com/vic/import-tree/archive/refs/heads/main.zip";
    hash = ""; # TODO
  });
  
  # importable module.
  module = import-tree ./modules;
in
{
  # Use in any module system
  imports = [ module ];
}
```

## The import-tree callable

An import-tree callable takes a single argument:

- A path to a directory containing files to be discovered.
- Any *path-like*: String, { outPath = "/some/path"; }.
- Another import-tree with predefined search paths. See `.addPath`.
- A nested list of these.

## Advanced Usage & API

### Filtering Files

Control which files are imported using the `.filter` method:

```nix
# Only import files containing "feature" in their path
import-tree.filter (lib.hasInfix "feature") ./modules

# Chain multiple filters (all must match)
lib.pipe import-tree [
  (i: i.filter (lib.hasInfix "desktop"))
  (i: i.filter (lib.hasSuffix "default.nix"))
  (i: i ./modules)
]
```

### Using Regular Expressions

Use `.match` for more complex pattern matching:

```nix
# Import files matching specific patterns
import-tree.match ".*/desktop@(gnome|kde)\.nix" ./modules
```

### Transforming Files

Use `.map` to transform paths before importing:

```nix
# Add debugging information to each import
import-tree.map (path: {
  imports = [ path ];
  # e.g, If we had an `_importedPaths` (listOf str) option, you can
  # track which files were automatically imported:
  _importedPaths = [ (toString path) ];
}) ./modules
```

### Working with File Lists

Get the list of discovered files without importing them:

```nix
# Get list of .nix files (remember to use withLib for non-module contexts)
nixFiles = (import-tree.withLib lib).files ./modules;

# Process non-Nix files
cssFiles = lib.pipe import-tree [
  (i: i.initFilter (lib.hasSuffix ".css"))  # Look for .css files
  (i: i.withLib lib)                        # Required for .files
  (i: i.files ./src)                        # Get the file list
];
```

### Pre-configuring Paths

Use `.addPath` to create import-tree instances with predefined search paths:

```nix
# Create a configured tree
myTree = import-tree.addPath ./modules;

# Use it with empty arguments or additional paths
config = {
  imports = [
    myTree.result              # Same as: myTree []
    (myTree ./extra-modules)   # Includes both ./modules and ./extra-modules
  ];
};
```

### Custom API Extensions

Create domain-specific APIs using `.addAPI`:

```nix
# Define a custom API for feature management
featureTree = import-tree.addAPI {
  # Method to get all available features
  all = self: self.addPath ./features;
  
  # Method to enable specific features
  enable = self: featureName: 
    self.all.filter (lib.hasInfix "+${featureName}");
  
  # Method for minimal feature set
  minimal = self: self.enable "minimal";
  
  # Method for desktop features
  desktop = self: self.enable "desktop";
};

# Usage:
{
  imports = [
    featureTree.minimal    # Only minimal features
    featureTree.desktop    # Only desktop features
  ];
}
```

## Why Use import-tree?

### The Dendritic Pattern

import-tree was inspired by the [Dendritic Pattern](https://github.com/mightyiam/dendritic), a modular approach where each file represents a focused, composable module. [This pattern offers several advantages](https://vic.github.io/dendrix/Dendritic.html):

- **Better organization**: Each file has a single responsibility
- **Easier maintenance**: Changes are isolated to specific files
- **Improved reusability**: Modules can be easily shared across configurations

Learn more from:
- [@mightyiam's original post](https://discourse.nixos.org/t/pattern-each-file-is-a-flake-parts-module/61271)
- [@drupol's practical experience](https://not-a-number.io/2025/refactoring-my-infrastructure-as-code-configurations/)
- [@vic's implementation insights](https://discourse.nixos.org/t/how-do-you-structure-your-nixos-configs/65851/8)

### Library Distribution & Community Configurations

The extensible API enables library authors to create [domain-specific import-tree configurations](https://vic.github.io/dendrix/Dendrix-Trees.html), similar to popular editor distributions (like Spacemacs or LazyVim).

#### Example: Editor Configuration Distribution

```nix
# editor-distro's flake output
{ inputs, lib, ... }:
let 
  # Pre-configured import-tree with editor-specific API
  modules-tree = lib.pipe inputs.import-tree [
    (i: i.addPath ./modules)
    (i: i.addAPI { 
      # Language-specific features
      ruby = self: self.filter (lib.hasInfix "+ruby");
      python = self: self.filter (lib.hasInfix "+python");
      
      # Editor preferences  
      vim = self: self.filter (lib.hasInfix "+vim");
      emacs = self: self.filter (lib.hasInfix "+emacs");
      
      # Feature toggles
      minimal = self: self.filterNot (lib.hasInfix "+bloat");
      ai-assist = self: self.filter (lib.hasInfix "+copilot");
    })
  ];
in {
  lib = { inherit modules-tree; };
}
```

#### Using Distributed Configurations

```nix
# Consumer flake
{ inputs, ... }:
let
  editor = inputs.editor-distro.lib.modules-tree;
in {
  imports = [
    # Compose features declaratively
    editor.vim.ruby.minimal
    
    # Mix and match as needed
    editor.python.ai-assist
  ];
}
```

This approach enables community-driven configuration sharing while maintaining the flexibility to customize for specific needs.

</details>


<details>
<summary>

## API Reference
</summary>

### Core Methods

#### `import-tree <path|paths>`
**Primary function**: Takes paths and returns a module that imports discovered files.

```nix
# Single path
import-tree ./modules

# Multiple paths  
import-tree [ ./modules ./features ]

# Nested paths (flattened automatically)
import-tree [ ./modules [ ./features ./plugins ] ]
```

### Configuration Methods

#### `.filter <predicate>`
**Filter files** by a predicate function `path -> bool`.

```nix
import-tree.filter (lib.hasInfix "desktop") ./modules
```

#### `.filterNot <predicate>`
**Exclude files** matching the predicate.

```nix
import-tree.filterNot (lib.hasInfix "experimental") ./modules
```

#### `.match <regex>`
**Filter by regex** pattern (uses `builtins.match`).

```nix
import-tree.match ".*/feature-[a-z]+\.nix" ./modules
```

#### `.map <function>`
**Transform each path** with a function `path -> any`.

```nix
import-tree.map (path: { imports = [ path ]; source = toString path; })
```

#### `.addPath <path>`
**Add paths** to be searched (accumulates with multiple calls).

```nix
(import-tree.addPath ./base).addPath ./extras
```

#### `.initFilter <predicate>`
**Replace the initial filter** (default: `.nix` files, ignore `/_` paths).

```nix
# Look for .md files instead
import-tree.initFilter (lib.hasSuffix ".md")

# Custom ignore pattern
import-tree.initFilter (p: lib.hasSuffix ".nix" p && !lib.hasInfix "/private/")
```

### Extension Methods

#### `.addAPI <attrset>`
**Extend the API** with custom methods.

```nix
import-tree.addAPI {
  stable = self: self.filter (lib.hasInfix "stable");
  beta = self: self.filter (lib.hasInfix "beta");
}
```

#### `.withLib <lib>`
**Provide lib instance** (required for `.files`, `.leafs`, `.pipeTo` methods).

```nix
import-tree.withLib pkgs.lib
```

### Output Methods

#### `.files`
**Get list of matching files** instead of importing them.

```nix
(import-tree.withLib lib).files ./modules
# => [ /path/to/modules/a.nix /path/to/modules/b.nix ]
```

#### `.result`
**Apply configured tree** with empty path list (useful for pre-configured trees).

```nix
(import-tree.addPath ./modules).result
# Same as: (import-tree.addPath ./modules) []
```

#### `.pipeTo <function>`
**Process file list** with a custom function.

```nix
import-tree.pipeTo (files: lib.length files) ./modules
# => number of discovered files
```

#### `.new`
**Create fresh instance** with empty configuration.

```nix
import-tree.addPath ./modules).new.addPath ./other
# Only includes ./other (previous config cleared)
```
</details>

## Testing

import-tree uses [checkmate](https://github.com/vic/checkmate) for testing.


```bash
# Run the full test suite
nix flake check path:checkmate --override-input target path:.

# Format code
nix run github:vic/checkmate#fmt
```
