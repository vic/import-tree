let
  perform =
    {
      lib ? null,
      pipef ? null,
      initf ? null,
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
        lib:
        let
          treeFiles = t: (t.withLib lib).files;

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

          nixFilter = andNot (lib.hasInfix "/_") (lib.hasSuffix ".nix");

          initialFilter = if initf != null then initf else nixFilter;

          pathFilter = compose (and filterf initialFilter) toString;

          otherFilter = and filterf (if initf != null then initf else (_: true));

          filter = x: if isPathLike x then pathFilter x else otherFilter x;

          isFileRelative =
            root:
            { file, rel }:
            if file != null && lib.hasPrefix root file then
              {
                file = null;
                rel = lib.removePrefix root file;
              }
            else
              { inherit file rel; };
          getFileRelative = { file, rel }: if rel == null then file else rel;

          makeRelative =
            roots:
            lib.pipe roots [
              (lib.lists.flatten)
              (builtins.filter isDirectory)
              (builtins.map builtins.toString)
              (builtins.map isFileRelative)
              (fx: fx ++ [ getFileRelative ])
              (
                fx: file:
                lib.pipe {
                  file = builtins.toString file;
                  rel = null;
                } fx
              )
            ];

          rootRelative =
            roots:
            let
              mkRel = makeRelative roots;
            in
            x: if isPathLike x then mkRel x else x;
        in
        root:
        lib.pipe
          [ paths root ]
          [
            (lib.lists.flatten)
            (map listFilesRecursive)
            (lib.lists.flatten)
            (builtins.filter (
              compose filter (rootRelative [
                paths
                root
              ])
            ))
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
            initFilter = initf: mergeAttrs { inherit initf; };
            pipeTo = pipef: mergeAttrs { inherit pipef; };
            leafs = mergeAttrs { pipef = (i: i); };

            # Applies empty (for already path-configured trees)
            result = (self f) [ ];

            # Return a list of all filtered files.
            files = (self f).leafs.result;

            # returns the original empty state
            new = callable;
          };
      };
    in
    __config (c: c);

in
callable
