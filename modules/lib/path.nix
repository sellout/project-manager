{lib}: let
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

  ## TODO: This should normalize. Right now it always uses ../ up to the common
  ##       parent then rebuilds the entire path. E.g.,
  ##      `route ./foo/bar/baz ./foo/bar/zab` is `../../../foo/bar/zab`, but it
  ##       could be `../zab`.
  routeFromComponents = components: destPath:
    lib.concatStringsSep "/" (map (_: "..") components ++ [destPath]);
in {
  inherit subpath;

  ## Find a path to `dest` from `source`. `source` must be a directory, not a
  ## file.
  routeFromDir = sourceDir:
    routeFromComponents (lib.pm.path.subpath.components sourceDir);

  ## Find a path to `dest` from the directory containing `source`. `source`
  ## must be a file, not a directory.
  routeFromFile = sourceFile:
    routeFromComponents (lib.init (lib.pm.path.subpath.components sourceFile));
}
