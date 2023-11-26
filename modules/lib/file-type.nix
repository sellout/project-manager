{
  commit-by-default,
  projectDirectory,
  lib,
  pkgs,
}: let
  inherit
    (lib)
    hasPrefix
    pm
    literalExpression
    mkDefault
    mkIf
    mkOption
    removePrefix
    types
    ;

  persistenceType = types.enum [
    "store"
    "worktree"
    "repository"
  ];
in rec {
  fileContents = opt: basePathDesc: basePath: nameStr: (types.submodule (
    {
      name,
      config,
      ...
    }: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = lib.mdDoc ''
            Whether this file should be generated. This option allows specific
            files to be disabled.
          '';
        };

        target = mkOption {
          type = types.str;
          apply = p: let
            absPath =
              if hasPrefix "/" p
              then p
              else "${basePath}/${p}";
          in
            removePrefix (projectDirectory + "/") absPath;
          defaultText = lib.literalMD "name";
          description = lib.mdDoc ''
            Path to target file relative to ${basePathDesc}.
          '';
        };

        text = mkOption {
          default = null;
          type = types.nullOr types.lines;
          description = lib.mdDoc ''
            Text of the file. If this option is null then
            [](#opt-${opt}.${nameStr}.source)
            must be set.
          '';
        };

        source = mkOption {
          type = types.path;
          description = lib.mdDoc ''
            Path of the source file or directory. If
            [](#opt-${opt}.${nameStr}.text)
            is non-null then this option will automatically point to a file
            containing that text.
          '';
        };

        storePath = mkOption {
          type = types.path;
          internal = true;
          description = lib.mdDoc ''
            The Nix store path for this file. This is used by Project Manager to
            reference files without having to link them into the working tree.
          '';
        };

        referenceViaStore = mkOption {
          type = types.functionTo types.bool;
          internal = true;
          description = lib.mdDoc ''
            Whether the file should be referenced from the store (as opposed to
            the working tree). The argument is where the reference will be used.

            In most cases, `reference` can be used instead to get the path to
            use as a reference directly. But this is useful when that isn't
            enough.
          '';
        };

        reference = mkOption {
          type = types.functionTo types.str;
          internal = true;
          description = lib.mdDoc ''
            The path that should be used for references to this file. If the
            file is store persisted, then this points to the store, otherwise it
            points into the worktree. The function takes the location that the
            reference will be used from, returning a path relative to that
            location.
          '';
        };

        executable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = lib.mdDoc ''
            Set the execute bit. If `null`, defaults to the mode
            of the {var}`source` file or to `false`
            for files created through the {var}`text` option.
          '';
        };

        recursive = mkOption {
          type = types.bool;
          default = false;
          description = lib.mdDoc ''
            If the file source is a directory, then this option
            determines whether the directory should be recursively
            linked to the target location. This option has no effect
            if the source is a file.

            If `false` (the default) then the target
            will be a symbolic link to the source directory. If
            `true` then the target will be a
            directory structure matching the source's but whose leafs
            are symbolic links to the files of the source directory.
          '';
        };

        onChange = mkOption {
          type = types.lines;
          default = "";
          description = lib.mdDoc ''
            Shell commands to run when file has changed between
            generations. The script will be run
            *after* the new files have been linked
            into place.

            Note, this code is always run when `recursive` is
            enabled.
          '';
        };

        force = mkOption {
          type = types.bool;
          default = false;
          visible = false;
          description = lib.mdDoc ''
            Whether the target path should be unconditionally replaced
            by the managed file source. Warning, this will silently
            delete the target regardless of whether it is a file or
            link.
          '';
        };

        minimum-persistence = mkOption {
          type = persistenceType;
          default = "repository";
          description = lib.mdDoc ''
            How we store the file. The options are “store” (file will be
            referenced by the worktree on demand), “worktree” (persist the file
            in the worktree), and “repository” (commit the file in the
            worktree). The second will also be added to the project’s .gitignore,
            while the last will instead be added to .gitattributes with a
            “linguist-generated” attribute.
          '';
        };

        broken-symlink = mkOption {
          type = types.bool;
          default = false;
          description = lib.mdDoc ''
            This option is only relevant when `minimum-persistence` isn’t
            “repository”. It indicates whether or not the file can be referenced
            with a symlink. If this is true, then the file will not be symlinked
            into the worktree, but will be represented with either a hard link
            or a copy. Hard links are preferred over symlinks in some contexts
            anyway, but then the store is on a different volume from the
            worktree, hard links aren’t viable.
          '';
        };

        commit-by-default = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = lib.mdDoc ''
            Whether to accept the `minimum-persistence` value (`false`) or to
            force the persistence to “repository” (`true`). The latter is useful
            when you want to use a file outside of its standard use case. E.g.,
            `.gitattributes` sets this to true when github is enabled, so that
            the `lingist-generated` attribute can be processed by GitHub. `null`
            inherits the project-wide setting.
          '';
        };

        persistence = mkOption {
          internal = true;
          type = persistenceType;
          description = lib.mdDoc ''
            How we store the file. The options are “store” (file will be
            referenced by the worktree on demand), “worktree” (persist the file
            in the worktree), and “repository” (commit the file in the
            worktree). The second will also be added to the project’s .gitignore,
            while the last will instead be added to .gitattributes with a
            “linguist-generated” attribute.
          '';
        };
      };

      config = {
        target = mkDefault name;
        source = mkIf (config.text != null) (
          mkDefault (pkgs.writeTextFile {
            inherit (config) text;
            executable = config.executable == true; # can be null
            name = pm.strings.storeFileName name;
          })
        );
        storePath = let
          sourcePath = toString config.source;
          sourceName = pm.strings.storeFileName (baseNameOf sourcePath);
        in
          if builtins.hasContext sourcePath
          then config.source
          else
            builtins.path {
              path = config.source;
              name = sourceName;
            };

        referenceViaStore = referencingFile:
          config.persistence == "store" || referencingFile.persistence == "store";

        reference = referencingFile:
          if config.referenceViaStore referencingFile
          ## Absolute path to the store. We do this in all cases where the
          ## referencing file isn't persisted to the working tree to avoid
          ## having references outside of the store, especially ones that will
          ## vary between users.
          then toString config.storePath
          ## Relative path within worktree
          else lib.pm.path.routeFromFile referencingFile.target config.target;

        persistence = lib.mkForce (
          if
            (
              if config.commit-by-default == null
              then commit-by-default
              else config.commit-by-default
            )
          then "repository"
          else config.minimum-persistence
        );
      };
    }
  ));

  # Constructs a type suitable for a `project.file` like option. The
  # target path may be either absolute or relative, in which case it
  # is relative the `basePath` argument (which itself must be an
  # absolute path).
  #
  # Arguments:
  #   - opt            the name of the option, for self-references
  #   - basePathDesc   docbook compatible description of the base path
  #   - basePath       the file base path
  fileType = opt: basePathDesc: basePath:
    types.attrsOf (fileContents opt basePathDesc basePath "_name_");
}
