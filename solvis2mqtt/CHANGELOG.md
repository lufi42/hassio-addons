# Changelog

## 1.0.0

Erste Version, Server solvis2mqtt 1.0.0.

* base.xml aus den App-Optionen (Anlage, Features, MQTT), MQTT-Broker automatisch von der Mosquitto-App.
* Eigene `base.xml`, `ha-labels.properties`, `ha-groups.properties` und `tinylog.properties` aus dem
  Konfigurationsverzeichnis der App.
* Serverlog im Log-Reiter, Datenverzeichnis in den Home-Assistant-Backups.
* Beim ersten Start lernt der Server die Bildschirme der SolvisControl (etwa zehn Minuten, SolvisRemote nicht
  bedienen).
