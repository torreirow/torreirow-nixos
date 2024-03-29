{ config, pkgs,... }:

{
  environment.systemPackages = with pkgs; [
   awscli2
   aws-mfa
   ssmsh
  ];

}
