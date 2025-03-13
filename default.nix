{
  filter ? null,
}:
let

  leafs =
    lib: root:
    let
      # using toString prevents the path from being copied to the store (and exist)
      hasSuffix = a: b: lib.hasSuffix a (lib.toString b);
      hasInfix = a: b: lib.hasInfix a (lib.toString b);
      notHasInfix = a: b: !hasInfix a b;
    in
    lib.pipe root [
      (lib.toList)
      (lib.lists.flatten)
      (lib.map lib.filesystem.listFilesRecursive)
      (lib.lists.flatten)
      (lib.filter (hasSuffix ".nix"))
      (lib.filter (if filter == null then (notHasInfix "/_") else filter))
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
