# solvis2mqtt

Bindet eine Solvis-Heizungsanlage mit **SolvisControl 2** und **SolvisRemote** (SolvisMax 6 und 7) per MQTT an
Home Assistant an. Messwerte, Zustände und Sollwerte erscheinen über MQTT Auto-Discovery als Entities, verteilt auf
Geräte nach dem Solvis-Anlagenschema (Speicher, Solaranlage, Warmwasser, Heizkreise, Wärmeerzeuger). Sollwerte und
Betriebsarten lassen sich aus Home Assistant setzen; der Server bedient dazu die Web-Oberfläche der SolvisRemote.

Die App verpackt den Server [solvis2mqtt](https://github.com/lufi42/solvis2mqtt). Dort stehen die ausführliche
Beschreibung der Topics, Kanäle, Server-Befehle und bekannten Schwächen. Für Anlagen mit SolvisControl 3 oder einer
SC2 ab Firmware MA205 ist Modbus der bessere Weg, etwa mit
[hass_solvis_control](https://github.com/LarsK1/hass_solvis_control).

## Voraussetzungen

* SolvisRemote im lokalen Netz, erreichbar von Home Assistant aus (Web-Oberfläche mit Benutzer und Passwort).
* Ein MQTT-Broker: am einfachsten die App **Mosquitto broker**, die die App automatisch verwendet. Ein eigener
  Broker lässt sich in den Optionen eintragen.
* Die **MQTT-Integration** in Home Assistant, verbunden mit diesem Broker (Einstellungen → Geräte & Dienste).
* **Nur ein Server pro Anlage.** Läuft solvis2mqtt bereits anderswo (Docker, LXC), diesen vorher stoppen. Zwei
  Server, die gleichzeitig die SolvisRemote bedienen, stören sich gegenseitig.

## Installation

1. Repository hinzufügen: Einstellungen → Apps → App installieren → Menü oben rechts → Repositories →
   `https://github.com/lufi42/hassio-addons`.
2. App **solvis2mqtt** installieren.
3. Unter **Konfiguration** mindestens den Host der SolvisRemote, Benutzer und Passwort sowie Anlagentyp, Hauptheizung
   und Anzahl der Heizkreise eintragen (siehe unten), speichern.
4. App starten und das **Log** beobachten. Beim ersten Start lernt der Server die Bildschirme der SolvisControl
   (**Learning**, etwa zehn Minuten). In dieser Zeit liefert er keine Messwerte, und die SolvisRemote darf nicht
   bedient werden, weder am Touchscreen noch im Browser. Danach legt die MQTT-Integration die Entities an.

Nach einem Update der App lernt der Server bei Bedarf selbst neu; ob eine Version das erfordert, steht im Changelog.

## Optionen

Option | Bedeutung
--- | ---
`solvis_host` | Hostname oder IP-Adresse der SolvisRemote, optional mit Port (`192.168.1.50`, `solvis.local:8080`).
`solvis_user`, `solvis_password` | Anmeldung an der Web-Oberfläche der SolvisRemote. Das Passwort steht nur verschlüsselt in der erzeugten `base.xml`.
`unit_id` | Name der Anlage in Topics und Entity-Ids (`sensor.solvis_<unit_id>_…`). Buchstaben, Ziffern, Unterstrich.
`unit_type` | `SolvisMax6`, `SolvisMax6PurSolo` oder `SolvisMax7`.
`main_heating` | `OelBW` (Öl-Brennwert), `OelNT`, `Gas`, `Fern`, `WaermeP`, `Extern` oder `Pellet` (SolvisLino).
`heating_circuits` | Anzahl der Heizkreise, 1 bis 3.
`extensions` | Liste: `OhneRaumfuehler_HK1`, `OhneRaumfuehler_HK2`, `OhneRaumfuehler_HK3` (Heizkreis ohne Raumfühler), `Festbrennstoff`, `SolarOstWest`, `Zaehlfunktion2Screens`.
`remote_firmware_old` | Nur bei SolvisRemote-Firmware älter als 1714SP4110-2_21_02A.
`gui_access` | Schreibzugriff über den Touchscreen (Sollwerte, Betriebsarten). Aus: der Server liest nur.
`clock_tuning` | Stellt die Uhr der SolvisControl nach der Systemzeit von Home Assistant.
`admin` | Liest die Installateur-Einstellungen (Gerät „Installateur“) und schaltet Installateur-Modus und Brennersperre frei. Nur mit Bedacht einschalten.
`mqtt_host`, `mqtt_port`, `mqtt_user`, `mqtt_password` | Nur bei eigenem Broker. Leer: Mosquitto-App über den Supervisor.
`topic_prefix` | Erstes Element aller Topics (`<topic_prefix>/HomeAssistant/<unit_id>/…`) und MQTT-Client-Id. Buchstaben und Ziffern.
`discovery_prefix` | Discovery-Prefix der MQTT-Integration, normalerweise `homeassistant`.
`time_zone` | Zeitzone der Anlage; Standard ist die von Home Assistant.
`java_heap_mb` | Speicher für den Server (Standard 384 MB, das Learning braucht etwa 300 MB).

Die übrigen Einstellungen der `base.xml` (Messintervalle, Features wie `UpdateAfterUserAccess`, Kanaloptionen)
setzt die App auf bewährte Werte. Wer mehr braucht, verwendet eine eigene `base.xml` (nächster Abschnitt).

## Eigene base.xml und Overrides

Im Konfigurationsverzeichnis der App (Freigabe `addon_configs`, Ordner `…_solvis2mqtt`, erreichbar z. B. mit der
App Samba share oder dem File editor) werden beim Start folgende Dateien berücksichtigt:

Datei | Wirkung
--- | ---
`base.xml` | Ersetzt die aus den Optionen erzeugte `base.xml` vollständig. Die Optionen zu Anlage und MQTT werden dann ignoriert. Pflicht: `writablePathLinux="/data"`. Passwörter verschlüsselt eintragen (siehe unten).
`ha-labels.properties`, `ha-groups.properties` | Eigene Namen und Geräte-Zuordnung für Home Assistant, Format wie im Server-Repo.
`tinylog.properties` | Eigene Log-Konfiguration.

Passwörter für eine eigene `base.xml` verschlüsselt die App im Terminal (App „Terminal & SSH“ oder „Advanced SSH“):

```sh
docker exec -it addon_<id>_solvis2mqtt java -jar /app/solvis2mqtt.jar --string-to-crypt=geheim
```

Das Datenverzeichnis `/data/SolvisServerData` (gelernte Bilder, Backups, Logs, Rückstellungsdateien) ist Teil der
Home-Assistant-Backups. Die erzeugte `base.xml` wird bei jedem Start neu geschrieben.

## Log

Der Reiter **Log** zeigt das Serverlog (Stufe Info). Die Logdateien liegen zusätzlich in
`/data/SolvisServerData/solvis-tiny.log.0` und `solvis-error.log.0`.

## Bedienung aus Home Assistant

Entities, Server-Befehle (`<topic_prefix>/HomeAssistant/<unit_id>/server/cmnd`, z. B. `GUI_COMMANDS_DISABLE`,
`INSTALLER_ENABLE`, `BURNER_LOCK_ENABLE:120`), Schreibstatus, Störungsdetails, Installateur-Modus und Brennersperre
sind im [README des Servers](https://github.com/lufi42/solvis2mqtt#readme) beschrieben.

## Bekannte Einschränkungen

* Beim Stoppen setzt der Server Werte zurück, die eine laufende GUI-Sequenz verstellt hat (bis zu 50 s). Beendet der
  Supervisor den Container vorher, holt der Server das beim nächsten Start nach.
* Keine Web-Oberfläche (kein Ingress); die Anlage wird über die Entities bedient.
* Nur eine Unit je App-Instanz.

## Hilfe

* Fragen zur App (Optionen, Start, Log): [Issues im App-Repository](https://github.com/lufi42/hassio-addons/issues).
* Fehler des Servers (Kanäle, Learning, Schreibzugriffe): [Issues bei solvis2mqtt](https://github.com/lufi42/solvis2mqtt/issues).

Lizenz: MIT.
