let
  ## This follows Semantic Versioning 2.0.0 (https://semver.org/)
  version = {
    major = 0;
    minor = 6;
    patch = 1;
  };
in {
  inherit version;
  release = (
    with version; "${toString major}.${toString minor}.${toString patch}"
  );
  isReleaseBranch = true;
}
