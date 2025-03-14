{
  outputs = _: {
    __functor = _: import ./default.nix { };
    filtered = filter: import ./default.nix { inherit filter; };
    matching = regex: import ./default.nix { inherit regex; };
  };
}
