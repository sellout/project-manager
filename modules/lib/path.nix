{lib}: {
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
    (map (_: "..") (lib.tail (lib.path.subpath.components sourceDir)))
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
    (map (_: "..") (lib.tail (lib.init (lib.path.subpath.components sourceFile))))
    + "/"
    + destPath;
}
