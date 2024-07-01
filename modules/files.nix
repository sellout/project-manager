{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = filterAttrs (n: f: f.enable) config.project.file;

  projectDirectory = config.project.projectDirectory;

  fileType =
    (import lib/file-type.nix {
      inherit projectDirectory lib pkgs;
      commit-by-default = config.project.commit-by-default;
    })
    .fileType;
in {
  options = {
    project.file = mkOption {
      description = lib.mdDoc ''
        Attribute set of files to link into the project root.
      '';
      default = {};
      type = fileType "project.file" "" projectDirectory;
    };

    project-files = mkOption {
      type = types.package;
      internal = true;
      description = lib.mdDoc ''
        Package to contain all project files
      '';
    };
  };

  config = {
    assertions = [
      (
        let
          dups =
            attrNames
            (filterAttrs (n: v: v > 1)
              (foldAttrs (acc: v: acc + v) 0
                (mapAttrsToList (n: v: {${v.target} = 1;}) cfg)));
          dupsStr = concatStringsSep ", " dups;
        in {
          assertion = dups == [];
          message = ''
            Conflicting managed target files: ${dupsStr}

            This may happen, for example, if you have a configuration similar to

                project.file = {
                  conflict1 = { source = ./foo.nix; target = "baz"; };
                  conflict2 = { source = ./bar.nix; target = "baz"; };
                }'';
        }
      )
    ];

    lib.file.mkOutOfStoreSymlink = path: let
      pathStr = toString path;
      name = pm.strings.storeFileName (baseNameOf pathStr);
    in
      pkgs.runCommandLocal name {} ''ln -s ${escapeShellArg pathStr} $out'';

    # This activation script will
    #
    # 1. Remove files from the old generation that are not in the new
    #    generation.
    #
    # 2. Switch over the Project Manager gcroot and current profile
    #    links.
    #
    # 3. Symlink files from the new generation into $PROJECT_ROOT.
    #
    # This order is needed to ensure that we always know which links
    # belong to which generation. Specifically, if we're moving from
    # generation A to generation B having sets of project file links FA
    # and FB, respectively then cleaning before linking produces state
    # transitions similar to
    #
    #      FA   →   FA ∩ FB   →   (FA ∩ FB) ∪ FB = FB
    #
    # and a failure during the intermediate state FA ∩ FB will not
    # result in lost links because this set of links are in both the
    # source and target generation.
    project.activation.linkGeneration = pm.dag.entryAfter ["writeBoundary"] (
      let
        link = pkgs.writeShellScript "link" ''
          ## TODO: Extract this to be used by other scripts.
          function create_reference() {
            sourcePath="$1"
            relativePath="$2"
            targetPath="$PROJECT_ROOT/$relativePath"
            if [[ -e "$targetPath" && ! -L "$targetPath" ]] && cmp -s "$sourcePath" "$targetPath" ; then
              # The target exists but is identical – don’t do anything.
              "''${VERBOSE_ECHO}" "Skipping '$relativePath' as it is identical to '$sourcePath'"
            else
              mkdir -p $(dirname "$relativePath")
              ## Try a symlink (if allowed), then a hard link, then a copy
              ([[ ''${persistence[$relativePath]} == worktree && ! ''${broken_symlink[$relativePath]} ]] \
                  && "''${DRY_RUN_CMD[@]}" ln -Tsf "''${VERBOSE_ARG[@]}" "$sourcePath" "$targetPath") \
                || ([[ ''${persistence[$relativePath]} != store ]] \
                      && ("''${DRY_RUN_CMD[@]}" ln -Tf "''${VERBOSE_ARG[@]}" "$sourcePath" "$targetPath" 2>/dev/null \
                          || "''${DRY_RUN_CMD[@]}" cp -T --remove-destination "''${VERBOSE_ARG[@]}" "$sourcePath" "$targetPath" \
                          || ("''${VERBOSE_ECHO}" "failed to create “$targetPath”" && exit 1))) \
                || true
            fi
          }

          newGenFiles="$1"
          shift
          declare -A persistence=( )
          while read -r var value; do
            persistence[$var]=$value
          done < "$newGenFiles/pm-metadata/persistence"
          declare -A broken_symlink=( )
          while read -r var value; do
            broken_symlink[$var]=$value
          done < "$newGenFiles/pm-metadata/broken_symlink"
          for sourcePath in "$@" ; do
            targetPath="''${sourcePath#$newGenFiles/}"
            [[ $targetPath =~ pm-metadata ]] && continue
            create_reference "$sourcePath" "$targetPath"
          done
        '';

        cleanup = pkgs.writeShellScript "cleanup" ''
          ${config.lib.bash.initProjectManagerLib}

          # A symbolic link whose target path matches this pattern will be
          # considered part of a Project Manager generation.
          projectFilePattern="$(readlink -e ${escapeShellArg builtins.storeDir})/*-project-manager-files/*"

          newGenFiles="$1"
          shift 1
          for relativePath in "$@" ; do
            targetPath="$PROJECT_ROOT/$relativePath"
            if [[ -e "$newGenFiles/$relativePath" ]] ; then
              "''${VERBOSE_ECHO}" "Checking $targetPath: exists"
            else
              "''${VERBOSE_ECHO}" "Checking $targetPath: gone (deleting)"
              "''${DRY_RUN_CMD[@]}" rm "''${VERBOSE_ARG[@]}" "$targetPath" || true

              # Recursively delete empty parent directories.
              targetDir="$(dirname "$relativePath")"
              if [[ "$targetDir" != "." ]] ; then
                pushd "$PROJECT_ROOT" > /dev/null

                # Call rmdir with a relative path excluding $PROJECT_ROOT.
                # Otherwise, it might try to delete $PROJECT_ROOT and exit
                # with a permission error.
                "''${DRY_RUN_CMD[@]}" rmdir "''${VERBOSE_ARG[@]}" \
                    -p --ignore-fail-on-non-empty \
                    "$targetDir" \
                  || true

                popd > /dev/null
              fi
            fi
          done
        '';
      in ''
        function linkNewGen() {
          _i "Creating project file links in %s" "$PROJECT_ROOT"

          local newGenFiles
          newGenFiles="$(readlink -e "$newGenPath/project-files")"
          find "$newGenFiles" \( -type f -or -type l \) \
            -exec bash ${link} "$newGenFiles" {} +
        }

        function cleanOldGen() {
          if [[ ! -v oldGenPath || ! -e "$oldGenPath/project-files" ]] ; then
            return
          fi

          _i "Cleaning up orphan links from %s" "$PROJECT_ROOT"

          local newGenFiles oldGenFiles
          newGenFiles="$(readlink -e "$newGenPath/project-files")"
          oldGenFiles="$(readlink -e "$oldGenPath/project-files")"

          # Apply the cleanup script on each leaf in the old
          # generation. The find command below will print the
          # relative path of the entry.
          find "$oldGenFiles" '(' -type f -or -type l ')' -printf '%P\0' \
            | xargs -0 bash ${cleanup} "$newGenFiles"
        }

        cleanOldGen

        function nixProfileList() {
          # We attempt to use `--json` first (added in Nix 2.17 / Nixpkgs
          # 23.11)). Otherwise attempt to parse the legacy output format.
          {
            nix profile list --profile $1 --json 2>/dev/null \
              | jq --raw-output '.elements[].storePaths[]'
          } || {
            nix profile list --profile $1 | cut -d ' ' -f 4
          }
        }

        if [[ ! -v oldGenPath || "$oldGenPath" != "$newGenPath" ]] ; then
          _i "Creating profile generation %s" $newGenNum
          # Remove all packages from "$genProfilePath"
          # `nix profile remove '.*' --profile "$genProfilePath"` was not
          # working (NixOS/nix#7487), so here is a workaround:
          nixProfileList "$genProfilePath" \
            | xargs "''${VERBOSE_ARG[@]}" "''${DRY_RUN_CMD[@]}" nix profile remove "''${VERBOSE_ARG[@]}" --profile "$genProfilePath"
          "''${DRY_RUN_CMD[@]}" nix profile install "''${VERBOSE_ARG[@]}" --profile "$genProfilePath" "$newGenPath"

          "''${DRY_RUN_CMD[@]}" nix-store --realise "$newGenPath" --add-root "$newGenGcPath" > "$DRY_RUN_NULL"
        else
          _i "No change so reusing latest profile generation %s" "$oldGenNum"
        fi

        linkNewGen
      ''
    );

    project.activation.checkFilesChanged = pm.dag.entryBefore ["linkGeneration"] (
      let
        projectDirArg = escapeShellArg projectDirectory;
      in
        ''
          function _cmp() {
            if [[ -d $1 && -d $2 ]]; then
              diff -rq "$1" "$2" &> /dev/null
            else
              cmp --quiet "$1" "$2"
            fi
          }
          declare -A changedFiles
        ''
        + concatMapStrings (v: let
          sourceArg = escapeShellArg v.storePath;
          targetArg = escapeShellArg v.target;
        in ''
          _cmp ${sourceArg} ${projectDirArg}/${targetArg} \
            && changedFiles[${targetArg}]=0 \
            || changedFiles[${targetArg}]=1
        '') (filter (v: v.onChange != "") (attrValues cfg))
        + ''
          unset -f _cmp
        ''
    );

    project.activation.onFilesChange = pm.dag.entryAfter ["linkGeneration"] (
      concatMapStrings (v: ''
        if (( ''${changedFiles[${escapeShellArg v.target}]} == 1 )); then
          if [[ -v DRY_RUN || -v VERBOSE ]]; then
            echo "Running onChange hook for" ${escapeShellArg v.target}
          fi
          if [[ ! -v DRY_RUN ]]; then
            ${v.onChange}
          fi
        fi
      '') (filter (v: v.onChange != "") (attrValues cfg))
    );

    # Symlink directories and files that have the right execute bit.
    # Copy files that need their execute bit changed.
    project-files =
      pkgs.runCommandLocal
      "project-manager-files-for-${config.project.name}"
      {
        nativeBuildInputs = [pkgs.xorg.lndir];
      }
      (''
          mkdir -p $out

          # Needed in case /nix is a symbolic link.
          realOut="$(realpath -m "$out")"
          mkdir -p "$realOut/pm-metadata"

          function insertFile() {
            local source="$1"
            local relTarget="$2"
            local executable="$3"
            local recursive="$4"
            local persistence="$5"
            local broken_symlink="$6"

            ## TOOD: There should be a safer place for this (i.e., if there is a
            ##       real file called `pm-metadata`, we’ll mess it up).
            echo "$relTarget $persistence" >> $realOut/pm-metadata/persistence
            echo "$relTarget $broken_symlink" >> $realOut/pm-metadata/broken_symlink

            # If the target already exists then we have a collision. Note, this
            # should not happen due to the assertion found in the “files” module.
            # We therefore simply log the conflict and otherwise ignore it, mainly
            # to make the `files-target-config` test work as expected.
            if [[ -e "$realOut/$relTarget" ]]; then
              echo "File conflict for file “$relTarget”" >&2
              return
            fi

            # Figure out the real absolute path to the target.
            local target
            target="$(realpath -m "$realOut/$relTarget")"

            # Target path must be within $PROJECT_ROOT.
            if [[ ! $target == $realOut* ]] ; then
              echo "Error installing file “$relTarget” outside \$PROJECT_ROOT" >&2
              exit 1
            fi

            mkdir -p "$(dirname "$target")"
            if [[ -d $source ]]; then
              if [[ $recursive ]]; then
                mkdir -p "$target"
                lndir -silent "$source" "$target"
              else
                ln -s "$source" "$target"
              fi
            else
              [[ -x $source ]] && isExecutable=1 || isExecutable=""

              # Link the file into the project file directory if possible,
              # i.e., if the executable bit of the source is the same we
              # expect for the target. Otherwise, we copy the file and
              # set the executable bit to the expected value.
              if [[ $executable == inherit || $isExecutable == $executable ]]; then
                ln -s "$source" "$target"
              else
                cp "$source" "$target"

                if [[ $executable == inherit ]]; then
                  # Don’t change file mode if it should match the source.
                  :
                elif [[ $executable ]]; then
                  chmod +x "$target"
                else
                  chmod -x "$target"
                fi
              fi
            fi
          }
        ''
        + concatStrings (
          mapAttrsToList (n: v: ''
            insertFile ${
              escapeShellArgs [
                v.storePath
                v.target
                (
                  if v.executable == null
                  then "inherit"
                  else toString v.executable
                )
                (toString v.recursive)
                v.persistence
                v.broken-symlink
              ]
            }
          '')
          cfg
        ));
  };
}
