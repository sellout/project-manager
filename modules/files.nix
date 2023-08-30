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
    })
    .fileType;

  sourceStorePath = file: let
    sourcePath = toString file.source;
    sourceName = config.lib.strings.storeFileName (baseNameOf sourcePath);
  in
    if builtins.hasContext sourcePath
    then file.source
    else
      builtins.path {
        path = file.source;
        name = sourceName;
      };
in {
  options = {
    project.file = mkOption {
      description = "Attribute set of files to link into the project root.";
      default = {};
      type = fileType "project.file" "" projectDirectory;
    };

    project-files = mkOption {
      type = types.package;
      internal = true;
      description = "Package to contain all project files";
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

    # This verifies that the links we are about to create will not
    # overwrite an existing file.
    project.activation.checkLinkTargets = pm.dag.entryBefore ["writeBoundary"] (
      let
        # Paths that should be forcibly overwritten by Project Manager.
        # Caveat emptor!
        forcedPaths =
          concatMapStringsSep " " (p: ''"$PROJECT_ROOT"/${escapeShellArg p}'')
          (mapAttrsToList (n: v: v.target)
            (filterAttrs (n: v: v.force) cfg));

        check = pkgs.writeText "check" ''
          ${config.lib.bash.initProjectManagerLib}

          # A symbolic link whose target path matches this pattern will be
          # considered part of a Project Manager generation.
          projectFilePattern="$(readlink -e ${escapeShellArg builtins.storeDir})/*-project-manager-files/*"

          forcedPaths=(${forcedPaths})

          newGenFiles="$1"
          shift
          declare -A persistence=( )
          while read -r var value; do
            persistence[$var]=$value
          done < "$newGenFiles/pm-metadata"
          for sourcePath in "$@" ; do
            relativePath="''${sourcePath#$newGenFiles/}"
            targetPath="$PROJECT_ROOT/$relativePath"

            forced=""
            for forcedPath in "''${forcedPaths[@]}"; do
              if [[ $targetPath == $forcedPath* ]]; then
                forced="yeah"
                break
              fi
            done

            if [[ -n $forced ]]; then
              $VERBOSE_ECHO "Skipping collision check for $targetPath"
            elif [[ -e "$targetPath" \
                && ''${persistence[$relativePath]} == store \
                && ! "$(readlink "$targetPath")" == $projectFilePattern ]] ; then
              # The target file already exists and it isn't a symlink owned by Project Manager (but _should_ be a symlink).
              if cmp -s "$sourcePath" "$targetPath"; then
                # First compare the files' content. If they're equal, we're fine.
                warnEcho "Existing file '$targetPath' is in the way of '$sourcePath', will be skipped since they are the same"
              elif [[ ! -L "$targetPath" && -n "$PROJECT_MANAGER_BACKUP_EXT" ]] ; then
                # Next, try to move the file to a backup location if configured and possible
                backup="$targetPath.$PROJECT_MANAGER_BACKUP_EXT"
                if [[ -e "$backup" ]]; then
                  errorEcho "Existing file '$backup' would be clobbered by backing up '$targetPath'"
                  collision=1
                else
                  warnEcho "Existing file '$targetPath' is in the way of '$sourcePath', will be moved to '$backup'"
                fi
              else
                # Fail if nothing else works
                errorEcho "Existing file '$targetPath' is in the way of '$sourcePath'"
                collision=1
              fi
            fi
          done

          if [[ -v collision ]] ; then
            errorEcho "Please move the above files and try again or use 'project-manager switch -b backup' to back up existing files automatically."
            exit 1
          fi
        '';
      in ''
        function checkNewGenCollision() {
          local newGenFiles
          newGenFiles="$(readlink -e "$newGenPath/project-files")"
          find "$newGenFiles" \( -type f -or -type l \) \
              -exec bash ${check} "$newGenFiles" {} +
        }

        checkNewGenCollision || exit 1
      ''
    );

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
          newGenFiles="$1"
          shift
          declare -A persistence=( )
          while read -r var value; do
            persistence[$var]=$value
          done < "$newGenFiles/pm-metadata"
          for sourcePath in "$@" ; do
            relativePath="''${sourcePath#$newGenFiles/}"
            [[ $relativePath == pm-metadata ]] && continue
            targetPath="$PROJECT_ROOT/$relativePath"
            if [[ -e "$targetPath" && ! -L "$targetPath" && -n "$PROJECT_MANAGER_BACKUP_EXT" ]] ; then
              # The target exists, back it up
              backup="$targetPath.$PROJECT_MANAGER_BACKUP_EXT"
              $DRY_RUN_CMD mv $VERBOSE_ARG "$targetPath" "$backup" || errorEcho "Moving '$targetPath' failed!"
            fi

            if [[ -e "$targetPath" && ! -L "$targetPath" && ''${persistence[$relativePath]} != store ]] && cmp -s "$sourcePath" "$targetPath" ; then
              # The target exists but is identical – don't do anything.
              $VERBOSE_ECHO "Skipping '$targetPath' as it is identical to '$sourcePath'"
            else
              # Place that symlink, --force
              # This can still fail if the target is a directory, in which case we bail out.
              $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "$(dirname "$targetPath")"
              if [[ ''${persistence[$relativePath]} == store ]]; then
                $DRY_RUN_CMD ln -Tsf $VERBOSE_ARG "$sourcePath" "$targetPath" || exit 1
              else
                $DRY_RUN_CMD ln -Tf $VERBOSE_ARG "$sourcePath" "$targetPath" 2>/dev/null \
                  || $DRY_RUN_CMD cp -T --remove-destination $VERBOSE_ARG "$sourcePath" "$targetPath" \
                  || exit 1
              fi
            fi
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
              $VERBOSE_ECHO "Checking $targetPath: exists"
            else
              $VERBOSE_ECHO "Checking $targetPath: gone (deleting)"
              $DRY_RUN_CMD rm $VERBOSE_ARG "$targetPath"

              # Recursively delete empty parent directories.
              targetDir="$(dirname "$relativePath")"
              if [[ "$targetDir" != "." ]] ; then
                pushd "$PROJECT_ROOT" > /dev/null

                # Call rmdir with a relative path excluding $PROJECT_ROOT.
                # Otherwise, it might try to delete $PROJECT_ROOT and exit
                # with a permission error.
                $DRY_RUN_CMD rmdir $VERBOSE_ARG \
                    -p --ignore-fail-on-non-empty \
                    "$targetDir"

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

        if [[ ! -v oldGenPath || "$oldGenPath" != "$newGenPath" ]] ; then
          _i "Creating profile generation %s" $newGenNum
          if [[ -e "$genProfilePath"/manifest.json ]] ; then
            # Remove all packages from "$genProfilePath"
            # `nix profile remove '.*' --profile "$genProfilePath"` was not working, so here is a workaround:
            nix profile list --profile "$genProfilePath" \
              | cut -d ' ' -f 4 \
              | xargs -t $DRY_RUN_CMD nix profile remove $VERBOSE_ARG --profile "$genProfilePath"
            $DRY_RUN_CMD nix profile install $VERBOSE_ARG --profile "$genProfilePath" "$newGenPath"
          else
            $DRY_RUN_CMD nix-env $VERBOSE_ARG --profile "$genProfilePath" --set "$newGenPath"
          fi

          $DRY_RUN_CMD nix-store --realise "$newGenPath" --add-root "$newGenGcPath" > "$DRY_RUN_NULL"
          if [[ -e "$legacyGenGcPath" ]]; then
            $DRY_RUN_CMD rm $VERBOSE_ARG "$legacyGenGcPath"
          fi
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
          sourceArg = escapeShellArg (sourceStorePath v);
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
      "project-manager-files"
      {
        nativeBuildInputs = [pkgs.xorg.lndir];
      }
      (''
          mkdir -p $out

          # Needed in case /nix is a symbolic link.
          realOut="$(realpath -m "$out")"

          function insertFile() {
            local source="$1"
            local relTarget="$2"
            local executable="$3"
            local recursive="$4"
            local persistence="$5"

            ## TOOD: There should be a safer place for this (i.e., if there is a
            ##       real file called `pm-metadata`, we’ll mess it up).
            echo "$relTarget $persistence" >> $realOut/pm-metadata

            # If the target already exists then we have a collision. Note, this
            # should not happen due to the assertion found in the 'files' module.
            # We therefore simply log the conflict and otherwise ignore it, mainly
            # to make the `files-target-config` test work as expected.
            if [[ -e "$realOut/$relTarget" ]]; then
              echo "File conflict for file '$relTarget'" >&2
              return
            fi

            # Figure out the real absolute path to the target.
            local target
            target="$(realpath -m "$realOut/$relTarget")"

            # Target path must be within $PROJECT_ROOT.
            if [[ ! $target == $realOut* ]] ; then
              echo "Error installing file '$relTarget' outside \$PROJECT_ROOT" >&2
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
                  # Don't change file mode if it should match the source.
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
                (sourceStorePath v)
                v.target
                (
                  if v.executable == null
                  then "inherit"
                  else toString v.executable
                )
                (toString v.recursive)
                v.persistence
              ]
            }
          '')
          cfg
        ));
  };
}
