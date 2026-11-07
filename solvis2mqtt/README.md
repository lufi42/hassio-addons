# solvis2mqtt

Solvis-Heizungsanlagen mit **SolvisControl 2** und **SolvisRemote** (SolvisMax 6 und 7) per MQTT in Home Assistant.
Messwerte, Zustände und Sollwerte erscheinen über MQTT Auto-Discovery als Entities, Sollwerte und Betriebsarten
lassen sich setzen. Verwendet den Mosquitto-Broker automatisch.

Verpackt den Server [lufi42/solvis2mqtt](https://github.com/lufi42/solvis2mqtt). Einrichtung und Optionen stehen
in der Dokumentation der App.
