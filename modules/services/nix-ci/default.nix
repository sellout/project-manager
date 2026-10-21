## TODO: Ideally this would live in some Nix CI flake, produced via the original
##       codec, which I would imagine is defined by Autodocodec somewhere, but
##       for now, it’s manualy.
{
  config,
  lib,
  self,
  ...
}: let
  cfg = config.services.nix-ci;
in {
  options.services.nix-ci = let
    t = lib.types;
  in {
    ## FIXME: Try to recover my deleted version of this from Time Machine
    enable = lib.mkOption {
      type = t.nullOr t.bool;
      default = null;
      example = false;
      description = ''
        [Nix CI](https://nix-ci.com/) is enabled via
        [GitHub](https://github.com/). This option controls the (optional)
        nix-ci.nix file that it uses for configuration. The default (`null`) is
        to not generate a file at all. If explicitly set to `false`, it will
        generate the file, but set `enable = false` in the file, which
        _disables_ Nix CI, even if it’s enabled via GitHub. This is particularly
        useful if you have Nix CI enabled for your entire org, but want to
        disable it on some repositories.
      '';
    };

    systems = lib.mkOption {
      type = t.nullOr (t.listOf t.str);
      default = null;
      description = ''
        Only build for these systems. By default these are computed based on
        which workers are available for the repository.
      '';
    };

    onlyBuild = lib.mkOption {
      type = t.nullOr (t.listOf t.str);
      default = null;
      description = ''
        Only build these attributes.
      '';
    };

    doNotBuild = lib.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        Exclude these attributes.
      '';
    };

    supportedSystemFeatures = lib.mkOption {
      type = t.nullOr (t.listOf t.str);
      default = ["benchmark" "big-parallel" "kvm" "nixos-test"];
      description = ''
        The system features that Nix CI’s builders provide. Checks that require
        any other feature are added to {option}`services.nix-ci.doNotBuild`.
        `null` means to not exclude any features.

        If a build fails with “missing system features”, Nix’s error lists the
        builder’s “Available features”, which is what belongs here.
      '';
    };

    unbuildableChecks = lib.mkOption {
      type = t.attrsOf t.package;
      readOnly = true;
      internal = true;
      default =
        lib.pm.ci.unbuildable cfg.supportedSystemFeatures
        config.project.checks;
      description = ''
        The checks (for the current system) that Nix CI can’t build.
      '';
    };

    git-ssh-key = lib.mkOption {
      type = t.nullOr (t.attrsOf t.str);
      default = null;
      description = ''
        SSH key to use for [Git](https://git-scm.com/) cloning.

        By default no SSH key is used so Nix will fail to clone private
        dependencies.

        See [the relevant Nix CI
        documentation](https://nix-ci.com/documentation/git-ssh-key) for more.
      '';
    };

    timeout = lib.mkOption {
      type = t.nullOr t.numbers.nonnegative;
      default = null;
      description = ''
        Maximum timeout, in seconds. Note that the actual timeout may depend on
        the workers’ configuration.
      '';
    };

    cache = lib.mkOption {
      type = t.nullOr (t.attrsOf t.str);
      default = null;
      description = ''
        SSH cache configuration.

        In order to push to the cache as well, the repository needs to have an
        `SSH_CACHE_PRIVATE_KEY` secret.
      '';
    };

    cachix = lib.mkOption {
      type = t.nullOr (t.attrsOf t.str);
      default = null;
      description = ''
        [Cachix](https://www.cachix.org/) configuration.

        In order to push to the cache as well, the repository needs to have a
        `CACHIX_AUTH_TOKEN` or `CACHIX_SIGNING_KEY` secret.

        See [the relevant Nix CI
        documentation](https://nix-ci.com/documentation/cachix) for more.
      '';
    };

    allow-import-from-derivation = lib.mkOption {
      type = t.bool;
      default = true;
      example = false;
      description = ''
        Show with `--allow-import-from-derivation`.
      '';
    };

    impure = lib.mkOption {
      type = t.bool;
      default = false;
      example = true;
      description = ''
        Build with `--impure`.
      '';
    };

    build-logs = lib.mkOption {
      type = t.bool;
      default = true;
      example = false;
      description = ''
        Build with `--print-build-logs`.
      '';
    };

    fail-fast = lib.mkOption {
      type = t.bool;
      default = true;
      example = false;
      description = ''
        Cancel the rest of a suite once one job fails.
      '';
    };

    auto-retry = lib.mkOption {
      type = t.bool;
      default = true;
      example = false;
      description = ''
        Automatically retry every individual failed run in a suite once.
      '';
    };

    test = lib.mkOption {
      type = t.attrsOf t.attrs;
      default = {};
      description = ''
        Test configurations.

        See [the relevant Nix CI
        documentation](https://nix-ci.com/documentation/test) for more.
      '';
    };

    deploy = lib.mkOption {
      type = t.attrsOf t.attrs;
      default = {};
      description = ''
        Deploy configurations.

        See [the relevant Nix CI
        documentation](https://nix-ci.com/documentation/deploy) for more.
      '';
    };
  };

  config = lib.mkIf (cfg.enable != null) {
    project.file."nix-ci.nix".text =
      lib.pm.generators.toPretty {multiline = false;}
      ## TODO: Elide the other default values for a smaller/cleaner file.
      (lib.filterAttrs (_: v: v != null)
        ## These configure Project Manager, not Nix CI.
        (removeAttrs cfg ["supportedSystemFeatures" "unbuildableChecks"]));

    services.nix-ci.doNotBuild = lib.concatMap (sys:
      lib.pm.ci.excludedFlakePaths cfg.supportedSystemFeatures self sys
      ++ ["devShells.${sys}.lax-checks"])
    ["x86_64-linux"];
  };
}
