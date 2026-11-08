#!/bin/sh
# solvis2mqtt Home Assistant app: builds base.xml from the app options and starts the server.
#
# - /data/options.json      options validated by the Supervisor (schema in config.yaml)
# - /config/base.xml        optional: own base.xml, used instead of the generated one
#                           (must have writablePathLinux="/data")
# - /config/ha-labels.properties, ha-groups.properties, tinylog.properties
# - /config/measurements.xml, graficData.xml, LearnedImages/: moved once into /data/SolvisServerData
#                           optional overrides, copied into /data/SolvisServerData
# - /data/SolvisServerData  learned images, backups, logs (persistent, in HA backups)
#
# The directories can be overridden by environment variables for tests outside Home Assistant.
set -eu

OPTIONS="${OPTIONS_JSON:-/data/options.json}"
DATA="${DATA_DIR:-/data}"
CONFIG="${CONFIG_DIR:-/config}"
APP="${APP_DIR:-/app}"
JAR="$APP/solvis2mqtt.jar"
BASE_XML="$DATA/base.xml"
SERVER_DATA="$DATA/SolvisServerData"

log() { echo "[solvis2mqtt] $*"; }
die() { echo "[solvis2mqtt] ERROR: $*" >&2; exit 1; }

# option as string ("" if missing or null)
opt() { jq -r --arg k "$1" '.[$k] // empty' "$OPTIONS"; }
# option as true/false
optbool() { jq -r --arg k "$1" 'if .[$k] == true then "true" else "false" end' "$OPTIONS"; }
# escape for an XML attribute value
xml() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }
# encrypted form of a password for base.xml
crypt() { java -jar "$JAR" --string-to-crypt="$1" | tr -d '\r' | tail -n 1; }

[ -f "$OPTIONS" ] || die "$OPTIONS not found"
[ -f "$JAR" ] || die "$JAR not found"
mkdir -p "$SERVER_DATA"

HEAP=$(opt java_heap_mb)
: "${HEAP:=384}"

# --- overrides from the app config directory ---------------------------------------
for f in ha-labels.properties ha-groups.properties tinylog.properties; do
	if [ -f "$CONFIG/$f" ]; then
		cp "$CONFIG/$f" "$SERVER_DATA/$f"
		log "using $f from $CONFIG"
	fi
done

# --- one-time import of server data from the app config directory (migration) ---------
# measurements.xml (counter values; without it X01/X02/X10 start at 0 and Home Assistant books a
# counter reset), graficData.xml and LearnedImages/ (skip the learning). Moved into
# /data/SolvisServerData the first time they are found; an existing file there is kept.
for f in measurements.xml graficData.xml LearnedImages; do
	if [ -e "$CONFIG/$f" ]; then
		if [ -e "$SERVER_DATA/$f" ]; then
			log "import of $f skipped: already present in $SERVER_DATA (delete it there to replace it)"
		else
			cp -r "$CONFIG/$f" "$SERVER_DATA/$f" && rm -rf "$CONFIG/$f"
			log "imported $f from $CONFIG into $SERVER_DATA"
		fi
	fi
done

# Log configuration: the server's default writes only errors to the console. In the app the
# console is the Log tab, so info goes there as well (plus the rolling files in SolvisServerData).
if [ ! -f "$SERVER_DATA/tinylog.properties" ]; then
	cat > "$SERVER_DATA/tinylog.properties" <<'EOF'
writer1				= console
writer1.level		= info
writer1.format		= {date: HH:mm:ss,SSS}|{level}|{message}
writer1.tag			= -

writer2				= rolling file
writer2.level		= info
writer2.file		= solvis-tiny.log.{count}
writer2.format		= [{date: yyyy-MM-dd HH:mm:ss,SSS}] {level} {message}
writer2.append		= true
writer2.policies	= size: 1mb
writer2.backups		= 5

writer3				= console
writer3.level		= info
writer3.format		= {date: HH:mm:ss,SSS}|LEARN|{message}
writer3.tag			= LEARN

writer4				= rolling file
writer4.level		= error
writer4.file		= solvis-error.log.{count}
writer4.format		= [{date: yyyy-MM-dd HH:mm:ss,SSS}] {level} {message}
writer4.append		= true
writer4.policies	= size: 1mb
writer4.backups		= 2

writingthread		= false
autoshutdown		= false
EOF
fi

# --- base.xml -------------------------------------------------------------------------
if [ -f "$CONFIG/base.xml" ]; then
	cp "$CONFIG/base.xml" "$BASE_XML"
	log "using base.xml from $CONFIG (options for the unit and MQTT are ignored)"
else
	SOLVIS_HOST=$(opt solvis_host)
	SOLVIS_USER=$(opt solvis_user)
	SOLVIS_PASSWORD=$(opt solvis_password)
	[ -n "$SOLVIS_HOST" ] || die "option solvis_host is empty: host name or IP address of the SolvisRemote"
	[ -n "$SOLVIS_USER" ] || die "option solvis_user is empty"
	[ -n "$SOLVIS_PASSWORD" ] || die "option solvis_password is empty"

	# MQTT: options first, otherwise the broker registered at the Supervisor (Mosquitto app)
	MQTT_HOST=$(opt mqtt_host)
	MQTT_PORT=$(opt mqtt_port)
	MQTT_USER=$(opt mqtt_user)
	MQTT_PASSWORD=$(opt mqtt_password)
	if [ -n "$MQTT_HOST" ]; then
		log "MQTT broker from the options: $MQTT_HOST"
	elif [ -n "${SUPERVISOR_TOKEN:-}" ]; then
		SVC=$(curl -sf -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/services/mqtt || true)
		if [ -n "$SVC" ] && [ "$(printf '%s' "$SVC" | jq -r '.result')" = "ok" ]; then
			MQTT_HOST=$(printf '%s' "$SVC" | jq -r '.data.host // empty')
			MQTT_PORT=$(printf '%s' "$SVC" | jq -r '.data.port // empty')
			MQTT_USER=$(printf '%s' "$SVC" | jq -r '.data.username // empty')
			MQTT_PASSWORD=$(printf '%s' "$SVC" | jq -r '.data.password // empty')
			log "MQTT broker from the Supervisor: $MQTT_HOST:$MQTT_PORT (user $MQTT_USER)"
		fi
	fi
	[ -n "$MQTT_HOST" ] || die "no MQTT broker: install and start the Mosquitto broker app, or set mqtt_host in the options"
	: "${MQTT_PORT:=1883}"

	TIME_ZONE=$(opt time_zone)
	: "${TIME_ZONE:=${TZ:-Europe/Berlin}}"
	UNIT_ID=$(opt unit_id)
	UNIT_TYPE=$(opt unit_type)
	MAIN_HEATING=$(opt main_heating)
	HEATING_CIRCUITS=$(opt heating_circuits)
	FW_OLD=$(optbool remote_firmware_old)
	GUI_ACCESS=$(optbool gui_access)
	CLOCK_TUNING=$(optbool clock_tuning)
	ADMIN=$(optbool admin)
	TOPIC_PREFIX=$(opt topic_prefix)
	DISCOVERY_PREFIX=$(opt discovery_prefix)
	: "${UNIT_ID:=SolvisMax}"
	: "${TOPIC_PREFIX:=solvis2mqtt}"
	: "${DISCOVERY_PREFIX:=homeassistant}"

	EXTENSIONS=$(jq -r '(.extensions // []) | unique | .[] | "\t\t\t\t<tns:Extension id=\"" + . + "\" />"' "$OPTIONS")
	# RF1 (room sensor of heating circuit 1) does not exist with OhneRaumfuehler_HK1
	if jq -e '(.extensions // []) | index("OhneRaumfuehler_HK1")' "$OPTIONS" >/dev/null; then
		RF1_OPTION=""
	else
		RF1_OPTION='				<tns:Channel id="RF1.Raumfuehler_HK1" powerOnDelay_s="1500" />'
	fi

	SOLVIS_CRYPT=$(crypt "$SOLVIS_PASSWORD")
	[ -n "$SOLVIS_CRYPT" ] || die "encrypting the Solvis password failed"
	MQTT_AUTH=""
	if [ -n "$MQTT_USER" ]; then
		MQTT_CRYPT=$(crypt "$MQTT_PASSWORD")
		[ -n "$MQTT_CRYPT" ] || die "encrypting the MQTT password failed"
		MQTT_AUTH="userName=\"$(xml "$MQTT_USER")\" passwordCrypt=\"$MQTT_CRYPT\""
	fi

	umask 077
	cat > "$BASE_XML" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!-- generated by the solvis2mqtt app from the app options; edits are lost at the next start.
     For an own configuration put a base.xml into the app config directory. -->
<tns:BaseData xmlns:tns="http://www.example.org/control"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://www.example.org/control base.xsd ">
	<tns:ExecutionData timeZone="$(xml "$TIME_ZONE")"
		writablePathLinux="$DATA"
		writeablePathWindows="C:\\solvis2mqtt"
		echoInhibitTime_ms="2000" />
	<tns:Units>
		<tns:Unit id="$(xml "$UNIT_ID")" type="$(xml "$UNIT_TYPE")"
			mainHeating="$(xml "$MAIN_HEATING")" heatingCircuits="$HEATING_CIRCUITS" fwLth2_21_02A="$FW_OLD"
			account="$(xml "$SOLVIS_USER")" passwordCrypt="$SOLVIS_CRYPT" url="$(xml "$SOLVIS_HOST")"
			defaultAverageCount="12" measurementHysteresisFactor="4"
			measurementsInterval_s="10" measurementsIntervalFast_s="5"
			forceUpdateAfterFastChangingIntervals="3"
			forcedUpdateInterval_ms="3600000" doubleUpdateInterval_ms="10000"
			bufferedInterval_ms="60000" watchDogTime_ms="30000"
			releaseBlockingAfterUserAccess_ms="300000"
			releaseBlockingAfterServiceAccess_ms="3600000"
			reheatingNotRequiredActiveTime_ms="30000"
			delayAfterSwitchingOnEnable="true"
			resetErrorDelayTime_ms="300000"
			installerModeTime_min="15"
			burnerLockTime_min="120"
			ignoredFrameThicknesScreenSaver="3">
			<tns:Extensions>
$EXTENSIONS
			</tns:Extensions>
			<tns:Features>
				<tns:Feature id="InteractiveGUIAccess" value="$GUI_ACCESS" />
				<tns:Feature id="ClockTuning" value="$CLOCK_TUNING" />
				<tns:Feature id="EquipmentTimeSynchronisation" value="true" />
				<tns:Feature id="UpdateAfterUserAccess" value="true" />
				<tns:Feature id="DetectServiceAccess" value="false" />
				<tns:Feature id="PowerOffIsServiceAccess" value="true" />
				<tns:Feature id="ClearErrorMessage" value="false" />
				<tns:Feature id="Admin" value="$ADMIN" />
				<tns:Feature id="Min_Vorlauf_Temp" value="false" />
				<tns:Feature id="BetriebsartVT_HK" value="false" />
				<tns:Feature id="WW_Pumpe_Min_Laufzeit" value="false" />
				<tns:Feature id="EndOfUserInterventionDetectionThroughScreenSaver" value="false" />
			</tns:Features>
			<tns:IgnoredChannels>
			</tns:IgnoredChannels>
			<tns:ChannelAssignments>
			</tns:ChannelAssignments>
			<tns:Durations>
			</tns:Durations>
			<tns:ChannelOptions>
				<tns:Channel id="S03.Speicherreferenztemperatur" powerOnDelay_s="600" />
				<tns:Channel id="S04.Heizungspuffertemperatur_oben" powerOnDelay_s="600" />
				<tns:Channel id="S09.Heizungspuffertemperatur_unten" powerOnDelay_s="600" />
				<tns:Channel id="S10.Aussentemperatur" powerOnDelay_s="900" />
$RF1_OPTION
			</tns:ChannelOptions>
		</tns:Unit>
	</tns:Units>
	<tns:Mqtt enable="true" brokerUrl="$(xml "$MQTT_HOST")" port="$MQTT_PORT"
		$MQTT_AUTH
		subscribeQoS="1" publishQoS="1" idPrefix="$(xml "$TOPIC_PREFIX")"
		topicPrefix="$(xml "$TOPIC_PREFIX")" smartHomeId="HomeAssistant"
		haDiscoveryPrefix="$(xml "$DISCOVERY_PREFIX")" />
</tns:BaseData>
EOF
	log "base.xml generated: unit $UNIT_ID ($UNIT_TYPE, $MAIN_HEATING, $HEATING_CIRCUITS heating circuit(s)) at $SOLVIS_HOST, time zone $TIME_ZONE"
fi

if [ "${GENERATE_ONLY:-}" = "1" ]; then
	log "GENERATE_ONLY set, not starting the server"
	exit 0
fi

log "starting solvis2mqtt (heap ${HEAP} MB); the full log is also in $SERVER_DATA/solvis-tiny.log.0"
# shellcheck disable=SC2086
exec java -Xmx"${HEAP}"m -Djava.awt.headless=true ${JAVA_EXTRA_OPTS:-} -jar "$JAR" --base-xml="$BASE_XML" "$@"
