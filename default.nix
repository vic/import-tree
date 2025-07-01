let
  perform =
    {
      lib ? null,
      pipef ? null,
      filterf,
      mapf,
      paths,
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
            else if hasOutPath x then
              listFilesRecursive x.outPath
            else if isDirectory x then
              lib.filesystem.listFilesRecursive x
            else
              [ x ];
          treeFiles = t: (t.withLib lib).leafs.result;
          pathFilter = compose (and filterf initialFilter) toString;
          filter = x: if isPathLike x then pathFilter x else filterf x;
        in
        lib.pipe
          [ paths root ]
          [
            (lib.lists.flatten)
            (map listFilesRecursive)
            (lib.lists.flatten)
            (builtins.filter filter)
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

  isDirectory = and (x: builtins.readFileType x == "directory") isPathLike;

  isPathLike = x: builtins.isPath x || builtins.isString x || hasOutPath x;

  hasOutPath = and (x: x ? outPath) builtins.isAttrs;

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
            boundAPI = builtins.mapAttrs (_: g: g (self f)) __config.api;
            accAttr = attrName: acc: self (c: mapAttr (f c) attrName acc);
            mergeAttrs = attrs: self (c: (f c) // attrs);
          in
          boundAPI
          // {
            inherit __config;
            __functor = functor;

            # Configuration updates (accumulating)
            filter = filterf: accAttr "filterf" (and filterf);
            filterNot = filterf: accAttr "filterf" (andNot filterf);
            match = regex: accAttr "filterf" (and (matchesRegex regex));
            matchNot = regex: accAttr "filterf" (andNot (matchesRegex regex));
            map = mapf: accAttr "mapf" (compose mapf);
            addPath = path: accAttr "paths" (p: p ++ [ path ]);
            addAPI = api: accAttr "api" (a: a // api);

            # Configuration updates (non-accumulating)
            withLib = lib: mergeAttrs { inherit lib; };
            pipeTo = pipef: mergeAttrs { inherit pipef; };
            leafs = mergeAttrs { pipef = (i: i); };

            # Applies empty (for already path-configured trees)
            result = (self f) [ ];

            # returns the original empty state
            new = callable;
          };
      };
    in
    __config (c: c);

in
callable
