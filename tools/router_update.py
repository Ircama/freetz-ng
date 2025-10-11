#!/usr/bin/env python3
"""
router_update.py — Professional Freetz-NG Router Update via SSH/SCP

Emulates the web interface update process with interactive/batch modes, 
progress bars, dry-run, debug capabilities, and advanced UX.

Usage:
  python3 router_update.py --host 192.168.178.1 --password <pwd>
  python3 router_update.py --host 192.168.178.1 --password <pwd> --image path.image --external path.external --batch
  ROUTER_PASSWORD=<pwd> python3 router_update.py --host 192.168.178.1
"""
import os, sys, argparse, time, subprocess, threading, pty, select, errno, re, getpass
from glob import glob
from datetime import datetime

# --- CONSTANTS ---
DEFAULT_USER = 'root'
DEFAULT_TARGET_DIR = '/var/tmp'
DEFAULT_EXTERNAL_BASE = '/var/media/ftp/FRITZBOX/external'
STREAM_SIZE_THRESHOLD = 200 * 1024 * 1024  # 200MB
PING_TIMEOUT = 1
BOOT_WAIT_MAX_TRIES = 120  # 4 minutes
SSH_TEST_CMD = 'pwd'
SSH_LOG_FILE = '/tmp/router_update_ssh.log'

# --- COLORS AND EMOJIS ---
COLORS = {
    'reset': '\033[0m', 'red': '\033[91m', 'green': '\033[92m', 
    'yellow': '\033[93m', 'blue': '\033[94m', 'cyan': '\033[96m',
    'bold': '\033[1m', 'dim': '\033[2m'
}
EMOJI = {
    'ok': '✅', 'fail': '❌', 'wait': '⏳', 'copy': '📤', 'install': '🛠️', 
    'reboot': '🔄', 'ping': '📡', 'external': '📦', 'prompt': '👉',
    'warning': '⚠️', 'info': 'ℹ️', 'rocket': '🚀', 'check': '✓'
}

# --- UTILITY FUNCTIONS ---
def cprint(msg, color=None, emoji=None, end='\n', file=sys.stdout):
    """Print colored message with optional emoji prefix"""
    prefix = COLORS.get(color, '')
    suffix = COLORS['reset'] if color else ''
    emj = EMOJI.get(emoji, '') + ' ' if emoji else ''
    print(f"{prefix}{emj}{msg}{suffix}", end=end, file=file, flush=True)

def cerror(msg):
    """Print error message"""
    cprint(f"ERROR: {msg}", 'red', 'fail', file=sys.stderr)

def cwarning(msg):
    """Print warning message"""
    cprint(f"WARNING: {msg}", 'yellow', 'warning')

def cinfo(msg):
    """Print info message"""
    cprint(msg, 'cyan', 'info')

def cdebug(msg, debug=False):
    """Print debug message if debug mode enabled"""
    if debug:
        cprint(f"[DEBUG] {msg}", 'dim')

def progress_bar(current, total, prefix='', width=40):
    """Display a progress bar"""
    if total == 0:
        total = 1
    percent = int(100 * current / total)
    filled = int(width * current / total)
    bar = '█' * filled + '-' * (width - filled)
    print(f"\r{prefix}[{bar}] {percent}% ({current}/{total})", end='', flush=True)
    if current >= total:
        print()

def confirm(prompt, default=True):
    """Ask user for confirmation"""
    options = '[Y/n]' if default else '[y/N]'
    response = input(f"{EMOJI['prompt']} {prompt} {options}: ").strip().lower()
    if not response:
        return default
    return response in ('y', 'yes')

def get_file_size(filepath):
    """Get file size in bytes"""
    try:
        return os.path.getsize(filepath)
    except:
        return 0

def format_size(size_bytes):
    """Format bytes to human readable string"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.1f} TB"

def log_ssh_command(command, output="", debug=False):
    """Log SSH/SCP commands to file for debugging"""
    if not debug:
        return
    try:
        with open(SSH_LOG_FILE, 'a', encoding='utf-8') as f:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            f.write(f"\n{'='*60}\n")
            f.write(f"[{timestamp}] COMMAND: {command}\n")
            if output:
                f.write(f"OUTPUT:\n{output}\n")
            f.write(f"{'='*60}\n")
        cdebug(f"Logged SSH command to {SSH_LOG_FILE}", True)
    except Exception as e:
        cdebug(f"Failed to log SSH command: {e}", True)


# --- NETWORK UTILITY FUNCTIONS ---
def ping_router(host, timeout=PING_TIMEOUT):
    """Check if router responds to ping"""
    return os.system(f"ping -c 1 -W {timeout} {host} > /dev/null 2>&1") == 0

def wait_router_boot(host, password, user=DEFAULT_USER, max_tries=BOOT_WAIT_MAX_TRIES, debug=False):
    """Wait for router to boot and become accessible via SSH"""
    cinfo(f"Waiting for router {host} to boot...")
    start_time = time.time()
    
    # Phase 1: Wait for ping response
    cprint("Phase 1: Waiting for network connectivity", 'blue', 'ping')
    for i in range(max_tries):
        if ping_router(host):
            cprint(f"{EMOJI['ok']} Router is pingable!", 'green')
            break
        print('.', end='', flush=True)
        time.sleep(2)
    else:
        cerror(f"Timeout waiting for router to respond to ping ({max_tries * 2}s)")
        return False
    
    # Phase 2: Wait for SSH availability
    cprint("\nPhase 2: Waiting for SSH service", 'blue', 'wait')
    time.sleep(5)  # Give SSH daemon time to start
    for i in range(30):
        try:
            result = ssh_run(host, user, password, SSH_TEST_CMD, debug=debug, capture_output=True)
            if result and not 'connection refused' in result.lower():
                elapsed = int(time.time() - start_time)
                cprint(f"{EMOJI['ok']} Router is fully operational! (took {elapsed}s)", 'green')
                return True
        except:
            pass
        print('.', end='', flush=True)
        time.sleep(2)
    
    cerror("Timeout waiting for SSH service to start")
    return False

def count_tar_files(tarfile):
    """Count total files in tar archive"""
    try:
        output = subprocess.getoutput(f"tar -tf '{tarfile}' 2>/dev/null")
        return len([l for l in output.splitlines() if l.strip() and not l.endswith('/')])
    except:
        return 0

def get_password(args):
    """
    Get password from multiple sources (priority order):
    1. Command line argument (--password)
    2. Environment variable (ROUTER_PASSWORD)
    3. Interactive prompt (if not in batch mode)
    """
    if args.password:
        return args.password
    
    if 'ROUTER_PASSWORD' in os.environ:
        cdebug("Using password from ROUTER_PASSWORD environment variable", args.debug)
        return os.environ['ROUTER_PASSWORD']
    
    if args.batch:
        cerror("Password required in batch mode! Use --password or set ROUTER_PASSWORD environment variable")
        sys.exit(1)
    
    # Interactive password prompt
    try:
        password = getpass.getpass(f"{EMOJI['prompt']} Enter SSH password for {args.user}@{args.host}: ")
        if not password:
            cerror("Password cannot be empty!")
            sys.exit(1)
        return password
    except KeyboardInterrupt:
        cwarning("\nPassword input cancelled")
        sys.exit(130)

# --- FILE SELECTION FUNCTIONS ---
def find_images():
    """Find all .image and .external files in images/ directory"""
    images = sorted(glob('images/*.image'), key=os.path.getmtime, reverse=True)
    externals = sorted(glob('images/*.external'), key=os.path.getmtime, reverse=True)
    return images, externals

def select_file_interactive(files, file_type):
    """Interactive file selection from list"""
    if not files:
        cwarning(f"No {file_type} files found in images/ directory")
        return None
    
    cinfo(f"Available {file_type} files:")
    for i, f in enumerate(files[:5], 1):  # Show max 5 recent files
        size = format_size(get_file_size(f))
        mtime = datetime.fromtimestamp(os.path.getmtime(f)).strftime('%Y-%m-%d %H:%M')
        cprint(f"  {i}. {os.path.basename(f)} ({size}, {mtime})", 'cyan')
    
    cprint("")
    cprint(f"Latest {file_type}: {os.path.basename(files[0])}", 'green', 'check')
    
    if confirm(f"Use this {file_type}?", default=True):
        return files[0]
    
    choice = input(f"Enter number (1-{min(5, len(files))}) or path: ").strip()
    if choice.isdigit() and 1 <= int(choice) <= min(5, len(files)):
        cprint(f"Selected archive: {files[int(choice) - 1]}", 'green', 'check')
        return files[int(choice) - 1]
    elif os.path.exists(choice):
        cprint(f"Selected archive: {choice}", 'green', 'check')
        return choice
    else:
        cwarning(f"Invalid selection. Using latest {file_type}")
        return files[0]


# --- SSH/SCP WRAPPER ---
def sshpass_exec(cmd, password, verbose=False, retries=2, capture_output=False, silent=False):
    """
    Execute SSH/SCP command with automatic password authentication.
    Uses PTY to interact with SSH password prompts.
    
    Args:
        cmd: List of command arguments (e.g., ['ssh', 'root@host', 'ls'])
        password: SSH password
        verbose: Enable debug output
        retries: Number of password retry attempts
        capture_output: Return output as string instead of printing
        silent: Suppress all output (for SCP uploads)
    
    Returns:
        Output string if capture_output=True, empty string otherwise
    """
    pid, master = pty.fork()
    if pid == 0:
        # Child process: execute the command
        try:
            os.execvp(cmd[0], cmd)
        except Exception as e:
            print(f"Exec failed: {e}", file=sys.stderr)
            os._exit(127)
    
    # Parent process: handle password prompts and output
    rolling = bytearray()
    sent_count = 0
    hostkey_answered = False
    max_retries = max(0, retries)
    output = b''
    
    try:
        while True:
            r, _, _ = select.select([master, sys.stdin.fileno()], [], [], 0.1)
            
            # Handle stdin input
            if sys.stdin.fileno() in r:
                try:
                    data = os.read(sys.stdin.fileno(), 4096)
                except OSError:
                    data = b''
                if not data:
                    try:
                        os.shutdown(master, 1)
                    except Exception:
                        pass
                else:
                    os.write(master, data)
            
            # Handle command output
            if master in r:
                try:
                    data = os.read(master, 4096)
                except OSError as e:
                    if e.errno == errno.EIO:
                        break
                    raise
                
                if not data:
                    break
                
                # Filter password prompt from output
                filtered = data
                
                # For SCP, also filter progress lines (lines starting with filename and containing %)
                if b'scp' in cmd[0].encode():
                    # Filter SCP progress lines
                    lines = data.split(b'\n')
                    filtered_lines = []
                    for line in lines:
                        # Skip lines that look like SCP progress (contain % and ETA)
                        if b'%' in line and (b'ETA' in line or b'KB/s' in line or b'MB/s' in line):
                            continue
                        filtered_lines.append(line)
                    filtered = b'\n'.join(filtered_lines)
                
                for p in [b'password:', b'passwort:', b'pass:', b"'s password:", 
                          b'root password:', b'root@']:
                    idx = filtered.lower().find(p)
                    while idx != -1:
                        end = filtered.find(b'\n', idx)
                        start = filtered.rfind(b'\n', 0, idx)
                        next_nl = end
                        while next_nl != -1 and next_nl+1 < len(filtered) and filtered[next_nl+1:next_nl+2] == b'\n':
                            next_nl += 1
                        if start != -1 and end != -1:
                            filtered = filtered[:start] + filtered[(next_nl+1) if next_nl != -1 else (end+1):]
                        elif end != -1:
                            filtered = filtered[:idx] + filtered[(next_nl+1) if next_nl != -1 else (end+1):]
                        elif start != -1:
                            filtered = filtered[:start]
                        else:
                            filtered = filtered[:idx]
                        idx = filtered.lower().find(p)
                
                # Remove leading whitespace/newlines
                while filtered and filtered[:1] in (b'\n', b'\r', b' ', b'\t'):
                    filtered = filtered[1:]
                
                # Store or print output
                output += filtered
                if not capture_output and not silent and filtered:
                    os.write(sys.stdout.fileno(), filtered)
                
                if verbose:
                    sys.stderr.write("[recv hex] " + ' '.join(f'{x:02x}' for x in data) + "\n")
                    sys.stderr.flush()
                
                # Update rolling buffer for prompt detection
                rolling += data
                if len(rolling) > 4096:
                    rolling = rolling[-4096:]
                low = rolling.lower()
                
                # Handle SSH host key confirmation
                if (not hostkey_answered) and b"are you sure you want to continue connecting" in low:
                    os.write(master, b"yes\n")
                    hostkey_answered = True
                    rolling = bytearray()
                    continue
                if (not hostkey_answered) and b"(yes/no)?" in low:
                    os.write(master, b"yes\n")
                    hostkey_answered = True
                    rolling = bytearray()
                    continue
                
                # Detect and respond to password prompts
                if sent_count <= max_retries:
                    prompts = [b'password:', b'passwort:', b'pass:', b"'s password:", 
                               b'root password:', b'root@']
                    for p in prompts:
                        if p in low:
                            os.write(master, password.encode() + b"\n")
                            sent_count += 1
                            if verbose:
                                sys.stderr.write(f"[debug] Sent password (attempt {sent_count}) for prompt {p.decode(errors='ignore')}\n")
                                sys.stderr.flush()
                            rolling = bytearray()
                            break
                    else:
                        # Fallback: detect 'password' + ':' nearby
                        idx = low.find(b'password')
                        if idx != -1:
                            window = low[idx: idx + 64]
                            if b':' in window:
                                os.write(master, password.encode() + b"\n")
                                sent_count += 1
                                if verbose:
                                    sys.stderr.write(f"[debug] Sent password (attempt {sent_count})\n")
                                    sys.stderr.flush()
                                rolling = bytearray()
                                continue
                
                # Detect authentication failures
                fails = [b'permission denied', b'authentication failed', 
                         b'authentication error', b'login incorrect', b'access denied']
                if any(p in low for p in fails):
                    if verbose:
                        sys.stderr.write("[debug] Detected authentication failure, aborting\n")
                        sys.stderr.flush()
                    time.sleep(0.05)
                    break
    
    except KeyboardInterrupt:
        pass
    finally:
        try:
            _, status = os.waitpid(pid, 0)
        except ChildProcessError:
            pass
    
    return output.decode(errors='ignore') if capture_output else ''

def ssh_run(host, user, password, command, debug=False, capture_output=True):
    """Execute command on remote host via SSH"""
    cmd = ['ssh', '-o', 'StrictHostKeyChecking=no', f'{user}@{host}', command]
    cmd_str = ' '.join(cmd)
    cdebug(f"SSH: {cmd_str}", debug)
    
    # Execute command
    output = sshpass_exec(cmd, password, verbose=debug, capture_output=capture_output)
    
    # Log command and output only in debug mode
    if debug:
        log_ssh_command(cmd_str, output if capture_output else "[output not captured]", debug)
    
    return output

def scp_send(host, user, password, local, remote, debug=False):
    """Copy file to remote host via SCP"""
    # Use quiet mode and redirect all output to /dev/null to prevent progress display
    cmd = ['scp', '-o', 'StrictHostKeyChecking=no', '-o', 'LogLevel=ERROR', '-q', local, f'{user}@{host}:{remote}']
    cmd_str = ' '.join(cmd)
    cdebug(f"SCP: {cmd_str}", debug)
    
    # Log SCP command only in debug mode
    if debug:
        log_ssh_command(cmd_str, f"Uploading {local} to {remote}", debug)
    
    # Execute SCP with silent=True to suppress all output
    try:
        # Check if remote file already exists and warn user in interactive mode
        remote_exists = ssh_run(host, user, password, f"test -f '{remote}' && echo exists || echo notfound", debug=debug, capture_output=True).strip()
        if remote_exists == "exists":
            if not dry_run:
                if sys.stdin.isatty():  # Interactive mode
                    cwarning(f"Remote file already exists: {remote}")
                    if not confirm(f"Overwrite remote file\n '{remote}'?\n This will delete the existing file and it is needed to continue.", default=False):
                        cerror("Upload cancelled by user.")
                        return None
                # Delete remote file before upload
                ssh_run(host, user, password, f"rm -f '{remote}'", debug=debug)
            else:
                cwarning(f"[DRY-RUN] Remote file '{remote}' already exists. Would delete before upload.")

        output = sshpass_exec(cmd, password, verbose=False, capture_output=True, silent=True)
        # Check if there were any error messages in output
        if output and ('error' in output.lower() or 'failed' in output.lower() or 'permission denied' in output.lower()):
            cdebug(f"SCP error detected in output: {output}", debug)
            return False
        return True
    except Exception as e:
        cdebug(f"SCP exception: {e}", debug)
        return False


# --- ROUTER CONFIGURATION FUNCTIONS ---
class RouterConfig:
    """Router configuration container"""
    def __init__(self):
        self.external_dir = DEFAULT_EXTERNAL_BASE
        self.external_freetz_services = 'yes'
        self.lang = 'en'
        self.has_ubi = False
        self.ubi_size = 0
        self.ubi_available = 0
        self.storage_devices = []
        self.temp_suggestions = []
        
    def __repr__(self):
        return (f"RouterConfig(external_dir={self.external_dir}, "
                f"has_ubi={self.has_ubi}, storage_devices={len(self.storage_devices)})")

def parse_mod_config(config_text):
    """Parse /mod/etc/conf/mod.cfg content"""
    config = {}
    for line in config_text.splitlines():
        line = line.strip()
        if line.startswith('export '):
            # Remove 'export ' prefix
            line = line[7:]
            if '=' in line:
                key, value = line.split('=', 1)
                # Remove quotes from value
                value = value.strip("'\"")
                config[key] = value
    return config

def parse_df_output(df_text):
    """Parse df -h output to detect storage devices and UBI"""
    storage = []
    ubi_info = None
    
    for line in df_text.splitlines()[1:]:  # Skip header
        parts = line.split()
        if len(parts) >= 6:
            filesystem = parts[0]
            size = parts[1]
            used = parts[2]
            available = parts[3]
            use_percent = parts[4]
            mountpoint = ' '.join(parts[5:])
            
            # Detect UBI (internal flash storage)
            # UBI devices are mounted at /var/media/ftp or subdirectories
            if '/dev/ubi' in filesystem and '/var/media/ftp' in mountpoint:
                # Prefer the root UBI mount point (/var/media/ftp)
                # If we already have a UBI but this one is shorter path, replace it
                if ubi_info is None or len(mountpoint) < len(ubi_info['mountpoint']):
                    ubi_info = {
                        'filesystem': filesystem,
                        'size': size,
                        'available': available,
                        'mountpoint': mountpoint
                    }
            
            # Detect external storage (USB, SD card, etc.)
            # Only count devices that are NOT the UBI itself
            elif filesystem.startswith('/dev/sd') or filesystem.startswith('/dev/mmc'):
                storage.append({
                    'device': filesystem,
                    'size': size,
                    'available': available,
                    'use_percent': use_percent,
                    'mountpoint': mountpoint
                })
    
    return ubi_info, storage

def read_router_config(host, user, password, debug=False):
    """Read and parse router configuration"""
    config = RouterConfig()
    
    cprint("\n" + "="*70, 'bold')
    cprint("   Reading Router Configuration", 'bold', 'info')
    cprint("="*70 + "\n", 'bold')
    
    # Step 1: Read mod.cfg
    cinfo("Step 1: Reading Freetz-NG configuration (/mod/etc/conf/mod.cfg)")

    # Try to connect for up to 5 minutes, retrying every 2 seconds if 'No route to host' is detected
    start_time = time.time()
    no_route_first = True
    while True:
        mod_cfg_output = ssh_run(host, user, password, 
                                "cat /mod/etc/conf/mod.cfg 2>/dev/null",
                                debug=debug, capture_output=True)
        if mod_cfg_output and "ssh:" in mod_cfg_output and "No route to host" in mod_cfg_output:
            elapsed = time.time() - start_time
            if no_route_first:
                cerror(f"No connection to {host} (port 22: No route to host)")
                no_route_first = False
            else:
                print(".", end='', flush=True)
            if elapsed > 300:
                cerror(f"Could not connect to {host} after 5 minutes. Aborting.")
                return None
            time.sleep(2)
            continue
        if not mod_cfg_output or 'No such file' in mod_cfg_output:
            cerror("Freetz-NG configuration file not found!")
            cerror("File /mod/etc/conf/mod.cfg is missing. Freetz-NG may not be properly installed.")
            return None
        break
    
    # Parse mod.cfg
    mod_config = parse_mod_config(mod_cfg_output)
    
    # Set external_dir with fallback
    if 'MOD_EXTERNAL_DIRECTORY' in mod_config:
        config.external_dir = mod_config['MOD_EXTERNAL_DIRECTORY']
    else:
        config.external_dir = '/var/media/ftp/external'
        cwarning("MOD_EXTERNAL_DIRECTORY not found in config, using default: /var/media/ftp/external")
    
    if 'MOD_EXTERNAL_FREETZ_SERVICES' in mod_config:
        config.external_freetz_services = mod_config['MOD_EXTERNAL_FREETZ_SERVICES']
    if 'MOD_LANG' in mod_config:
        config.lang = mod_config['MOD_LANG']
    
    cprint(f"{EMOJI['ok']} Configuration loaded successfully", 'green')
    cprint(f"  External directory: {config.external_dir}", 'cyan')
    cprint(f"  External services:  {config.external_freetz_services}", 'cyan')
    cprint(f"  Language:           {config.lang}", 'cyan')
    
    # Step 2: Read storage information (df -h)
    cprint("")
    cinfo("Step 2: Detecting storage devices (df -h)")
    df_output = ssh_run(host, user, password, "df -h", debug=debug, capture_output=True)
    
    if df_output:
        ubi_info, storage_devices = parse_df_output(df_output)
        
        # UBI information
        if ubi_info:
            config.has_ubi = True
            config.ubi_size = ubi_info['size']
            config.ubi_available = ubi_info['available']
            cprint(f"\n{EMOJI['ok']} Internal UBI storage detected:", 'green')
            cprint(f"  Device:     {ubi_info['filesystem']}", 'cyan')
            cprint(f"  Size:       {ubi_info['size']}", 'cyan')
            cprint(f"  Available:  {ubi_info['available']}", 'cyan')
            cprint(f"  Mount:      {ubi_info['mountpoint']}", 'cyan')
        else:
            cwarning("No UBI storage detected (router may have limited internal storage)")
        
        # External storage devices
        if storage_devices:
            config.storage_devices = storage_devices
            cprint(f"\n{EMOJI['ok']} External storage devices detected: {len(storage_devices)}", 'green')
            for i, dev in enumerate(storage_devices, 1):
                cprint(f"  Device {i}:  {dev['device']}", 'cyan')
                cprint(f"    Size:       {dev['size']}", 'cyan')
                cprint(f"    Available:  {dev['available']}", 'cyan')
                cprint(f"    Used:       {dev['use_percent']}", 'cyan')
                cprint(f"    Mount:      {dev['mountpoint']}", 'cyan')
        else:
            cwarning("No external storage devices detected")
    
    # Determine temp directory suggestions
    config.temp_suggestions = []
    # If config.external_dir is set, use it as default with '/stage' appended unless it already contains 'stage' or 'external'
    if config.external_dir:
        ext_dir = config.external_dir.rstrip('/')
        # If external_dir ends with '/external', always suggest '/stage' for temp
        if ext_dir.endswith('/external'):
            config.temp_suggestions.append(ext_dir.replace('/external', '/stage'))
        elif ext_dir.endswith('/stage'):
            config.temp_suggestions.append(ext_dir)
        else:
            config.temp_suggestions.append(ext_dir + '/stage')
    # If UBI internal storage is present, suggest its mountpoint + /stage
    if config.has_ubi and hasattr(config, 'ubi_available') and hasattr(config, 'ubi_size'):
        ubi_stage = None
        # Try to get UBI mountpoint from config (set above)
        ubi_mount = None
        if 'ubi_info' in locals() and ubi_info and 'mountpoint' in ubi_info:
            ubi_mount = ubi_info['mountpoint']
        elif hasattr(config, 'ubi_mount'):
            ubi_mount = config.ubi_mount
        if ubi_mount:
            ubi_stage = ubi_mount.rstrip('/') + '/stage'
        else:
            ubi_stage = '/var/media/ftp/stage'
        config.temp_suggestions.append(ubi_stage)
    # Fallbacks
    if '/var/media/ftp/stage' not in config.temp_suggestions:
        config.temp_suggestions.append('/var/media/ftp/stage')
    config.temp_suggestions.append('/var/tmp')
    
    # Step 3: Additional router information
    cprint("")
    cinfo("Step 3: Gathering system information")
    
    # Get Freetz version
    freetz_version = ssh_run(host, user, password, 
                            "cat /etc/.freetz-version 2>/dev/null || echo 'Unknown'",
                            debug=debug, capture_output=True).strip()
    
    # Get kernel version
    kernel_version = ssh_run(host, user, password, 
                            "uname -r 2>/dev/null || echo 'Unknown'",
                            debug=debug, capture_output=True).strip()
    
    # Get box model
    box_model = ssh_run(host, user, password,
                       "cat /proc/sys/urlader/environment 2>/dev/null | grep 'HWRevision' | cut -d'=' -f2 || echo 'Unknown'",
                       debug=debug, capture_output=True).strip()
    
    if freetz_version != 'Unknown':
        cprint(f"  Freetz-NG:  {freetz_version}", 'cyan')
    if kernel_version != 'Unknown':
        cprint(f"  Kernel:     {kernel_version}", 'cyan')
    if box_model != 'Unknown':
        cprint(f"  Model:      {box_model}", 'cyan')
    
    cprint("\n" + "="*70 + "\n", 'bold')
    
    return config

# --- UPDATE PROCESS FUNCTIONS ---
def detect_external_dir(host, user, password, debug=False):
    """Detect current external directory from router configuration"""
    cdebug("Detecting external directory from router config", debug)
    # Try to read mod config
    output = ssh_run(host, user, password, 
                     "cat /mod/etc/conf/mod.cfg 2>/dev/null | grep EXTERNAL_DIRECTORY || echo '/var/media/ftp/FRITZBOX/external'",
                     debug=debug)
    if output and '/var' in output:
        match = re.search(r'(/var[^\s]+)', output)
        if match:
            return match.group(1)
    return DEFAULT_EXTERNAL_BASE

def upload_file_with_progress(host, user, password, local_file, remote_dir, debug=False, dry_run=False):
    """Upload file to router with progress indication"""
    filename = os.path.basename(local_file)
    filesize = get_file_size(local_file)
    remote_path = f"{remote_dir}/{filename}"
    
    cprint(f"Uploading file name: '{filename}' ({format_size(filesize)})", 'yellow', 'copy')
    # Count number of files in tar archive
    nfiles = count_tar_files(local_file)
    cprint(f"Archive contains {nfiles} files.", 'yellow', 'info')
    cprint(f"Stage filename: {remote_path}", 'yellow', 'copy')
    
    if dry_run:
        cwarning("[DRY-RUN] Skipping file upload")
        return remote_path
    
    # Check if remote file already exists and warn user in interactive mode
    remote_exists = ssh_run(host, user, password, f"test -f '{remote_path}' && echo exists || echo notfound", debug=debug, capture_output=True).strip()
    if remote_exists == "exists":
        if not dry_run:
            if sys.stdin.isatty():  # Interactive mode
                cwarning(f"Remote file already exists: {remote_path}")
                if not confirm(f"Overwrite remote file '{remote_path}'? This will delete the existing file.", default=False):
                    cerror("Upload cancelled by user.")
                    return None
            # Delete remote file before upload
            ssh_run(host, user, password, f"rm -f '{remote_path}'", debug=debug)
        else:
            cwarning(f"[DRY-RUN] Remote file '{remote_path}' already exists. Would delete before upload.")

    # For large files, show progress with monitoring thread
    if filesize > 10 * 1024 * 1024:  # > 10MB
        cinfo("Upload in progress (this may take several minutes)...")
        
        # Progress monitoring thread
        upload_done = threading.Event()
        start_time = time.time()
        
        def monitor_progress():
            """Monitor upload progress by checking remote file size"""
            last_size = 0
            shown_progress = False
            while not upload_done.is_set():
                try:
                    # Check remote file size
                    result = ssh_run(host, user, password, 
                                   f"ls -l {remote_path} 2>/dev/null | awk '{{print $5}}'",
                                   debug=False, capture_output=True)
                    if result and result.strip().isdigit():
                        current_size = int(result.strip())
                        if current_size > 0 and current_size > last_size:
                            last_size = current_size
                            elapsed = time.time() - start_time
                            speed = current_size / elapsed if elapsed > 0 else 0
                            percent = int(100 * current_size / filesize)
                            eta = int((filesize - current_size) / speed) if speed > 0 else 0
                            
                            # Clear line and show progress
                            print(f"\r   Progress: {percent}% | {format_size(current_size)}/{format_size(filesize)} | "
                                  f"{format_size(speed)}/s | ETA: {eta}s     ", end='', flush=True)
                            shown_progress = True
                except:
                    pass
                time.sleep(1)  # Update every second
            
            # If we never showed progress, it means upload was too fast or failed
            if not shown_progress:
                time.sleep(0.1)  # Give SCP time to complete
        
        # Start monitoring thread
        monitor_thread = threading.Thread(target=monitor_progress, daemon=True)
        monitor_thread.start()
        
        # Perform upload
        success = scp_send(host, user, password, local_file, remote_path, debug=debug)
        upload_done.set()
        monitor_thread.join(timeout=1)
        
        # Verify upload completed successfully
        elapsed = time.time() - start_time
        verify_result = ssh_run(host, user, password,
                               f"ls -l {remote_path} 2>/dev/null | awk '{{print $5}}'",
                               debug=debug, capture_output=True)
        
        if verify_result and verify_result.strip().isdigit():
            uploaded_size = int(verify_result.strip())
            if uploaded_size == filesize:
                speed = filesize / elapsed if elapsed > 0 else 0
                print(f"\r   Progress: 100% | {format_size(filesize)}/{format_size(filesize)} | "
                      f"{format_size(speed)}/s | Completed in {int(elapsed)}s     ")
                success = True
            else:
                print(f"\r  Upload incomplete: {format_size(uploaded_size)}/{format_size(filesize)}     ")
                success = False
        else:
            # Could not verify - assume success if scp_send returned True
            if success:
                speed = filesize / elapsed if elapsed > 0 else 0
                print(f"\r   Progress: 100% | {format_size(filesize)}/{format_size(filesize)} | "
                      f"{format_size(speed)}/s | Completed in {int(elapsed)}s     ")
    else:
        # Small files: simple upload
        start_time = time.time()
        success = scp_send(host, user, password, local_file, remote_path, debug=debug)
        elapsed = time.time() - start_time
    
    if success:
        cprint(f"{EMOJI['ok']} Upload complete", 'green')
        return remote_path
    else:
        cerror("Upload failed!")
        return None

def firmware_update_process(host, user, password, image_file, target_dir,
                           stop_services='stop_avm', no_reboot=False, 
                           debug=False, dry_run=False):
    """Execute firmware update process (emulates do_update_handler.sh)"""
    cprint("\n" + "="*60, 'bold')
    cprint("FIRMWARE UPDATE PROCESS", 'bold', 'install')
    cprint("="*60 + "\n", 'bold')
    
    # Upload firmware image
    remote_image = upload_file_with_progress(host, user, password, image_file, target_dir, debug, dry_run)
    if not remote_image:
        return False
    
    if dry_run:
        cwarning("[DRY-RUN] Skipping firmware extraction and installation")
        return True
    
    # Step 1: Extract firmware archive
    cinfo("Step 1: Extracting firmware archive to /")
    tar_count = count_tar_files(image_file)
    extract_cmd = f"tar -C / -xv < {remote_image} > /tmp/fw_extract.log 2>&1"
    cdebug(f"Extracting {tar_count} files from firmware", debug)
    
    # Monitor extraction progress
    extract_done = threading.Event()
    start_time = time.time()
    
    def monitor_extraction():
        """Monitor extraction progress by counting extracted files"""
        last_count = 0
        while not extract_done.is_set():
            try:
                # Count lines in extraction log (each line = one file)
                result = ssh_run(host, user, password, 
                               f"wc -l < /tmp/fw_extract.log 2>/dev/null || echo 0",
                               debug=False, capture_output=True)
                if result and result.strip().isdigit():
                    current_count = int(result.strip())
                    if current_count > last_count:
                        last_count = current_count
                        percent = min(99, int(100 * current_count / tar_count)) if tar_count > 0 else 0
                        print(f"\r   Extraction progress: {percent}% | {current_count}/{tar_count} files extracted     ", 
                              end='', flush=True)
            except:
                pass
            time.sleep(1)  # Update every second
    
    # Start monitoring thread
    monitor_thread = threading.Thread(target=monitor_extraction, daemon=True)
    monitor_thread.start()
    
    # Execute extraction
    ssh_run(host, user, password, extract_cmd, debug=debug, capture_output=False)
    extract_done.set()
    monitor_thread.join(timeout=1)
    
    # Show completion
    elapsed = int(time.time() - start_time)
    print(f"\r   Extraction progress: 100% | {tar_count}/{tar_count} files extracted in {elapsed}s     ")
    cprint(f"{EMOJI['ok']} Firmware extracted", 'green')
    
    # Step 2: Stop AVM services (if requested)
    if stop_services in ('stop_avm', 'semistop_avm'):
        cinfo(f"Step 2: Stopping AVM services ({stop_services})")
        if stop_services == 'stop_avm':
            ssh_run(host, user, password, "prepare_fwupgrade start", debug=debug)
            ssh_run(host, user, password, "prepare_fwupgrade end", debug=debug)
        else:
            ssh_run(host, user, password, "prepare_fwupgrade start_from_internet", debug=debug)
        cprint(f"{EMOJI['ok']} AVM services stopped", 'green')
    else:
        cinfo("Step 2: Skipping AVM services stop (nostop_avm mode)")
    
    # Step 3: Execute firmware installation script
    cinfo("Step 3: Executing firmware installation script (/var/install)")
    install_output = ssh_run(host, user, password, 
                            "cd / && /var/install 2>&1 | tee /tmp/var-install.out; echo EXIT_CODE=$?",
                            debug=debug)
    
    # Parse installation result
    exit_code = 6  # Default: OTHER_ERROR
    if 'EXIT_CODE=' in install_output:
        try:
            exit_code = int(install_output.split('EXIT_CODE=')[-1].split()[0])
        except:
            pass
    
    result_codes = {
        0: ("INSTALL_SUCCESS_NO_REBOOT", "green"),
        1: ("INSTALL_SUCCESS_REBOOT", "green"),
        2: ("INSTALL_WRONG_HARDWARE", "red"),
        3: ("INSTALL_KERNEL_CHECKSUM", "red"),
        4: ("INSTALL_FILESYSTEM_CHECKSUM", "red"),
        5: ("INSTALL_URLADER_CHECKSUM", "red"),
        6: ("INSTALL_OTHER_ERROR", "red"),
        7: ("INSTALL_FIRMWARE_VERSION", "yellow"),
        8: ("INSTALL_DOWNGRADE_NEEDED", "yellow"),
    }
    
    result_txt, color = result_codes.get(exit_code, ("UNKNOWN_ERROR", "red"))
    cprint(f"\nInstallation result: {exit_code} ({result_txt})", color, 'info' if color == 'green' else 'warning')
    
    # Step 4: Reboot if needed
    if exit_code == 1 and not no_reboot:
        cprint("\n" + "="*60, 'bold')
        cprint("REBOOTING ROUTER", 'bold', 'reboot')
        cprint("="*60 + "\n", 'bold')
        ssh_run(host, user, password, "reboot", debug=debug)
        return wait_router_boot(host, password, user, debug=debug)
    elif exit_code == 1 and no_reboot:
        cwarning("Reboot required but --no-reboot flag is set")
        return True
    elif exit_code <= 1:
        cprint(f"{EMOJI['ok']} Firmware update complete (no reboot required)", 'green')
        return True
    else:
        cerror("Firmware installation failed!")
        return False

def external_update_process(host, user, password, external_file, external_dir,
                            preserve_old=False, restart_services=True,
                            debug=False, dry_run=False):
    """Execute external update process (emulates do_external_handler.sh)"""
    cprint("\n" + "="*60, 'bold')
    cprint("EXTERNAL UPDATE PROCESS", 'bold', 'external')
    cprint("="*60 + "\n", 'bold')
    
    # Determine external directory from filename if not specified
    if not external_dir:
        basename = os.path.splitext(os.path.basename(external_file))[0]
        external_dir = f"{DEFAULT_EXTERNAL_BASE}/{basename}"
    
    cprint(f"Installation directory: {external_dir}", 'cyan', 'info')
    
    # Determine stage directory (replace /external with /stage, or get parent + /stage)
    if '/external' in external_dir:
        stage_dir = external_dir.replace('/external', '/stage')
    else:
        # Get parent directory and append /stage
        parent_dir = '/'.join(external_dir.rstrip('/').split('/')[:-1])
        stage_dir = f"{parent_dir}/stage" if parent_dir else '/var/media/ftp/stage'
    
    cprint(f"Stage directory: {stage_dir}", 'cyan', 'info')
    
    # Upload external archive to stage directory (has space for large files)
    remote_external = upload_file_with_progress(host, user, password, external_file, stage_dir, debug, dry_run)
    if not remote_external:
        return False
    
    if dry_run:
        cwarning("[DRY-RUN] Skipping external extraction")
        return True
    
    # Step 1: Stop external services
    if restart_services:
        cinfo("Step 1: Stopping external services")
        status = ssh_run(host, user, password, "/mod/etc/init.d/rc.external status 2>/dev/null", debug=debug)
        if 'running' in status:
            ssh_run(host, user, password, "/mod/etc/init.d/rc.external stop", debug=debug)
            cprint(f"{EMOJI['ok']} External services stopped", 'green')
        else:
            cinfo("External services not running")
    
    # Step 2: Delete or preserve old directory
    if preserve_old:
        cinfo("Step 2: Keeping old external directory and files")
    else:
        cinfo("Step 2: Removing old external directory and files")
        ssh_run(host, user, password, f"rm -rf {external_dir}", debug=debug)
        cprint(f"{EMOJI['ok']} Old external directory and files removed", 'green')
    
    # Step 3: Extract external archive
    cinfo("Step 3: Extracting external archive")
    tar_count = count_tar_files(external_file)
    extract_cmd = f"mkdir -p {external_dir} && tar -C {external_dir} -xv < {remote_external} > /tmp/ext_extract.log 2>&1"
    cdebug(f"Extracting {tar_count} files to {external_dir}", debug)
    
    # Monitor extraction progress
    extract_done = threading.Event()
    start_time = time.time()
    
    def monitor_extraction():
        """Monitor extraction progress by counting extracted files"""
        last_count = 0
        while not extract_done.is_set():
            try:
                # Count lines in extraction log (each line = one file)
                result = ssh_run(host, user, password, 
                               f"wc -l < /tmp/ext_extract.log 2>/dev/null || echo 0",
                               debug=False, capture_output=True)
                if result and result.strip().isdigit():
                    current_count = int(result.strip())
                    if current_count > last_count:
                        last_count = current_count
                        percent = min(99, int(100 * current_count / tar_count)) if tar_count > 0 else 0
                        print(f"\r   Extraction progress: {percent}% | {current_count}/{tar_count} files extracted     ", 
                              end='', flush=True)
            except:
                pass
            time.sleep(1)  # Update every second
    
    # Start monitoring thread
    monitor_thread = threading.Thread(target=monitor_extraction, daemon=True)
    monitor_thread.start()
    
    # Execute extraction
    ssh_run(host, user, password, extract_cmd, debug=debug, capture_output=False)
    extract_done.set()
    monitor_thread.join(timeout=1)
    
    # Show completion
    elapsed = int(time.time() - start_time)
    print(f"\r   Extraction progress: 100% | {tar_count}/{tar_count} files extracted in {elapsed}s     ")
    cprint(f"{EMOJI['ok']} External files extracted", 'green')
    
    # Step 4: Mark as external directory
    cinfo("Step 4: Mark external directory")
    ssh_run(host, user, password, f"touch {external_dir}/.external", debug=debug)
    
    # Step 5: Restart external services
    if restart_services:
        cinfo("Step 5: Starting external services...")
        ret = ssh_run(host, user, password, "/mod/etc/init.d/rc.external start", debug=debug)
        cprint(ret)
        cprint(f"{EMOJI['ok']} External services started", 'green')
    
    return True



# --- MAIN FUNCTION ---
def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Professional Freetz-NG Router Update Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Interactive mode (recommended for first-time users)
    %(prog)s --host 192.168.178.1 --password mypass

    # Batch mode with specific files
    %(prog)s --host 192.168.178.1 --password mypass --image fw.image --external fw.external --batch

    # Dry-run to test without making changes
    %(prog)s --host 192.168.178.1 --password mypass --dry-run

    # Update only firmware (no external)
    %(prog)s --host 192.168.178.1 --password mypass --image fw.image --batch --skip-external

    # Update only external (no firmware)
    %(prog)s --host 192.168.178.1 --password mypass --external fw.external --batch --skip-firmware
"""
    )
    
    # Connection arguments
    conn_group = parser.add_argument_group('Connection Options')
    conn_group.add_argument('--host', required=True,
                           help='Router IP address or hostname')
    conn_group.add_argument('--user', default=DEFAULT_USER,
                           help=f'SSH username (default: {DEFAULT_USER})')
    conn_group.add_argument('--password',
                           help='SSH password (or use ROUTER_PASSWORD env var, or interactive prompt)')
    
    # File selection arguments
    file_group = parser.add_argument_group('File Selection')
    file_group.add_argument('--image',
                           help='Firmware .image file path (or auto-detect from images/)')
    file_group.add_argument('--external',
                           help='External .external file path (or auto-detect from images/)')
    file_group.add_argument('--skip-firmware', action='store_true',
                           help='Skip firmware update (external only)')
    file_group.add_argument('--skip-external', action='store_true',
                           help='Skip external update (firmware only)')
    
    # Directory arguments
    dir_group = parser.add_argument_group('Directory Options')
    dir_group.add_argument('--target-dir', default=DEFAULT_TARGET_DIR,
                          help=f'Temporary directory on router for uploads (default: {DEFAULT_TARGET_DIR})')
    dir_group.add_argument('--external-dir',
                          help='External installation directory (default: auto-detect)')
    
    # Update behavior arguments
    update_group = parser.add_argument_group('Update Behavior')
    update_group.add_argument('--stop-services', 
                             choices=['stop_avm', 'semistop_avm', 'nostop_avm'],
                             default='stop_avm',
                             help='AVM services stop strategy (default: stop_avm)')
    update_group.add_argument('--no-reboot', action='store_true',
                             help='Do not reboot router after firmware update')
    update_group.add_argument('--no-delete-external', action='store_true',
                             help='Delete old external files before extraction')
    update_group.add_argument('--no-external-restart', action='store_true',
                             help='Do not restart external services after update')
    update_group.add_argument('--stream-threshold', type=int, default=STREAM_SIZE_THRESHOLD,
                             help=f'File size threshold for streaming mode in bytes (default: {STREAM_SIZE_THRESHOLD})')
    
    # Mode arguments
    mode_group = parser.add_argument_group('Execution Modes')
    mode_group.add_argument('--batch', action='store_true',
                           help='Batch mode: no interactive prompts, use only CLI arguments')
    mode_group.add_argument('--dry-run', action='store_true',
                           help='Dry-run: show what would be done without making changes')
    mode_group.add_argument('--debug', action='store_true',
                           help='Enable debug output')
    
    args = parser.parse_args()
    
    # Get password from args, env var, or prompt
    args.password = get_password(args)
    
    # Print header
    cprint("\n" + "="*70, 'bold')
    cprint("   Freetz-NG Router Update Tool", 'bold', 'rocket')
    cprint("="*70 + "\n", 'bold')
    
    # Initialize SSH log file only if debug mode is active
    if args.debug:
        try:
            with open(SSH_LOG_FILE, 'w', encoding='utf-8') as f:
                f.write(f"Router Update Session - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            cinfo(f"SSH commands will be logged to: {SSH_LOG_FILE}")
        except Exception as e:
            cwarning(f"Could not create SSH log file: {e}")
    
    if args.dry_run:
        cwarning("DRY-RUN MODE: No changes will be made to the router\n")
    
    # Read router configuration (always read to show information and validate)
    router_config = read_router_config(args.host, args.user, args.password, args.debug)
    if router_config is None:
        cerror("Cannot proceed without valid Freetz-NG configuration!")
        return 1
    
    # Update defaults based on router configuration
    if not args.external_dir:
        # Use configured external directory as default
        DEFAULT_EXTERNAL_BASE_OVERRIDE = router_config.external_dir
        cdebug(f"Using external directory from router config: {DEFAULT_EXTERNAL_BASE_OVERRIDE}", args.debug)
    
    # Validate arguments
    if args.skip_firmware and args.skip_external:
        cerror("Cannot skip both firmware and external updates!")
        return 1
    
    # File selection (interactive or batch)
    images, externals = find_images()
    
    if not args.skip_firmware and not args.image:
        if args.batch:
            if not images:
                cerror("No firmware images found and --batch mode requires --image")
                return 1
            args.image = images[0]
            cinfo(f"Auto-selected latest image: {os.path.basename(args.image)}")
        else:
            # Interactive: ask if user wants to install firmware
            if confirm("Install firmware image?", default=True):
                args.image = select_file_interactive(images, 'firmware image')
                if not args.image:
                    cwarning("No firmware image selected, skipping firmware update")
                    args.skip_firmware = True
            else:
                cinfo("Skipping firmware update")
                args.skip_firmware = True
    
    if not args.skip_external and not args.external:
        if args.batch:
            if externals:
                args.external = externals[0]
                cinfo(f"Auto-selected latest external: {os.path.basename(args.external)}")
            else:
                cinfo("No external files found, skipping external update")
                args.skip_external = True
        else:
            # Interactive: ask if user wants to install external
            cprint("")  # Empty line for spacing
            if confirm("Install external package?", default=True):
                args.external = select_file_interactive(externals, 'external package')
                if not args.external:
                    cwarning("No external package selected, skipping external update")
                    args.skip_external = True
            else:
                cinfo("Skipping external update")
                args.skip_external = True
    
    # Re-validate that at least one operation is selected
    if args.skip_firmware and args.skip_external:
        cerror("No operations selected! Must install at least firmware or external.")
        return 1
    
    # Validate selected files exist
    if args.image and not os.path.exists(args.image):
        cerror(f"Firmware image not found: {args.image}")
        return 1
    if args.external and not os.path.exists(args.external):
        cerror(f"External package not found: {args.external}")
        return 1
    
    # Interactive directory configuration
    cprint("\n" + "-"*70, 'dim')  # Begin directory configuration
    cinfo("Directory Configuration:")
    
    # Show storage information first
    if router_config:
        cprint(f"  💡 Available storage devices:", 'yellow')
        # Show UBI internal storage first if present
        if router_config.has_ubi and hasattr(router_config, 'ubi_available') and hasattr(router_config, 'ubi_size'):
            ubi_label = getattr(router_config, 'ubi_mount', None) or '/var/media/ftp'
            cprint(f"     [UBI] {ubi_label}: {router_config.ubi_available} free ({router_config.ubi_size} total)", 'yellow')
        # Show external devices
        if router_config.storage_devices:
            for dev in router_config.storage_devices:
                cprint(f"     {dev['mountpoint']}: {dev['available']} free ({dev['size']} total)", 'yellow')
        cprint("")  # Empty line for spacing
    
    # Determine best temp directory suggestion
    if router_config and router_config.temp_suggestions:
        suggested_temp = router_config.temp_suggestions[0]
    else:
        suggested_temp = args.target_dir
    
    if args.batch:
        args.target_dir = suggested_temp
    else:
        # Ask for temporary upload directory
        cprint(f"  Suggested temp directory: {suggested_temp}", 'cyan')
        if router_config and len(router_config.temp_suggestions) > 1:
            cprint(f"  Alternative options:", 'dim')
            for alt in router_config.temp_suggestions[1:]:
                cprint(f"    - {alt}", 'dim')
        
        # Ask for temp directory
        if not confirm("Use suggested temporary directory for uploads?", default=True):
            custom_dir = input(f"{EMOJI['prompt']} Enter custom temporary directory path: ").strip()
            if custom_dir:
                args.target_dir = custom_dir
                cinfo(f"Using temp directory: {args.target_dir}")
        else:
            args.target_dir = suggested_temp
            cinfo(f"Using temp directory: {args.target_dir}")

    # Check and create temp directory if needed
    temp_exists = ssh_run(args.host, args.user, args.password, f"test -d {args.target_dir} && echo exists || echo notfound", debug=args.debug).strip()
    if temp_exists == "exists":
        cwarning(f"Temporary directory '{args.target_dir}' already exists on router.")
        if not args.batch:
            if not confirm(
                    f"Delete temporary directory on router: {args.target_dir}?\n   This will remove all its contents and it is required to continue.",
                    default=True
            ):
                cwarning("Process interrupted by user.")
                return 1
        if not args.dry_run:
            # Ask if user wants to delete the temp directory if it exists
            delete_dir_cmd = f"rm -rf '{args.target_dir}'; echo EXIT_CODE=$?"
            delete_result = ssh_run(args.host, args.user, args.password, delete_dir_cmd, debug=args.debug)
            error_keywords = [
                "cannot remove", "permission denied", "no such file or directory", "disk full",
                "input/output error", "invalid argument", "not a directory", "read-only file system",
                "operation not permitted", "exit_code="
            ]
            exit_code = None
            if "exit_code=" in delete_result.lower():
                try:
                    exit_code = int(delete_result.lower().split("exit_code=")[-1].split()[0])
                except Exception:
                    exit_code = None
            if exit_code is not None and exit_code != 0:
                cerror(f"Failed to delete temporary directory '{args.target_dir}'.\n   Check permissions or try manually.")
                return 1
            else:
                cprint(f"{EMOJI['ok']} Temporary directory '{args.target_dir}' deleted.", 'green')
        else:
            cinfo("[DRY RUN] Temporary directory deleted.")

    if not args.dry_run:
        create_dir_cmd = f"mkdir -p '{args.target_dir}'; echo EXIT_CODE=$?"
        create_result = ssh_run(args.host, args.user, args.password, create_dir_cmd, debug=args.debug)
        error_keywords = [
            "cannot create directory", "permission denied", "no space left", "disk full",
            "input/output error", "invalid argument", "not a directory", "read-only file system",
            "operation not permitted", "file exists", "exit_code="
        ]
        exit_code = None
        if "exit_code=" in create_result.lower():
            try:
                exit_code = int(create_result.lower().split("exit_code=")[-1].split()[0])
            except Exception:
                exit_code = None
        if exit_code is not None and exit_code != 0:
            cerror(f"Failed to create temporary directory '{args.target_dir}'. Check permissions, disk space, or choose another path.")
            return 1
        cprint(f"{EMOJI['ok']} Temporary directory '{args.target_dir}' created.", 'green')
    else:
        cwarning("[DRY RUN Temporary directory created.")
        return 1

    # Show temp directory size
    temp_size = ssh_run(args.host, args.user, args.password, f"du -sh '{args.target_dir}' 2>/dev/null | awk '{{print $1}}'", debug=args.debug, capture_output=True).strip()
    cprint(f"  Temporary directory size: {temp_size}", 'cyan')
    cprint("")  # Empty line for spacing

    # Ask for external directory if external update is selected
    if args.external and not args.skip_external:
        if not args.external_dir:
            # Use router config external directory directly (without appending basename)
            if router_config:
                suggested_dir = router_config.external_dir
            else:
                suggested_dir = DEFAULT_EXTERNAL_BASE
            if args.batch:
                args.external_dir = suggested_dir
            else:
                cprint(f"  Suggested external directory: {suggested_dir}", 'cyan')
                # Show storage recommendations
                if router_config and router_config.storage_devices:
                    cprint(f"  💡 Available storage devices:", 'yellow')
                    # Show UBI internal storage first if present
                    if router_config.has_ubi and hasattr(router_config, 'ubi_available') and hasattr(router_config, 'ubi_size'):
                        ubi_label = getattr(router_config, 'ubi_mount', None) or '/var/media/ftp'
                        cprint(f"     [UBI] {ubi_label}: {router_config.ubi_available} free ({router_config.ubi_size} total)", 'yellow')
                    # Show external devices
                    if router_config.storage_devices:
                        for dev in router_config.storage_devices:
                            cprint(f"     {dev['mountpoint']}: {dev['available']} free", 'yellow')
                if confirm("Use suggested directory for external installation?", default=True):
                    args.external_dir = suggested_dir
                else:
                    custom_dir = input(f"{EMOJI['prompt']} Enter custom external directory path: ").strip()
                    args.external_dir = custom_dir if custom_dir else suggested_dir
                    cinfo(f"Using external directory: {args.external_dir}")

        # Check and create external directory if needed
        ext_exists = ssh_run(args.host, args.user, args.password, f"test -d '{args.external_dir}' && echo exists || echo notfound", debug=args.debug).strip()
        if ext_exists != "exists":
            cwarning(f"External directory does not exist on router: {args.external_dir}")
            if not args.dry_run:
                if confirm(f"Create external directory on router: {args.external_dir}?", default=True):
                    create_dir_cmd = f"mkdir -p '{args.external_dir}'; echo EXIT_CODE=$?"
                    create_result = ssh_run(args.host, args.user, args.password, create_dir_cmd, debug=args.debug)
                    error_keywords = [
                        "cannot create directory", "permission denied", "no space left", "disk full",
                        "input/output error", "invalid argument", "not a directory", "read-only file system",
                        "operation not permitted", "file exists", "exit_code="
                    ]
                    error_found = any(kw in create_result.lower() for kw in error_keywords)
                    exit_code = None
                    if "exit_code=" in create_result.lower():
                        try:
                            exit_code = int(create_result.lower().split("exit_code=")[-1].split()[0])
                        except Exception:
                            exit_code = None
                    if error_found or (exit_code is not None and exit_code != 0):
                        cerror(f"Failed to create external directory '{args.external_dir}'. Check permissions, disk space, or choose another path.")
                        return 1
                    else:
                        cprint(f"{EMOJI['ok']} External directory '{args.external_dir}' created.", 'green')
        else:
            cwarning(f"External directory '{args.external_dir}' already exists on router.")

        cinfo(f"External directory: {args.external_dir}")

        # Show external directory size
        ext_size = ssh_run(args.host, args.user, args.password, f"du -sh '{args.external_dir}' 2>/dev/null | awk '{{print $1}}'", debug=args.debug, capture_output=True).strip()
        cprint(f"  External directory size: {ext_size}", 'cyan')

    # Ask for external directory if external update is selected
    if args.external and not args.skip_external:
        if not args.external_dir:
            # Use router config external directory directly (without appending basename)
            if router_config:
                suggested_dir = router_config.external_dir
            else:
                suggested_dir = DEFAULT_EXTERNAL_BASE
            
            cprint(f"  Suggested external directory: {suggested_dir}", 'cyan')
            
            # Show storage recommendations
            if router_config and router_config.storage_devices:
                cprint(f"  💡 Available storage devices:", 'yellow')
                # Show UBI internal storage first if present
                if router_config.has_ubi and hasattr(router_config, 'ubi_available') and hasattr(router_config, 'ubi_size'):
                    ubi_label = getattr(router_config, 'ubi_mount', None) or '/var/media/ftp'
                    cprint(f"     [UBI] {ubi_label}: {router_config.ubi_available} free ({router_config.ubi_size} total)", 'yellow')
                # Show external devices
                if router_config.storage_devices:
                    for dev in router_config.storage_devices:
                        cprint(f"     {dev['mountpoint']}: {dev['available']} free", 'yellow')
            
            if confirm("Use suggested directory for external installation?", default=True):
                args.external_dir = suggested_dir
            else:
                custom_dir = input(f"{EMOJI['prompt']} Enter custom external directory path: ").strip()
                args.external_dir = custom_dir if custom_dir else suggested_dir
                cinfo(f"Using external directory: {args.external_dir}")
    
    cprint("-"*70 + "\n", 'dim')  # End of directory configuration
    
    # Interactive service management
    if args.image and not args.skip_firmware:
        cprint("\n" + "-"*70, 'dim')
        cinfo("Firmware Update Service Management:")
        if confirm("Stop AVM services before firmware update?", default=True):
            if confirm("Use full stop (stop_avm) instead of semi-stop (semistop_avm)?", default=True):
                args.stop_services = 'stop_avm'
            else:
                args.stop_services = 'semistop_avm'
        else:
            args.stop_services = 'nostop_avm'
            cwarning("Warning: Not stopping AVM services may cause issues!")
        
        args.no_reboot = not confirm("Reboot router after firmware installation?", default=True)
        cprint("-"*70 + "\n", 'dim')
    
    if args.external and not args.skip_external and not args.batch:
        cprint("\n" + "-"*70, 'dim')
        cinfo("External Update Service Management:")

        if confirm("Delete external directory after file upload and before extraction?", default=True):
            args.no_delete_external = True
        cprint("-"*70 + "\n", 'dim')

        if not confirm("Stop/restart external services after the file extraction?", default=True):
            args.no_external_restart = True
            cwarning("Warning: Not restarting services may cause issues!")
            
    # Show summary
    cprint("\n" + "-"*70, 'dim')
    cinfo("Update Summary:")
    cprint(f"  Router:           {args.host}", 'cyan')
    cprint(f"  User:             {args.user}", 'cyan')
    # Get temp directory size
    temp_size = ssh_run(args.host, args.user, args.password, f"du -hs {args.target_dir} 2>/dev/null | awk '{{print $1}}'", debug=args.debug, capture_output=True).strip()
    temp_size_str = f" ({temp_size})" if temp_size else ""
    cprint(f"  Temp directory:   {args.target_dir}{temp_size_str}", 'cyan')
    if args.image:
        cprint(f"  Firmware:         {os.path.basename(args.image)} ({format_size(get_file_size(args.image))})", 'cyan')
    if args.external:
        cprint(f"  External archive: {os.path.basename(args.external)} ({format_size(get_file_size(args.external))})", 'cyan')
        if args.external_dir:
            ext_size = ssh_run(args.host, args.user, args.password, f"du -hs {args.external_dir} 2>/dev/null | awk '{{print $1}}'", debug=args.debug, capture_output=True).strip()
            ext_size_str = f" ({ext_size})" if ext_size else ""
            cprint(f"  External dir:     {args.external_dir}{ext_size_str}", 'cyan')
    if args.image and not args.skip_firmware:
        cprint(f"  Stop services:    {args.stop_services}", 'cyan')
        cprint(f"  Reboot:           {'No' if args.no_reboot else 'Yes'}", 'cyan')
    cprint("-"*70 + "\n", 'dim')

    # Execute firmware update
    if args.image and not args.skip_firmware:
        success = firmware_update_process(
            args.host, args.user, args.password, args.image, args.target_dir,
            stop_services=args.stop_services, no_reboot=args.no_reboot,
            debug=args.debug, dry_run=args.dry_run
        )
        if not success:
            cerror("Firmware update failed!")
            return 1
    
    # Execute external update
    if args.external and not args.skip_external:
        # Detect external dir if not provided
        if not args.external_dir:
            if router_config:
                # Use configuration from router
                basename = os.path.splitext(os.path.basename(args.external))[0]
                args.external_dir = f"{router_config.external_dir}/{basename}"
                cdebug(f"Using external directory from router config: {args.external_dir}", args.debug)
            elif not args.dry_run:
                # Fallback to detection
                args.external_dir = detect_external_dir(args.host, args.user, args.password, args.debug)
                cdebug(f"Detected external directory: {args.external_dir}", args.debug)

        if not args.batch:
            if not confirm("Proceed with update?", default=False):
                cinfo("Update cancelled by user.")
                return 0
        
        success = external_update_process(
            args.host, args.user, args.password, args.external, args.external_dir,
            preserve_old=args.no_delete_external, 
            restart_services=not args.no_external_restart,
            debug=args.debug, dry_run=args.dry_run
        )
        if not success:
            cerror("External update failed!")
            return 1
    
    # Final success message
    cprint("\n" + "="*70, 'bold')
    cprint("   UPDATE COMPLETED SUCCESSFULLY!", 'green', 'ok')
    cprint("="*70 + "\n", 'bold')
    
    # Show log file location only in debug mode
    if args.debug and os.path.exists(SSH_LOG_FILE):
        cinfo(f"SSH command log saved to: {SSH_LOG_FILE}")
    
    return 0

if __name__ == "__main__":
    try:
        ret = main()
        cprint("")
        sys.exit(ret)
    except KeyboardInterrupt:
        cwarning("\n\nUpdate interrupted by user")
        sys.exit(130)
    except Exception as e:
        cerror(f"Unexpected error: {e}")
        if '--debug' in sys.argv:
            import traceback
            traceback.print_exc()
        sys.exit(1)

