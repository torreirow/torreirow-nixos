{ config, pkgs,... }:

{
  environment.systemPackages = with pkgs; [
   fprintd
 ];

services.fprintd.enable = true;

services.fprintd.tod.enable = true;

services.fprintd.tod.driver = pkgs.libfprint-2-tod1-vfs0090; (If the vfs0090 Driver does not work, use the following driver)

#services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix; (On my device it only worked with this driver)

}
