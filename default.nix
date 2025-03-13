path:
{ lib, ... }:
{
  imports = lib.pipe path [
    (lib.toList)
    (lib.map lib.filesystem.listFilesRecursive)
    (lib.lists.flatten)
    (lib.filter (lib.hasSuffix ".nix"))
    (lib.filter (lib.hasInfix "/_"))
  ];
}
