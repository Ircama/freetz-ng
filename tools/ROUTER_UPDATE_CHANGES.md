# Router Update - Modifiche Implementate

## 1. Logging SSH Completo ✅

### Funzionalità
- **File di log**: `/tmp/router_update_ssh.log`
- **Cosa viene loggato**:
  - Tutti i comandi SSH eseguiti
  - Tutti i comandi SCP eseguiti
  - Output dei comandi (quando catturato)
  - Timestamp preciso di ogni operazione

### Implementazione
```python
def log_ssh_command(command, output="", debug=False):
    """Log SSH/SCP commands to file for debugging"""
    try:
        with open(SSH_LOG_FILE, 'a', encoding='utf-8') as f:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            f.write(f"\n{'='*60}\n")
            f.write(f"[{timestamp}] COMMAND: {command}\n")
            if output:
                f.write(f"OUTPUT:\n{output}\n")
            f.write(f"{'='*60}\n")
    except Exception as e:
        if debug:
            cdebug(f"Failed to log SSH command: {e}", True)
```

### Utilizzo
```bash
# Esegui update
./router_update.py --host 192.168.178.1 --dry-run-extract

# Controlla il log
cat /tmp/router_update_ssh.log
```

### Esempio Output Log
```
# Router Update Tool - Change Log

## Latest Updates (2025-10-10)

### Fixed Issues

1. **Interactive Configuration in Dry-Run-Extract Mode**
   - Added interactive prompts for directory configuration even in `--dry-run-extract` mode
   - Users are now asked for temp directory and external directory before upload
   - Added confirmation prompt before starting dry-run-extract operation

2. **Progress Bar Display**
   - Fixed issue where progress bar showed 100% immediately
   - Progress now only displays when actual upload progress is detected
   - Added verification of upload completion before showing final progress

3. **SCP Output Suppression**
   - Added `silent` parameter to `sshpass_exec()` function
   - SCP commands now run with complete output suppression
   - No more SCP progress lines appearing in the output

4. **Upload Verification**
   - Added file size verification after upload completion
   - Upload is only marked successful if remote file size matches local file size
   - Better error detection for failed uploads

### Interactive Prompts in Dry-Run-Extract Mode

When running with `--dry-run-extract`, users will now see:

```
DRY-RUN-EXTRACT Configuration:
Files will be uploaded and tested, but NOT extracted or installed

Continue with dry-run-extract? [Y/n]:
  Suggested temp directory: /var/tmp
Use this temporary directory for uploads? [Y/n]:
  Suggested external directory: /var/media/ftp/FRITZBOX/external/...
Use this directory for external installation? [Y/n]:
```

### Upload Progress Improvements

- Progress monitoring thread now waits for file to appear on remote system
- Progress updates only when actual upload progress is detected
- Final verification ensures upload completed successfully
- Clean progress display without SCP output interference

### Technical Changes

1. **sshpass_exec() function**
   - Added `silent` parameter for complete output suppression
   - Used by SCP commands to prevent any output leakage

2. **scp_send() function**
   - Now calls `sshpass_exec()` with `silent=True`
   - Returns proper success/failure status
   - Better error detection in output

3. **upload_file_with_progress() function**
   - Added `shown_progress` flag to track if progress was displayed
   - Added upload verification step
   - Better handling of upload completion status

4. **main() function**
   - Added separate interactive configuration for `--dry-run-extract` mode
   - Improved user experience with clear warnings and confirmations

## Previous Changes

### SSH Command Logging (2025-10-10)

- All SSH/SCP commands logged to `/tmp/router_update_ssh.log`
- Includes timestamps, full commands, and output
- Log file location shown at start and end of execution

### SCP Output Filtering (2025-10-10)

- SCP progress lines (%, ETA, KB/s, MB/s) filtered from output
- Clean progress bar without interference from SCP's own progress display
- Password prompts filtered from output

### Interactive Directory Configuration (2025-10-10)

- Interactive prompts for temp directory and external directory
- Users can choose suggested directories or provide custom paths
- Summary shows all configured directories before upload

### Multi-Source Password Input (2025-10-09)

- Password from CLI argument (`--password`)
- Password from environment variable (`ROUTER_PASSWORD`)
- Interactive password prompt with `getpass`

### Selective Updates (2025-10-09)

- `--skip-firmware`: Update external only
- `--skip-external`: Update firmware only
- Interactive mode asks which components to update

### Dry-Run Modes (2025-10-09)

- `--dry-run`: Simulate update without making changes
- `--dry-run-extract`: Upload files and test archives (tar -t) without extraction

### Service Management (2025-10-09)

- Interactive prompts for stopping/restarting services
- Configurable stop strategies: `stop_avm`, `semistop_avm`, `nostop_avm`
- Optional external services restart

### Progress Display (2025-10-09)

- Clean progress bars with thread-based monitoring
- File size and speed display
- ETA calculation

## Usage Examples

### Interactive Dry-Run-Extract

```bash
python3 tools/router_update.py --host 192.168.178.1 --password mypass --dry-run-extract
```

This will:
1. Ask which components to update (firmware/external)
2. Ask for directory configuration
3. Upload files to router
4. Test archives with `tar -t` without extraction
5. Skip service stop/restart and installation

### Batch Mode with Verification

```bash
python3 tools/router_update.py --host 192.168.178.1 --password mypass \
    --image fw.image --external fw.external --batch
```

This will:
1. Upload both files
2. Verify upload completion
3. Extract and install with default settings
4. Log all SSH commands to `/tmp/router_update_ssh.log`

### External Only Update

```bash
python3 tools/router_update.py --host 192.168.178.1 --password mypass \
    --external fw.external --skip-firmware --batch
```

This will:
1. Upload external package
2. Extract to configured directory
3. Restart external services
4. Skip firmware update entirely

## Debug and Logging

All SSH/SCP commands are logged to `/tmp/router_update_ssh.log` with:
- Timestamp of execution
- Full command with all arguments
- Command output (if captured)

Example log entry:
```
============================================================
[2025-10-10 15:30:45] COMMAND: scp -o StrictHostKeyChecking=no -o LogLevel=ERROR -q fw.external root@192.168.178.1:/var/tmp/fw.external
OUTPUT:
Uploading fw.external to /var/tmp/fw.external
============================================================
```

[2025-10-10 15:30:46] COMMAND: scp -o StrictHostKeyChecking=no -o LogLevel=ERROR -q file.tar root@192.168.178.1:/var/tmp/file.tar
OUTPUT:
Uploading file.tar to /var/tmp/file.tar
============================================================
```

## 2. Filtraggio Output SCP ✅

### Problema Risolto
L'output grezzo di SCP appariva così:
```
7590AX_08.20.all_freetz-ng-2c6e25c32c-gcc-pyt   0%    0     0.0KB/s   --:-- ETA
7590AX_08.20.all_freetz-ng-2c6e25c32c-gcc-pyt   0%  255KB 255.0KB/s   22:52 ETA
7590AX_08.20.all_freetz-ng-2c6e25c32c-gcc-pyt   0%  255KB 229.5KB/s   25:24 ETA
...
```

**Cause:**
1. Output SCP senza `\r` iniziale (carriage return)
2. SCP scrive direttamente su PTY bypassando il filtering

### Soluzione Implementata
```python
# In sshpass_exec(), aggiungi filtro per righe di progresso SCP:
if b'scp' in cmd[0].encode():
    lines = data.split(b'\n')
    filtered_lines = []
    for line in lines:
        # Skip lines that look like SCP progress
        if b'%' in line and (b'ETA' in line or b'KB/s' in line or b'MB/s' in line):
            continue
        filtered_lines.append(line)
    filtered = b'\n'.join(filtered_lines)
```

### Opzioni SCP
- `-q` - quiet mode
- `-o LogLevel=ERROR` - solo errori critici
- `capture_output=True` - cattura tutto l'output

### Risultato
Ora l'utente vede solo la progress bar pulita:
```
Uploading file.external (342.0 MB) to /var/tmp/file.external
Upload in progress (this may take several minutes)...
  Progress: 45% | 154.0 MB/342.0 MB | 2.5 MB/s | ETA: 75s
✅ Upload complete
```

## 3. Directory Interattive ✅

### Nuovo Flusso Interattivo

Dopo "Proceed with update?", lo script ora chiede:

#### Directory Configuration
```
Directory Configuration:
  Suggested temp directory: /var/tmp
👉 Use this temporary directory for uploads? [Y/n]:
```

Se l'utente risponde **No**:
```
👉 Enter custom temporary directory path: /mnt/usb/staging
ℹ️ Using temp directory: /mnt/usb/staging
```

#### External Directory
```
  Suggested external directory: /var/media/ftp/FRITZBOX/external/nome-pacchetto
👉 Use this directory for external installation? [Y/n]:
```

Se l'utente risponde **No**:
```
👉 Enter custom external directory path: /mnt/usb/external/custom
ℹ️ Using external directory: /mnt/usb/external/custom
```

## 4. Summary Migliorato ✅

Il summary ora mostra tutte le directory configurate:

```
Update Summary:
  Router:          192.168.178.1
  User:            root
  Temp directory:  /var/tmp
  Firmware:        file.image (500.0 MB)
  External:        file.external (342.0 MB)
  External dir:    /var/media/ftp/FRITZBOX/external/nome-pacchetto
  Stop services:   stop_avm
  Reboot:          Yes
```

## Test e Debugging

### Script di Test
```bash
./tools/test_router_update.sh
```

### Verifica Logging
```bash
# Durante l'esecuzione
tail -f /tmp/router_update_ssh.log

# Dopo l'esecuzione
cat /tmp/router_update_ssh.log | less
```

### Verifica Output SCP
Durante l'upload, dovresti vedere **SOLO**:
```
Uploading file.external (342.0 MB) to /var/tmp/file.external
Upload in progress (this may take several minutes)...
  Progress: 12% | 41.0 MB/342.0 MB | 3.2 MB/s | ETA: 95s
```

**NON** dovresti vedere:
```
file.external   12%   41MB   3.2MB/s   01:35 ETA
```

## Troubleshooting

### Se il log non viene creato
```bash
# Verifica permessi
touch /tmp/router_update_ssh.log
chmod 644 /tmp/router_update_ssh.log
```

### Se l'output SCP compare ancora
1. Verifica che `-q` sia presente nel comando SCP
2. Controlla che `capture_output=True` sia settato
3. Verifica il filtro nel codice `sshpass_exec()`

### Se le directory non vengono chieste
- Verifica di non essere in modalità `--batch`
- Verifica di non essere in modalità `--dry-run` o `--dry-run-extract`

## Compatibilità

✅ Funziona con:
- Python 3.6+
- SSH/SCP standard
- Freetz-NG routers
- Batch mode (logging automatico)
- Interactive mode (logging + conferme)

❌ Limitazioni note:
- Log file sempre in `/tmp/` (hardcoded)
- Filtro SCP potrebbe non catturare formati di output personalizzati
- Directory chieste solo in modalità interattiva non-dry-run
