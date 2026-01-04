#!/bin/sh

. /usr/lib/libmodcgi.sh
[ -r /etc/options.cfg ] && . /etc/options.cfg

# Auto-detect default storage for help text
autodetect_storage_hint() {
	[ -r /mod/etc/conf/mod.cfg ] && . /mod/etc/conf/mod.cfg
	local stor_prefix="${MOD_STOR_PREFIX:-uStor}"
	if [ -d "/var/media/ftp/${stor_prefix}01" ]; then
		echo "/var/media/ftp/${stor_prefix}01/rtorrent"
	elif [ -d /var/media/ftp/* 2>/dev/null ]; then
		echo "$(find /var/media/ftp -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n1)/rtorrent"
	else
		echo "/var/tmp/rtorrent"
	fi
}
AUTO_STORAGE="$(autodetect_storage_hint)"

# Select/check helpers
select "$RTORRENT_LOGLEVEL" error:logerror warn:logwarn info:loginfo debug:logdebug "*":logerror
select "$RTORRENT_DHT" off:dhtoff auto:dhtauto on:dhton disable:dhtdisable "*":dhtauto
select "$RTORRENT_SCGI_MODE" socket:scgimode_socket port:scgimode_port "*":scgimode_socket
check "$RTORRENT_PEX" yes:usepex
check "$RTORRENT_DAEMON_MODE" yes:daemonmode
check "$RTORRENT_CHECKHASH" yes:checkhash
check "$RTORRENT_PREALLOCATE" yes:preallocate

# ruTorrent link - check if ruTorrent is installed at runtime
if [ -d "/usr/mww/rutorrent" ] || [ -d "/mod/external/usr/mww/rutorrent" ]; then
	# Determine web server host and port dynamically
	WEBUI_HOST="${HTTP_HOST:-${SERVER_NAME:-fritz.box}}"
	# If HTTP_HOST doesn't include port, add it
	if [ -n "$HTTP_HOST" ] && echo "$HTTP_HOST" | grep -q ':'; then
		WEBUI_URL="http://${WEBUI_HOST}/rutorrent/"
	else
		WEBUI_PORT="${SERVER_PORT:-81}"
		WEBUI_URL="http://${WEBUI_HOST}:${WEBUI_PORT}/rutorrent/"
	fi
	RUTORRENT_LINK="<a href='${WEBUI_URL}' target='_blank'>ruTorrent</a>"
else
	RUTORRENT_LINK=""
	WEBUI_URL=""
fi

if [ -n "$RUTORRENT_LINK" ]; then
	sec_begin "$(lang de:"Web Interface" en:"Web Interface")"
	cat << EOF
<p>
$(lang de:"rTorrent kann über die Web-Oberfläche ruTorrent gesteuert werden:" en:"rTorrent can be controlled via the following web interface:") <strong>$RUTORRENT_LINK</strong>
</p>
<p>
<small>$(lang de:"Klicken Sie auf den obigen Link, um die Weboberfläche zu öffnen, oder greifen Sie darauf zu unter" en:"Click on the above link to open the web interface, or access it at"): <a href='${WEBUI_URL}' target='_blank'>${WEBUI_URL}</a></small>
</p>
EOF
	sec_end
fi

sec_begin "$(lang de:"Konfigurationsdateien" en:"Configuration Files")"
cat << EOF
<p style="font-family: monospace; font-size: 11px; line-height: 1.5;">
<strong>$(lang de:"rTorrent Konfiguration:" en:"rTorrent Configuration:")</strong><br>
&bull; <code>/var/flash/rtorrent.cfg</code> $(lang de:"(Web UI Einstellungen, persistent)" en:"(Web UI settings, persistent)")<br>
&bull; <code>/etc/default.rtorrent/rtorrent.cfg</code> $(lang de:"(Fallback, falls /var/flash leer)" en:"(Fallback if /var/flash empty)")<br>
&bull; <code>\${BASEDIR}/.rtorrent.rc</code> $(lang de:"(rTorrent Hauptkonfiguration)" en:"(rTorrent main config)")<br>
<br>
<strong>$(lang de:"ruTorrent Konfiguration:" en:"ruTorrent Configuration:")</strong><br>
&bull; <code>/usr/mww/rutorrent/conf/config.php</code> $(lang de:"(ruTorrent Einstellungen)" en:"(ruTorrent settings)")<br>
&bull; <code>/usr/mww/rutorrent/conf/plugins.ini</code> $(lang de:"(Plugin-Kontrolle)" en:"(Plugin control)")<br>
&bull; <code>/var/tmp/freetz_config.php</code> $(lang de:"(Dynamische SCGI-Konfiguration)" en:"(Dynamic SCGI configuration)")<br>
<br>
<small>$(lang de:"Hinweis: Bei externalisierten Paketen sind Dateien in /mod/external/usr/mww editierbar. Ansonsten sind sie schreibgeschützt (Firmware)." en:"Note: With externalized packages, files in /mod/external/usr/mww are editable. Otherwise they are read-only (firmware).")</small>
</p>
EOF
sec_end

sec_begin "$(lang de:"Starttyp" en:"Start type")"
cgi_print_radiogroup_service_starttype "enabled" "$RTORRENT_ENABLED" "" "" 0
sec_end

sec_begin "$(lang de:"Priorit&auml;t" en:"Priority")"
cat << EOF
<p>
<label for='nice'>Nice-Level: </label>
<input type='text' id='nice' name='nice' size='3' maxlength='3' value="$(html "$RTORRENT_NICE")">
</p>
EOF
sec_end

sec_begin "$(lang de:"Logging" en:"Logging")"
cat << EOF
<p>
<label for='loglevel'>Log-Level: </label>
<select name='loglevel' id='loglevel'>
<option value='error'$logerror_sel>ERROR</option>
<option value='warn'$logwarn_sel>WARN</option>
<option value='info'$loginfo_sel>INFO</option>
<option value='debug'$logdebug_sel>DEBUG</option>
</select>
</p>
EOF
sec_end

sec_begin "$(lang de:"Arbeitsverzeichnisse" en:"Working Directories")"
cat << EOF
<p>
<label for='basedir'>$(lang de:"Basisverzeichnis" en:"Base Directory"): </label>
<input type='text' id='basedir' name='basedir' size='50' maxlength='255' value="$(html "$RTORRENT_BASEDIR")">
<br><small>$(lang de:"Leer = Auto-Erkennung" en:"Empty = Auto-detect"): <code>$AUTO_STORAGE</code></small>
</p>

<p>
<label for='sessiondir'>$(lang de:"Sitzungsverzeichnis" en:"Session Directory"): </label>
<input type='text' id='sessiondir' name='sessiondir' size='40' maxlength='255' value="$(html "$RTORRENT_SESSIONDIR")">
</p>

<p>
<label for='downloaddir'>$(lang de:"Download-Verzeichnis" en:"Download Directory"): </label>
<input type='text' id='downloaddir' name='downloaddir' size='40' maxlength='255' value="$(html "$RTORRENT_DOWNLOADDIR")">
</p>

<p>
<label for='watchdir'>$(lang de:"Watch-Verzeichnis" en:"Watch Directory"): </label>
<input type='text' id='watchdir' name='watchdir' size='40' maxlength='255' value="$(html "$RTORRENT_WATCHDIR")">
</p>

<p>
<small>$(lang
de:"Relative Pfade werden als relativ zum Basisverzeichnis verstanden."
en:"Relative paths are interpreted as relative to the base directory."
)</small>
</p>
EOF
sec_end

sec_begin "$(lang de:"Peer-Einstellungen" en:"Peer Settings")"
cat << EOF
<p>
<small>$(lang
de:"Dieser Port muss in der Firewall freigegeben werden."
en:"This port must be opened in the firewall."
)</small>
</p>

<p>
<label for='peerport'>$(lang de:"Peer-Port" en:"Peer Port"): </label>
<input type='text' id='peerport' name='peerport' size='6' maxlength='5' value="$(html "$RTORRENT_PEERPORT")">
</p>

<p>
<label for='peerlimit'>$(lang de:"Maximale Peers" en:"Max Peers"): </label>
<input type='text' id='peerlimit' name='peerlimit' size='5' maxlength='4' value="$(html "$RTORRENT_PEERLIMIT")">
</p>

<p>
<label for='uploadslots'>$(lang de:"Upload-Slots" en:"Upload Slots"): </label>
<input type='text' id='uploadslots' name='uploadslots' size='5' maxlength='4' value="$(html "$RTORRENT_UPLOADSLOTS")">
</p>

<p>
<label for='downloadslots'>$(lang de:"Download-Slots" en:"Download Slots"): </label>
<input type='text' id='downloadslots' name='downloadslots' size='5' maxlength='4' value="$(html "$RTORRENT_DOWNLOADSLOTS")">
</p>

<p>
<label for='encryption'>$(lang de:"Verschl&uuml;sselung" en:"Encryption"): </label>
<input type='text' id='encryption' name='encryption' size='50' maxlength='100' value="$(html "$RTORRENT_ENCRYPTION")">
<br><small>$(lang
de:"z.B.: allow_incoming,try_outgoing,enable_retry"
en:"e.g.: allow_incoming,try_outgoing,enable_retry"
)</small>
</p>

<p>
<label for='dht'>DHT: </label>
<select name='dht' id='dht'>
<option value='off'$dhtoff_sel>$(lang de:"Aus" en:"Off")</option>
<option value='auto'$dhtauto_sel>$(lang de:"Automatisch" en:"Auto")</option>
<option value='on'$dhton_sel>$(lang de:"Ein" en:"On")</option>
<option value='disable'$dhtdisable_sel>$(lang de:"Deaktiviert" en:"Disabled")</option>
</select>
</p>

<p>
<label for='dhtport'>DHT-Port: </label>
<input type='text' id='dhtport' name='dhtport' size='6' maxlength='5' value="$(html "$RTORRENT_DHTPORT")">
</p>

<p>
<label for='usepex'>$(lang de:"PEX verwenden" en:"Use PEX"): </label>
<input type="hidden" name="pex" value="no">
<input type='checkbox' id='usepex' name='pex' value='yes'$usepex_chk>
</p>

<p>
<label for='daemonmode'>$(lang de:"Daemon-Modus" en:"Daemon mode"): </label>
<input type="hidden" name="daemon_mode" value="no">
<input type='checkbox' id='daemonmode' name='daemon_mode' value='yes'$daemonmode_chk>
<br><small>$(lang
de:"Abwählen nur für interaktives Debugging (Terminal erforderlich)"
en:"Uncheck only for interactive debugging (requires terminal)"
)</small>
</p>
EOF
sec_end

sec_begin "$(lang de:"Bandbreite" en:"Bandwidth")"
cat << EOF
<p>
<small>$(lang
de:"0 = unbegrenzt"
en:"0 = unlimited"
)</small>
</p>

<p>
<label for='downloadrate'>$(lang de:"Max Download (KB/s)" en:"Max Download (KB/s)"): </label>
<input type='text' id='downloadrate' name='downloadrate' size='8' maxlength='8' value="$(html "$RTORRENT_DOWNLOADRATE")">
</p>

<p>
<label for='uploadrate'>$(lang de:"Max Upload (KB/s)" en:"Max Upload (KB/s)"): </label>
<input type='text' id='uploadrate' name='uploadrate' size='8' maxlength='8' value="$(html "$RTORRENT_UPLOADRATE")">
</p>
EOF
sec_end

sec_begin "$(lang de:"SCGI/RPC-Einstellungen" en:"SCGI/RPC Settings")"
cat << EOF
<p>
<small>$(lang 
de:"<strong>SCGI</strong> ist die Kommunikationsschnittstelle zwischen rtorrent und ruTorrent.<br>
<strong>TCP Port (empfohlen):</strong> Funktioniert auf jedem Dateisystem (NTFS, FAT, ext4). Nutzt 127.0.0.1:5000 f&uuml;r lokalen Zugriff.<br>
<strong>UNIX Socket:</strong> Schneller, aber <span style='color:#c00;'>funktioniert NICHT auf NTFS/FAT</span>! Nur auf ext2/ext3/ext4/tmpfs verwenden."
en:"<strong>SCGI</strong> is the communication interface between rtorrent and ruTorrent.<br>
<strong>TCP Port (recommended):</strong> Works on any filesystem (NTFS, FAT, ext4). Uses 127.0.0.1:5000 for local access.<br>
<strong>UNIX Socket:</strong> Faster, but <span style='color:#c00;'>does NOT work on NTFS/FAT</span>! Only use on ext2/ext3/ext4/tmpfs."
)</small>
</p>

<p>
<label>$(lang de:"SCGI-Modus" en:"SCGI Mode"): </label><br>
<input type='radio' id='scgi_mode_port' name='scgi_mode' value='port'$scgimode_port_sel>
<label for='scgi_mode_port'><strong>$(lang de:"TCP Port (empfohlen)" en:"TCP Port (recommended)")</strong> - $(lang de:"Funktioniert auf jedem Dateisystem (NTFS/FAT/ext4)" en:"Works on any filesystem (NTFS/FAT/ext4)")</label>
<br>
<input type='radio' id='scgi_mode_socket' name='scgi_mode' value='socket'$scgimode_socket_sel>
<label for='scgi_mode_socket'>$(lang de:"UNIX Socket" en:"UNIX Socket")</label>
</p>

<p id='port_config'>
<label for='scgi_host'>$(lang de:"SCGI-Host" en:"SCGI Host"): </label>
<input type='text' id='scgi_host' name='scgi_host' size='20' maxlength='50' value="$(html "$RTORRENT_SCGI_HOST")">
<br>
<label for='scgi_port'>$(lang de:"SCGI-Port" en:"SCGI Port"): </label>
<input type='text' id='scgi_port' name='scgi_port' size='8' maxlength='5' value="$(html "$RTORRENT_SCGI_PORT")">
<br><small>$(lang 
de:"Standard: <code>127.0.0.1:5000</code><br>
<strong>127.0.0.1</strong> = nur lokaler Zugriff (sicher, empfohlen)<br>
<strong>0.0.0.0</strong> = LAN-Zugriff erlauben (Sicherheitsrisiko - keine Authentifizierung!)"
en:"Default: <code>127.0.0.1:5000</code><br>
<strong>127.0.0.1</strong> = local access only (secure, recommended)<br>
<strong>0.0.0.0</strong> = allow LAN access (security risk - no authentication!)"
)</small>
</p>

<p id='socket_config'>
<label for='scgi_socket'>$(lang de:"SCGI-Socket" en:"SCGI Socket"): </label>
<input type='text' id='scgi_socket' name='scgi_socket' size='40' maxlength='255' value="$(html "$RTORRENT_SCGI_SOCKET")">
<br><small style='color: #c00;'><strong>$(lang de:"WARNUNG:" en:"WARNING:")</strong> $(lang 
de:"UNIX-Sockets funktionieren NICHT auf NTFS/FAT/exFAT!<br>
Nur verwenden wenn Basis-Verzeichnis auf ext2/ext3/ext4/tmpfs liegt.<br>
<strong>Empfohlen:</strong> <code>/tmp/rtorrent-rpc.socket</code> (tmpfs, funktioniert immer)"
en:"UNIX sockets do NOT work on NTFS/FAT/exFAT!<br>
Only use if base directory is on ext2/ext3/ext4/tmpfs.<br>
<strong>Recommended:</strong> <code>/tmp/rtorrent-rpc.socket</code> (tmpfs, always works)"
)</small>
</p>

EOF

if [ -n "$RUTORRENT_LINK" ]; then
cat << EOF
<p>
$RUTORRENT_LINK
</p>
EOF
fi
sec_end

sec_begin "$(lang de:"Erweiterte Einstellungen" en:"Advanced Settings")"
cat << EOF
<p>
<label for='checkhash'>$(lang de:"Hash-Pr&uuml;fung nach Download" en:"Check hash on completion"): </label>
<input type="hidden" name="checkhash" value="no">
<input type='checkbox' id='checkhash' name='checkhash' value='yes'$checkhash_chk>
</p>

<p>
<label for='preallocate'>$(lang de:"Speicherplatz vorab reservieren" en:"Pre-allocate disk space"): </label>
<input type="hidden" name="preallocate" value="no">
<input type='checkbox' id='preallocate' name='preallocate' value='yes'$preallocate_chk>
</p>
<h3>$(lang de:"Erweiterte Optionen (optional)" en:"Advanced Options (optional)")</h3>

<p>
<label for='port_range'>$(lang de:"Port-Bereich" en:"Port Range"): </label>
<input type='text' id='port_range' name='port_range' size='15' maxlength='20' value="$(html "$RTORRENT_PORT_RANGE")">
<br><small>$(lang de:"z.B.: 6890-6999 (leer = Standard)" en:"e.g.: 6890-6999 (empty = default)")</small>
</p>

<p>
<label for='max_memory'>$(lang de:"Max. Speicher (MB)" en:"Max Memory (MB)"): </label>
<input type='text' id='max_memory' name='max_memory' size='8' maxlength='6' value="$(html "$RTORRENT_MAX_MEMORY")">
<br><small>$(lang de:"Leer = unbegrenzt" en:"Empty = unlimited")</small>
</p>

<p>
<label for='max_open_files'>$(lang de:"Max. offene Dateien" en:"Max Open Files"): </label>
<input type='text' id='max_open_files' name='max_open_files' size='8' maxlength='6' value="$(html "$RTORRENT_MAX_OPEN_FILES")">
<br><small>$(lang de:"Leer = Standard" en:"Empty = default")</small>
</p>

<p>
<label for='min_peers'>$(lang de:"Min. Peers pro Torrent" en:"Min Peers per Torrent"): </label>
<input type='text' id='min_peers' name='min_peers' size='5' maxlength='4' value="$(html "$RTORRENT_MIN_PEERS")">
</p>

<p>
<label for='max_peers'>$(lang de:"Max. Peers pro Torrent" en:"Max Peers per Torrent"): </label>
<input type='text' id='max_peers' name='max_peers' size='5' maxlength='4' value="$(html "$RTORRENT_MAX_PEERS")">
</p>

<p>
<label for='min_peers_seed'>$(lang de:"Min. Peers beim Seeden" en:"Min Peers when Seeding"): </label>
<input type='text' id='min_peers_seed' name='min_peers_seed' size='5' maxlength='4' value="$(html "$RTORRENT_MIN_PEERS_SEED")">
</p>

<p>
<label for='max_peers_seed'>$(lang de:"Max. Peers beim Seeden" en:"Max Peers when Seeding"): </label>
<input type='text' id='max_peers_seed' name='max_peers_seed' size='5' maxlength='4' value="$(html "$RTORRENT_MAX_PEERS_SEED")">
</p>

<p>
<label for='bind_address'>$(lang de:"Bind-Adresse" en:"Bind Address"): </label>
<input type='text' id='bind_address' name='bind_address' size='20' maxlength='50' value="$(html "$RTORRENT_BIND_ADDRESS")">
<br><small>$(lang de:"IP-Adresse für eingehende Verbindungen (leer = alle Interfaces)" en:"IP address for incoming connections (empty = all interfaces)")</small>
</p>

<p>
<label for='tracker_ip'>$(lang de:"Tracker-IP" en:"Tracker IP"): </label>
<input type='text' id='tracker_ip' name='tracker_ip' size='20' maxlength='50' value="$(html "$RTORRENT_TRACKER_IP")">
<br><small>$(lang de:"IP-Adresse für Tracker (leer = Auto-Erkennung)" en:"IP address reported to tracker (empty = auto-detect)")</small>
</p>
EOF
sec_end
