{
  config,
  lib,
  ...
}:
with lib; let
  releaseInfo = {
    release = "23.05";
    isReleaseBranch = true;
  };
in {
  options = {
    project.stateVersion = mkOption {
      type = types.enum [
        "23.05"
        "23.11"
      ];
      description = ''
        It is occasionally necessary for Project Manager to change
        configuration defaults in a way that is incompatible with
        stateful data. This could, for example, include switching the
        default data format or location of a file.

        The *state version* indicates which default
        settings are in effect and will therefore help avoid breaking
        program configurations. Switching to a higher state version
        typically requires performing some manual steps, such as data
        conversion or moving files.
      '';
    };

    project.version = {
      full = mkOption {
        internal = true;
        readOnly = true;
        type = types.str;
        default = let
          inherit (config.project.version) release revision;
          suffix =
            optionalString (revision != null) "+${substring 0 8 revision}";
        in "${release}${suffix}";
        example = "23.05+213a0629";
        description = "The full Project Manager version.";
      };

      release = mkOption {
        internal = true;
        readOnly = true;
        type = types.str;
        default = releaseInfo.release;
        example = "23.05";
        description = "The Project Manager release.";
      };

      isReleaseBranch = mkOption {
        internal = true;
        readOnly = true;
        type = types.bool;
        default = releaseInfo.isReleaseBranch;
        description = ''
          Whether the Project Manager version is from a versioned
          release branch.
        '';
      };

      revision = mkOption {
        internal = true;
        type = types.nullOr types.str;
        default = let
          gitRepo = "${toString ./../..}/.git";
        in
          if pathIsGitRepo gitRepo
          then commitIdFromGitRepo gitRepo
          else null;
        description = ''
          The Git revision from which this Project Manager configuration was
          built.
        '';
      };
    };
  };
}
