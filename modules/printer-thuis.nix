{ config, pkgs, ... }:

{
  services.printing = {
    enable = true;
    browsing = false;
  };

  hardware.printers = {
    ensurePrinters = [

      {
        name = "Brother-Thuis";
        location = "Thuis";
        description = "Brother DCP-L3550CDW";

        # IPP Everywhere — VAST IP
        deviceUri = "ipp://192.168.2.199/ipp/print";

        model = "everywhere";

        ppdOptions = {
          PageSize = "A4";
          Duplex = "DuplexNoTumble";
          ColorModel = "Gray";
        };
      }

      {
        name = "Brother-Kantoor";
        location = "Kantoortje";
        description = "Brother L8410CDW";

        deviceUri = "ipp://BRW30C9AB2865A2.local/ipp/print";
        model = "everywhere";

        ppdOptions = {
          PageSize = "A4";
          Duplex = "DuplexNoTumble";
          ColorModel = "Gray";
        };
      }
    ];

    ensureDefaultPrinter = "Brother-Thuis";
  };
}

