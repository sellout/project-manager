{
  config,
  lib,
  ...
}:
with lib; let
  releaseInfo = import ../../release.nix;
in {
  options = {
    project.stateVersion = mkOption {
      type = types.ints.between 0 releaseInfo.version.major;
      description = ''
        It is occasionally necessary for Project Manager to change configuration
        defaults in a way that is incompatible with stateful data. This could,
        for example, include switching the default data format or location of a
        file.

        The *state version* indicates which default settings are in effect and
        will therefore help avoid breaking program configurations. Switching to
        a higher state version typically requires performing some manual steps,
        such as data conversion or moving files.

        The state version corresponds to the major version component of the
        Project Manager release where those defaults were specified. The value
        can be set to any Project Manager release up to and including this one.
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
        example = "0.3.0+213a0629";
        description = "The full Project Manager version.";
      };

      release = mkOption {
        internal = true;
        readOnly = true;
        type = types.str;
        default = releaseInfo.release;
        example = "0.3.0";
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
