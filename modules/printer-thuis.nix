# printers.nix
{ config, pkgs, ... }:

{
  # Brother drivers toevoegen aan printing service
  services.printing.drivers = with pkgs; [
    brlaser           # Open source Brother laser driver
    cups-filters      # Nodig voor PDF conversie
    ghostscript       # PDF naar PostScript conversie
  ];

  # Browsing uitschakelen voor snelheid
  # (voorkomt dat CUPS automatisch naar printers zoekt bij elke print)
  services.printing.browsing = false;

  # Hardware printer configuratie
  hardware.printers = {
    ensurePrinters = [
      # Thuisprinter met vast IP (snel en betrouwbaar)
      {
        name = "Brother-Thuis";
        location = "Thuis";
        description = "Brother DCP-L3550CDW (Thuis)";
        deviceUri = "socket://192.168.2.199:9100";
        model = "drv:///brlaser.drv/br3550cdw.ppd";
        ppdOptions = {
          PageSize = "A4";
          Duplex = "DuplexNoTumble";
          ColorModel = "Gray";
        };
      }
      
    ];
    
    # Standaard printer (thuisprinter als default)
    ensureDefaultPrinter = "Brother-Thuis";
  };
}
