{
  filter ? null,
}:
let

  leafs =
    lib: root:
    let
      notHasInfix = a: b: !lib.hasInfix a b;
      stringFilter = f: path: f (builtins.toString path);
    in
    lib.pipe root [
      (lib.toList)
      (lib.lists.flatten)
      (lib.map lib.filesystem.listFilesRecursive)
      (lib.lists.flatten)
      (lib.filter (stringFilter (lib.hasSuffix ".nix")))
      (lib.filter (stringFilter (if filter == null then (notHasInfix "/_") else filter)))
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
