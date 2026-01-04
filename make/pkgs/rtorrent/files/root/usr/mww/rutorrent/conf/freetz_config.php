<?php
// ruTorrent dynamic configuration for Freetz-NG
// This file is auto-loaded by ruTorrent to configure SCGI connection

// Auto-detect first available USB storage
function autodetect_storage() {
	// Load Freetz config
	$mod_cfg = '/mod/etc/conf/mod.cfg';
	$stor_prefix = 'uStor';
	if (file_exists($mod_cfg)) {
		$lines = file($mod_cfg, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
		foreach ($lines as $line) {
			if (preg_match("/^export MOD_STOR_PREFIX='([^']+)'/", $line, $matches)) {
				$stor_prefix = $matches[1];
				break;
			}
		}
	}
	
	// Try ${stor_prefix}01 first
	$default_path = "/var/media/ftp/{$stor_prefix}01/rtorrent";
	if (is_dir("/var/media/ftp/{$stor_prefix}01")) {
		return $default_path;
	}
	
	// Try to find any mounted USB storage
	$usb_dirs = glob('/var/media/ftp/*', GLOB_ONLYDIR);
	if (!empty($usb_dirs)) {
		return $usb_dirs[0] . '/rtorrent';
	}
	
	// Fallback to tmpfs
	return '/var/tmp/rtorrent';
}

// Read SCGI socket path from rtorrent's active .rtorrent.rc file
$scgi_socket = '/tmp/rpc.socket';  // Default fallback

// Find BASEDIR - try /var/flash first (user config), then /etc/default (default)
$basedir = '';
$config_files = ['/var/flash/rtorrent.cfg', '/etc/default.rtorrent/rtorrent.cfg'];
foreach ($config_files as $freetz_cfg) {
	if (file_exists($freetz_cfg)) {
		$lines = file($freetz_cfg, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
		foreach ($lines as $line) {
			if (preg_match("/^export RTORRENT_BASEDIR='([^']+)'/", $line, $matches)) {
				$basedir = $matches[1];
				if (!empty($basedir)) {
					break 2; // Exit both loops if found
				}
			}
		}
	}
}

// If BASEDIR not set or empty, try to auto-detect
if (empty($basedir)) {
	$basedir = autodetect_storage();
}

// Try to read SCGI configuration from .rtorrent.rc in BASEDIR
$rtorrent_rc = $basedir . '/.rtorrent.rc';
if (file_exists($rtorrent_rc)) {
	$lines = file($rtorrent_rc, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
	foreach ($lines as $line) {
		// Match: network.scgi.open_port = 127.0.0.1:5000 (TCP mode)
		if (preg_match('/^\s*network\.scgi\.open_port\s*=\s*(.+)/', $line, $matches)) {
			$tcp_config = trim($matches[1]);
			// Parse host:port
			if (preg_match('/^([^:]+):(\d+)$/', $tcp_config, $parts)) {
				$scgi_host = $parts[1];
				$scgi_port = (int)$parts[2];
				break;
			}
		}
		// Match: network.scgi.open_local = /path/to/socket (UNIX socket mode)
		if (preg_match('/^\s*network\.scgi\.open_local\s*=\s*(.+)/', $line, $matches)) {
			$socket_path = trim($matches[1]);
			// Handle relative paths - if not starting with /, assume /tmp/
			if ($socket_path[0] !== '/') {
				$socket_path = '/tmp/' . $socket_path;
			}
			$scgi_host = 'unix://' . $socket_path;
			$scgi_port = 0;
			break;
		}
	}
} else {
	// Fallback defaults if .rtorrent.rc not found
	$scgi_host = 'unix://' . $scgi_socket;
	$scgi_port = 0;
}

// Note: $scgi_host and $scgi_port are now set from .rtorrent.rc
// They can be used directly by ruTorrent's config.php
?>
