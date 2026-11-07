# Home Assistant Apps von lufi42

Repository mit Apps (Add-ons) für Home Assistant OS und Supervised.

[![Repository zu Home Assistant hinzufügen](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Flufi42%2Fhassio-addons)

Oder von Hand: Einstellungen → Apps → App installieren → Menü oben rechts → Repositories →
`https://github.com/lufi42/hassio-addons` eintragen.

## Apps

App | Beschreibung
--- | ---
[solvis2mqtt](solvis2mqtt/) | Solvis-Heizungsanlagen mit SolvisControl 2 und SolvisRemote (SolvisMax 6 und 7) per MQTT in Home Assistant, mit Auto-Discovery. Verpackt den Server [lufi42/solvis2mqtt](https://github.com/lufi42/solvis2mqtt).

## Entwicklung

Jede App liegt in einem eigenen Ordner mit `config.yaml`, `Dockerfile`, `rootfs/` und Doku. Die Images baut
GitHub Actions mit den Builder-Actions von Home Assistant für `amd64` und `aarch64` und veröffentlicht sie bei
einem Release als Multi-Arch-Image auf `ghcr.io/lufi42/hassio-addon-<app>`; der Release-Tag muss zur `version`
in der `config.yaml` passen (`v1.0.0` ↔ `1.0.0`). Ohne Release lässt sich die App auch aus dem Repository
heraus lokal bauen, dazu den Eintrag `image` in der `config.yaml` auskommentieren.
