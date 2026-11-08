# Changelog

## 1.0.1

Server unverändert 1.0.0. Erkenntnisse aus dem ersten Produktivumzug (Container → App).

* Umzug: `measurements.xml`, `graficData.xml` und `LearnedImages/` aus dem Konfigurationsverzeichnis der App werden
  beim Start einmalig nach `/data/SolvisServerData` übernommen. Ohne `measurements.xml` starten die berechneten
  Zähler (Brennerstarts, Laufzeiten) bei 0, und Home Assistant bucht einen Zählerreset in der Langzeitstatistik.
* Optionen `solvis_host`, `solvis_user`, `solvis_password` dürfen leer bleiben, wenn eine eigene `base.xml`
  verwendet wird (bisher verlangte das Schema einen gültigen Host).
* Doku: Abschnitt „Umzug von einer bestehenden Installation“, Hinweis zum Zugriff auf `addon_configs`
  (die App „Terminal & SSH“ sieht den Ordner nicht), Host-Pfade unter HAOS.

## 1.0.0

Erste Version, Server solvis2mqtt 1.0.0.

* base.xml aus den App-Optionen (Anlage, Features, MQTT), MQTT-Broker automatisch von der Mosquitto-App.
* Eigene `base.xml`, `ha-labels.properties`, `ha-groups.properties` und `tinylog.properties` aus dem
  Konfigurationsverzeichnis der App.
* Serverlog im Log-Reiter, Datenverzeichnis in den Home-Assistant-Backups.
* Beim ersten Start lernt der Server die Bildschirme der SolvisControl (etwa zehn Minuten, SolvisRemote nicht
  bedienen).
