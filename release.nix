let
  ## This follows Semantic Versioning 2.0.0 (https://semver.org/)
  version = {
    major = 0;
    minor = 7;
    patch = 0;
  };
in {
  inherit version;
  release = (
    with version; "${toString major}.${toString minor}.${toString patch}"
  );
  isReleaseBranch = true;
}
