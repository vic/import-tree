{
  filter ? null,
}:
let

  leafs =
    lib: root:
    lib.pipe root [
      (lib.toList)
      (lib.lists.flatten)
      (lib.map lib.filesystem.listFilesRecursive)
      (lib.lists.flatten)
      (lib.filter (lib.hasSuffix ".nix"))
      (lib.filter (if filter == null then (i: !lib.hasInfix "/_" i) else filter))
    ];

  # module exists so we delay access to lib til we are part of the module system.
  module =
    path:
    { lib, ... }:
    {
      imports = leafs lib path;
    };

in
{
  inherit leafs;
  __functor = _: path: { imports = [ (module path) ]; };
}
