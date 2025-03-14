{
  filter ? null,
  regex ? null,
}:
let

  leafs =
    lib: root:
    let
      isNixFile = lib.hasSuffix ".nix";
      notIgnored = p: !lib.hasInfix "/_" p;
      matchesRegex = a: b: (lib.strings.match a b) != null;

      stringFilter = f: path: f (builtins.toString path);
      filterWithS = f: lib.filter (stringFilter f);

      userFilter =
        if filter != null then
          filter
        else if regex != null then
          matchesRegex regex
        else
          (_: true);

    in
    lib.pipe root [
      (lib.toList)
      (lib.lists.flatten)
      (lib.map lib.filesystem.listFilesRecursive)
      (lib.lists.flatten)
      (filterWithS isNixFile)
      (filterWithS notIgnored)
      (filterWithS userFilter)
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
