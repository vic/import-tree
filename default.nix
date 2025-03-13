{
  filter ? null,
}:
path: {
  imports =
    let
      inner =
        { lib, ... }:
        {
          imports = lib.pipe path [
            (lib.toList)
            (lib.lists.flatten)
            (lib.map lib.filesystem.listFilesRecursive)
            (lib.lists.flatten)
            (lib.filter (lib.hasSuffix ".nix"))
            (lib.filter (if filter == null then (i: !lib.hasInfix "/_" i) else filter))
          ];
        };
    in
    [ inner ];
}
