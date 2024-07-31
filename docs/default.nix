{
  pkgs,
  # Note, this should be "the standard library" + PM extensions.
  lib ? import ../modules/lib/stdlib-extended.nix pkgs.lib,
  self,
  release,
  isReleaseBranch,
}: let
  # Recursively replace each derivation in the given attribute set
  # with the same derivation but with the `outPath` attribute set to
  # the string `"\${pkgs.attribute.path}"`. This allows the
  # documentation to refer to derivations through their values without
  # establishing an actual dependency on the derivation output.
  #
  # This is not perfect, but it seems to cover a vast majority of use
  # cases.
  #
  # Caveat: even if the package is reached by a different means, the
  # path above will be shown and not e.g.
  # `${config.services.foo.package}`.
  scrubDerivations = prefixPath: attrs: let
    scrubDerivation = name: value: let
      pkgAttrName = prefixPath + "." + name;
    in
      if lib.isAttrs value
      then
        scrubDerivations pkgAttrName value
        // lib.optionalAttrs (lib.isDerivation value) {
          outPath = "\${${pkgAttrName}}";
        }
      else value;
  in
    lib.mapAttrs scrubDerivation attrs;

  # Make sure the used package is scrubbed to avoid actually
  # instantiating derivations.
  scrubbedPkgsModule = {
    imports = [
      {
        _module.args = {
          pkgs = lib.mkForce (scrubDerivations "pkgs" pkgs);
          pkgs_i686 = lib.mkForce {};
        };
      }
    ];
  };

  dontCheckDefinitions = {_module.check = false;};

  gitHubDeclaration = user: repo: subpath: let
    urlRef =
      if isReleaseBranch
      then "release-${release}"
      else "master";
  in {
    url = "https://github.com/${user}/${repo}/blob/${urlRef}/${subpath}";
    name = "<${repo}/${subpath}>";
  };

  pmPath = toString ./..;

  buildOptionsDocs = args @ {
    modules,
    includeModuleSystemOptions ? true,
    ...
  }: let
    options =
      (lib.evalModules {
        inherit modules;
        class = "projectManager";
      })
      .options;
  in
    pkgs.buildPackages.nixosOptionsDoc ({
        options =
          if includeModuleSystemOptions
          then options
          else builtins.removeAttrs options ["_module"];
        transformOptions = opt:
          opt
          // {
            # Clean up declaration sites to not refer to the Project Manager
            # source tree.
            declarations = map (decl:
              if lib.hasPrefix pmPath (toString decl)
              then
                gitHubDeclaration "nix-community" "project-manager"
                (lib.removePrefix "/" (lib.removePrefix pmPath (toString decl)))
              else if decl == "lib/modules.nix"
              then
                # TODO: handle this in a better way (may require upstream
                # changes to nixpkgs)
                gitHubDeclaration "NixOS" "nixpkgs" decl
              else decl)
            opt.declarations;
          };
      }
      // builtins.removeAttrs args ["modules" "includeModuleSystemOptions"]);

  pmOptionsDocs = buildOptionsDocs {
    modules =
      import ../modules/all-modules.nix {
        inherit lib pkgs;
        check = false;
        modules = builtins.attrValues self.projectModules;
      }
      ++ [scrubbedPkgsModule];
    variablelistId = "project-manager-options";
  };

  release-config = import ../release.nix;
  revision = "release-${release-config.release}";
  # Generate the `man project-configuration.nix` package
  project-configuration-manual =
    pkgs.runCommand "project-configuration-reference-manpage" {
      nativeBuildInputs = [pkgs.buildPackages.installShellFiles pkgs.nixos-render-docs];
      allowedReferences = ["out"];
    } ''
      # Generate manpages.
      mkdir -p $out/share/man/man5
      mkdir -p $out/share/man/man1
      nixos-render-docs -j $NIX_BUILD_CORES options manpage \
        --revision ${revision} \
        --header ${./project-configuration-nix-header.5} \
        --footer ${./project-configuration-nix-footer.5} \
        ${pmOptionsDocs.optionsJSON}/share/doc/nixos/options.json \
        $out/share/man/man5/project-configuration.nix.5
      cp ${./project-manager.1} $out/share/man/man1/project-manager.1
    '';
  # Generate the HTML manual pages
  project-manager-manual = pkgs.callPackage ./project-manager-manual.nix {
    project-manager-options = {
      project-manager = pmOptionsDocs.optionsJSON;
    };
    inherit revision;
  };
  html = project-manager-manual;
  htmlOpenTool = pkgs.callPackage ./html-open-tool.nix {} {inherit html;};
in {
  options = {
    # TODO: Use `pmOptionsDocs.optionsJSON` directly once upstream
    # `nixosOptionsDoc` is more customizable.
    json =
      pkgs.runCommand "options.json" {
        meta.description = "List of Project Manager options in JSON format";
      } ''
        mkdir -p $out/{share/doc,nix-support}
        cp -a ${pmOptionsDocs.optionsJSON}/share/doc/nixos $out/share/doc/project-manager
        substitute \
          ${pmOptionsDocs.optionsJSON}/nix-support/hydra-build-products \
          $out/nix-support/hydra-build-products \
          --replace \
            '${pmOptionsDocs.optionsJSON}/share/doc/nixos' \
            "$out/share/doc/project-manager"
      '';
  };

  manPages = project-configuration-manual;

  manual = {inherit html htmlOpenTool;};

  # Unstable, mainly for CI.
  jsonModuleMaintainers = pkgs.writeText "pm-module-maintainers.json" (let
    result = lib.evalModules {
      modules =
        import ../modules/all-modules.nix {
          inherit lib pkgs;
          check = false;
          modules = builtins.attrValues self.projectModules;
        }
        ++ [scrubbedPkgsModule];
      class = "projectManager";
    };
  in
    builtins.toJSON result.config.meta.maintainers);
}
