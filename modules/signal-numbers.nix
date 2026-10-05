{ ... }:

# Afzender en ontvanger voor Signal-meldingen via de lokale signal-cli REST API
# (zelfde nummers als HA's signal_maria). Niet geheim, wel persoonsgegevens, dus
# uit de publieke repo. Env-bestand voor EnvironmentFile=:
#   SIGNAL_SENDER=+31…
#   SIGNAL_RECIPIENT=+31…
{
  age.secrets.signal-numbers = {
    file = ../secrets/signal-numbers.age;
    path = "/run/agenix/signal-numbers";
    mode = "0400";
  };
}
