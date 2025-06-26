let
  perform =
    {
      lib ? null,
      filterf ? null,
      mapf ? null,
      pipef ? null,
      paths ? [ ],
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
          initialFilter = andNot (lib.hasInfix "/_") (lib.hasSuffix ".nix");
          listFilesRecursive =
            x:
            if isImportTree x then
              treeFiles x
            else if lib.pathIsDirectory x then
              lib.filesystem.listFilesRecursive x
            else
              [x];
          treeFiles = t: (t.withLib lib).leafs.result;
        in
        lib.pipe
          [ paths root ]
          [
            (lib.lists.flatten)
            (map listFilesRecursive)
            (lib.lists.flatten)
            (builtins.filter (compose (and filterf initialFilter) toString))
            (map mapf)
          ];

    in
    result;

  compose =
    g: f: x:
    g (f x);

  # Applies the second filter first, to allow partial application when building the configuration.
  and =
    g: f: x:
    f x && g x;

  andNot = g: and (x: !(g x));

  matchesRegex = re: p: builtins.match re p != null;

  mapAttr =
    attrs: k: f:
    attrs // { ${k} = f attrs.${k}; };

  isImportTree = and (x: x ? __config.__functor) builtins.isAttrs;

  inModuleEval = and (x: x ? options) builtins.isAttrs;

  functor = self: arg: perform self.__config (if inModuleEval arg then [ ] else arg);

  callable =
    let
      __config = {
        # Accumulated configuration
        api = { };
        mapf = (i: i);
        filterf = _: true;
        paths = [ ];

        __functor =
          self: f:
          let
            __config = (f self);
          in
          __config.api
          // {
            inherit __config;
            __functor = functor;

            # Configuration updates (accumulating)
            filter = filterf: self (c: mapAttr (f c) "filterf" (and filterf));
            filterNot = filterf: self (c: mapAttr (f c) "filterf" (andNot filterf));
            match = regex: self (c: mapAttr (f c) "filterf" (and (matchesRegex regex)));
            matchNot = regex: self (c: mapAttr (f c) "filterf" (andNot (matchesRegex regex)));
            map = mapf: self (c: mapAttr (f c) "mapf" (compose mapf));
            addPath = path: self (c: mapAttr (f c) "paths" (p: p ++ [ path ]));
            addAPI = api: self (c: mapAttr (f c) "api" (a: a // builtins.mapAttrs (_: g: g (self f)) api));

            # Configuration updates (non-accumulating)
            withLib = lib: self (c: (f c) // { inherit lib; });
            pipeTo = pipef: self (c: (f c) // { inherit pipef; });
            leafs = self (c: (f c) // { pipef = (i: i); });

            # Applies empty (for already path-configured trees)
            result = (self f) [ ];
          };
      };
    in
    __config (c: c);

in
callable
