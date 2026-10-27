{
  config,
  lib,
  pkgs,
  pmPkgs,
  self,
  ...
}: let
  cfg = config.programs.vale;
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.programs.vale = {
    enable = lib.mkEnableOption "Vale";

    package = lib.mkPackageOption pkgs "Vale" {
      default = ["vale"];
    };

    coreSettings = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
      default = null;
      description = ''
        The [core settings](https://vale.sh/docs/vale-ini#core-settings) section
        of the .vale.ini file.

        See {var}`config.programs.vale.styles` for some more information about
        defining `Packages`.
      '';
    };

    formatAssociations = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
      default = null;
      description = ''
        The [format
        associations](https://vale.sh/docs/vale-ini#format-associations) section
        of the .vale.ini file.
      '';
    };

    formatSettings = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf (lib.types.attrsOf lib.types.anything));
      default = null;
      description = ''
        The [format-specific
        settings](https://vale.sh/docs/vale-ini#format-specific-settings)
        sections of the .vale.ini file.
      '';
    };

    styles = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = {};
      example = lib.literalExpression ''
        {
          Google = pkgs.valeStyles.google;
          write-good = pkgs.valeStyles.write-good;
        }
      '';
      description = ''
        Style packages for Vale, keyed by style name, each providing
        {file}`share/vale/styles/<name>`, as the packages in `pkgs.valeStyles`
        do. Nix users get these from the store, so `checks.vale` needs no
        network access. For Non-Nix users, the styles here are also added to
        `Packages` in .vale.ini, and can be retrieved via `vale sync`.

        Packages that only appear in `coreSettings.Packages` are still available
        to Nix users, but then `checks.vale` has to run `vale sync`, which makes
        it require import-from-derivation.
      '';
    };

    vocab = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.listOf lib.types.str));
      default = {};
      description = ''
        An attrset with two optional keys, “accept” and “reject”. Each contains
        a list of words that are either accepted or rejected by Vale’s spell
        checker.
      '';
    };

    ## NOTE: Each module that generates files adds them here itself, rather than
    ##       automatically excluding all generated files, because some generated
    ##       files are prose, and those _should_ be checked by Vale.
    excludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        A list of glob patterns to skip when checking Vale compliance.
      '';
    };
  };
  config = lib.mkIf cfg.enable (let
    generateIni =
      cfg.coreSettings
      != null
      || cfg.formatAssociations != null
      || cfg.formatSettings != null
      || cfg.styles != {};

    styles = pkgs.symlinkJoin {
      name = "vale-styles";
      paths = lib.attrValues cfg.styles;
    };

    ## The release asset that `vale sync` would fetch for the same version, if
    ## the style comes from GitHub.
    releaseUrl = name: style: let
      src = style.src or {};
    in
      if src ? owner && src ? repo && src ? rev
      then "https://github.com/${src.owner}/${src.repo}/releases/download/${src.rev}/${name}.zip"
      else null;

    releaseUrls = lib.mapAttrs releaseUrl cfg.styles;

    userPackages = (lib.optionalAttrs (cfg.coreSettings != null) cfg.coreSettings).Packages or null;

    packages =
      lib.optional (userPackages != null) userPackages
      ++ lib.filter (url: url != null) (lib.attrValues releaseUrls);

    ## NOTE: Vale 3 searches `VALE_STYLES_PATH` in addition to the `StylesPath`
    ##       from .vale.ini, so the generated vocabularies are still found. Vale
    ##       2 ignores it, which is why the check copies the styles instead.
    ##
    ## NOTE: This isn’t `vale.withStyles`, because that always wraps the `vale`
    ##       from Nixpkgs (a `callPackage` argument), even when it’s called on
    ##       an override of it, so it would ignore `cfg.package`. It also
    ##       doesn’t exist before Nixpkgs 24.05.
    wrapped =
      if cfg.styles == {}
      then cfg.package
      else
        pkgs.symlinkJoin {
          inherit (cfg.package) meta;

          name = "${cfg.package.name}-with-styles";
          nativeBuildInputs = [pkgs.makeWrapper];
          paths = [cfg.package];
          postBuild = ''
            wrapProgram "$out/bin/vale" \
              --set VALE_STYLES_PATH "${styles}/share/vale/styles"
          '';
        };

    ## This is a bit complicated, because if we’re _not_ generating a .vale.ini,
    ## then this needs to have the default "styles" value, but if we are, then
    ## we want to default to ".local/share/vale".
    actualCoreSettings =
      (
        if cfg.coreSettings == null
        then {StylesPath = "styles";}
        else {StylesPath = "${config.xdg.dataDir}/vale";} // cfg.coreSettings
      )
      // lib.optionalAttrs (packages != []) {
        Packages = lib.concatStringsSep ", " packages;
      };

    stylesPath = actualCoreSettings.StylesPath;

    lint = ''
      find . -type f \
        ${
        lib.concatStringsSep " " (map (v: "-not -path '${v}' ")
          (cfg.excludes
            ++ [
              "./${config.xdg.cacheDir}/*"
              ## `StylesPath` holds the styles, so we tell `find` to skip
              ## those.
              "./${stylesPath}/*"
            ]))
      } \
        -exec vale {} +
    '';

    checkInputs = [
      pkgs.vale
      ## TODO: Conditinalize these dependencies based on whether the user wants
      ##       to lint these files types.
      pkgs.asciidoctor
      pkgs.libxslt
    ];

    copySource = ''
      cp -R "$src/." build
      chmod -R +w build
      cd build || exit
    '';
  in {
    warnings =
      lib.optional (userPackages != null) ''
        `programs.vale.coreSettings.Packages` is set, so `checks.vale` has to
        run `vale sync`, which needs import-from-derivation. Move the styles to
        `programs.vale.styles` to avoid that.
      ''
      ++ lib.mapAttrsToList (name: _: ''
        The Vale style “${name}” doesn’t come from GitHub, so it can’t be added
        to `Packages`, and only Nix users will have it.
      '') (lib.filterAttrs (_: url: url == null) releaseUrls);

    project = {
      file =
        {
          ".vale.ini" = lib.mkIf generateIni {
            ## TODO: Should be able to make this `"store"`.
            # minimum-persistence = "worktree";
            onChange = lib.mkIf (userPackages != null) ''
              export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              ${cfg.package}/bin/vale sync
            '';
            text = lib.pm.generators.toINIWithGlobalSection {} {
              globalSection = actualCoreSettings;
              sections =
                (
                  if cfg.formatAssociations == null
                  then {}
                  else {formats = cfg.formatAssociations;}
                )
                // cfg.formatSettings or {};
            };
          };
        }
        // lib.concatMapAttrs (k: v: {
          # Need to generate files for all Vale versions in supported Nixpkgs
          # versions until we test them in separate environments
          # (see sellout/project-manager#69)
          # for Vale <3.0.0
          "${stylesPath}/Vocab/${k}/accept.txt" = lib.mkIf (v ? accept) {
            # minimum-persistence = "worktree";
            text = lib.concatLines v.accept;
          };
          "${stylesPath}/Vocab/${k}/reject.txt" = lib.mkIf (v ? reject) {
            # minimum-persistence = "worktree";
            text = lib.concatLines v.reject;
          };
          # for Vale >=3.0.0
          "${stylesPath}/config/vocabularies/${k}/accept.txt" = lib.mkIf (v ? accept) {
            # minimum-persistence = "worktree";
            text = lib.concatLines v.accept;
          };
          "${stylesPath}/config/vocabularies/${k}/reject.txt" = lib.mkIf (v ? reject) {
            # minimum-persistence = "worktree";
            text = lib.concatLines v.reject;
          };
        })
        cfg.vocab;

      devPackages = [wrapped];

      ## When there are style packages defined in .vale.ini, we need to use IFD.
      ## Without that, the derivation is puer.
      checks.vale =
        if userPackages == null
        then
          pmPkgs.runStrictCommand "vale" {
            nativeBuildInputs = checkInputs;
            src = self;
          } ''
            ${copySource}
            ## WAIT: Once we no longer support Nixpkgs <24.05, we can remove
            ##       this in favor of `VALE_STYLES_PATH`.
            ${lib.optionalString (cfg.styles != {}) ''
              mkdir -p "${stylesPath}"
              ln -s "${styles}/share/vale/styles/"* "${stylesPath}/"
            ''}
            ${lint}
            touch "$out"
          ''
        else
          pmPkgs.runEmptyCommand "vale" {
            nativeBuildInputs = [pkgs.cacert] ++ checkInputs;
            src = self;
          } ''
            ${copySource}
            vale sync
            ${lint}
          '';
    };

    programs.vale.excludes = let
      ini = config.project.file.".vale.ini";
    in
      lib.optional (generateIni && ini.in-worktree) "./${ini.target}";

    programs.git.ignores =
      if actualCoreSettings ? Vocab
      ## See https://vale.sh/docs/topics/packages/#packages-and-vcs for an
      ## explanation of this convoluted ignoring.
      then [
        # Need to support all Vale versions in supported Nixpkgs versions until
        # we test them in separate environments (see sellout/project-manager#69)
        "/${stylesPath}/*"
        "!/${stylesPath}/config/"
        "/${stylesPath}/config/*"
        "!/${stylesPath}/config/vocabularies/"
        "/${stylesPath}/config/vocabularies/*"
        "!/${stylesPath}/config/vocabularies/${actualCoreSettings.Vocab}/"
        "!/${stylesPath}/Vocab/"
        "/${stylesPath}/Vocab/*"
        "!/${stylesPath}/Vocab/${actualCoreSettings.Vocab}/"
      ]
      else ["/${stylesPath}/"];
  });
}
