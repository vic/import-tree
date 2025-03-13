path:
{ lib, ... }:
{
  imports = lib.pipe path [
    lib.filesystem.listFilesRecursive
    (lib.filter (lib.hasSuffix ".nix"))
    (lib.filter (lib.hasInfix "/_"))
  ];
}
