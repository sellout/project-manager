{config, ...}: {
  services.flakehub = {
    enable = true;
    ## TODO: Should be inferred.
    name = "sellout/${config.project.name}";
    visibility = "public";
  };
}
