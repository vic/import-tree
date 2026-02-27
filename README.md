<p align="right">
  <a href="https://dendritic.oeiuwq.com/sponsor"><img src="https://img.shields.io/badge/sponsor-vic-white?logo=githubsponsors&logoColor=white&labelColor=%23FF0000" alt="Sponsor Vic"/>
  </a>
  <a href="https://dendritic.oeiuwq.com"> <img src="https://img.shields.io/badge/Dendritic-Nix-informational?logo=nixos&logoColor=white" alt="Dendritic Nix"/> </a>
  <a href="LICENSE"> <img src="https://img.shields.io/github/license/vic/import-tree" alt="License"/> </a>
  <a href="https://github.com/vic/import-tree/actions">
  <img src="https://github.com/vic/import-tree/actions/workflows/test.yml/badge.svg" alt="CI Status"/> </a>
</p>

> `import-tree` and [vic](https://bsky.app/profile/oeiuwq.bsky.social)'s [dendritic libs](https://dendritic.oeiuwq.com) made for you with Love++ and AI--. If you like my work, consider [sponsoring](https://dendritic.oeiuwq.com/sponsor)

# 🌲🌴 import-tree 🎄🌳

> Recursively import [Nix modules](https://nix.dev/tutorials/module-system/) from a directory, with a simple, extensible API.

## Quick Start (flake-parts)

```nix
{
  inputs.import-tree.url = "github:vic/import-tree";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; }
   (inputs.import-tree ./modules);
}
```

By default, paths having `/_` are ignored.

## Features

🌳 Works with NixOS, nix-darwin, home-manager, flake-parts, NixVim, etc.\
🌲 Callable as a deps-free Flake or nix lib.\
🌴 Sensible defaults and configurable behaviour.\
🌵 Chain `.filter`, `.match`, `.map` for precise file selection.\
🎄 Extensible: `.addAPI` to create domain-specific instances.\
🌿 Built for the [Dendritic Pattern](https://github.com/mightyiam/dendritic).\
🌱 [Growing](https://github.com/search?q=language%3ANix+import-tree&type=code) [community](https://vic.github.io/dendrix/Dendrix-Trees.html) [adoption](https://github.com/vic/flake-file)

## Documentation

📖 **[Full documentation](https://import-tree.oeiuwq.com)** — guides, API reference, and examples.

## Testing

`import-tree` uses [`checkmate`](https://github.com/vic/checkmate) for testing:

```sh
nix flake check github:vic/checkmate --override-input target path:.
```
