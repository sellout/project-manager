{lib}: {
  ## This isn't in Nixpkgs 23.05, but should be in the next release.
  subpath.components = path: let
    parts = builtins.split "/+(\\./+)*" path;
    partCount = lib.length parts / 2 + 1;
    skipStart =
      if lib.head parts == "."
      then 1
      else 0;
    skipEnd =
      if lib.last parts == "." || lib.last parts == ""
      then 1
      else 0;
    componentCount = partCount - skipEnd - skipStart;
  in
    if path == "."
    then []
    else
      lib.genList (
        index:
          lib.elemAt parts ((skipStart + index) * 2)
      )
      componentCount;

  ## Find a path to `dest` from `source`. `source` must be a directory, not a
  ## file.
  ##
  ## TODO: This should normalize. Right now it always uses ../ up to the common
  ##       parent then rebuilds the entire path. E.g.,
  ##      `route ./foo/bar/baz ./foo/bar/zab` is `../../../foo/bar/zab`, but it
  ##       could be `../zab`.
  routeFromDir = sourceDir: destPath:
    lib.concatStringsSep
    "/"
    (map (_: "..") (lib.tail (lib.pm.path.subpath.components sourceDir)))
    + "/"
    + destPath;

  ## Find a path to `dest` from `source`. `source` must be a directory, not a
  ## file.
  ##
  ## TODO: This should normalize. Right now it always uses ../ up to the common
  ##       parent then rebuilds the entire path. E.g.,
  ##      `route ./foo/bar/baz ./foo/bar/zab` is `../../../foo/bar/zab`, but it
  ##       could be `../zab`.
  routeFromFile = sourceFile: destPath:
    lib.concatStringsSep
    "/"
    (map (_: "..") (lib.tail (lib.init (lib.pm.path.subpath.components sourceFile))))
    + "/"
    + destPath;
}
