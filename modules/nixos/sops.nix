# configuration.nix

{inputs, config, ... }:

{
  imports =
    [
      inputs.sops-nix.nixosModules.sops
    ];

  sops.defaultSopsFile = ../../artifacts/sops/secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  
  sops.age.keyFile = "../../artifacts/sops/age/keys.txt";

  sops.secrets.cmu-pass = { 
    owner = config.users.users.maxlang.name;
  };

}