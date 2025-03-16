let

  perform =
    {
      lib ? null,
      filter ? null,
      regex ? null,
      mapf ? null,
      pipef ? null,
      ...
    }:
    path:
    let
      result =
        if pipef == null then
          { imports = [ module ]; }
        else if lib == null then
          throw "You need to call withLib before trying to read the tree."
        else
          pipef (leafs lib path);

      # module exists so we delay access to lib til we are part of the module system.
      module =
        { lib, ... }:
        {
          imports = leafs lib path;
        };

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

          mapped = if mapf != null then lib.map mapf else (i: i);

        in
        lib.pipe root [
          (lib.toList)
          (lib.lists.flatten)
          (lib.map lib.filesystem.listFilesRecursive)
          (lib.lists.flatten)
          (filterWithS isNixFile)
          (filterWithS notIgnored)
          (filterWithS userFilter)
          (mapped)
        ];

    in
    result;

  functor = self: perform self.config;
  callable =
    let
      config = {
        __functor = self: f: {
          config = (f self);
          __functor = functor;
          flakeModules.nix-unit = ./checks/flakeModule.nix;

          withLib = lib: self (c: (f c) // { inherit lib; });

          filtered = filter: self (c: (f c) // { inherit filter; });

          matching = regex: self (c: (f c) // { inherit regex; });

          mapWith = mapf: self (c: (f c) // { inherit mapf; });

          pipeTo = pipef: self (c: (f c) // { inherit pipef; });

          leafs = self (c: (f c) // { pipef = (i: i); });
        };
      };
    in
    config (c: c);

in
callable
