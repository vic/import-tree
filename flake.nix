{
  outputs = _: {
    __functor = _: import ./default.nix { };
    matching = filter: import ./default.nix { inherit filter; };
  };
}
