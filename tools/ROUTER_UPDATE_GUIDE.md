# Router Update Tool - Guida Utente

## Nuove Funzionalità

### Logging SSH
Tutti i comandi SSH/SCP vengono automaticamente loggati in `/tmp/router_update_ssh.log` per debugging e tracciabilità.

Il log contiene:
- Timestamp di ogni comando
- Comando completo eseguito
- Output del comando (quando disponibile)

**Esempio log:**
```
============================================================
[2025-10-10 15:30:45] COMMAND: ssh -o StrictHostKeyChecking=no root@192.168.178.1 pwd
OUTPUT:
/var/tmp
============================================================
```

### Modalità Dry-Run Avanzata

#### 1. `--dry-run` (Simulazione Completa)
```bash
./router_update.py --host 192.168.178.1 --dry-run
```
- Non copia file sul router
- Mostra solo cosa verrebbe fatto
- Nessuna modifica al sistema

#### 2. `--dry-run-extract` (Test con Copia)
```bash
./router_update.py --host 192.168.178.1 --dry-run-extract
```
- **Copia i file** sul router (firmware.image e/o external.tar)
- **Testa gli archivi** con `tar -t` invece di `tar -x`
- **NON estrae** i file nel filesystem
- **NON modifica** i servizi AVM o external
- Mostra i primi 20 file dell'archivio
- Utile per verificare l'integrità degli archivi prima dell'installazione vera

### Gestione Interattiva dei Servizi

In modalità interattiva (senza `--batch`), lo script ora chiede:

#### Per Firmware Update:
1. **Stop AVM services?** (default: Yes)
   - Se Yes: chiede se usare full stop o semi-stop
   - Se No: usa nostop_avm (⚠️ warning mostrato)

2. **Reboot dopo installazione?** (default: Yes)

#### Per External Update:
1. **Stop/restart external services?** (default: Yes)
   - Controlla se servizi sono running
   - Stop prima dell'estrazione
   - Restart dopo l'estrazione

2. **Delete old external files?** (default: No)
   - Rimuove la directory esistente prima dell'estrazione

## Esempi d'Uso

### Test Archivio Senza Installazione
```bash
# Solo test firmware
./router_update.py --host 192.168.178.1 --dry-run-extract --skip-external

# Solo test external
./router_update.py --host 192.168.178.1 --dry-run-extract --skip-firmware

# Test entrambi
./router_update.py --host 192.168.178.1 --dry-run-extract
```

### Installazione Interattiva Completa
```bash
./router_update.py --host 192.168.178.1
```
Lo script chiederà:
1. Install firmware image? (Yes/No)
2. Install external files? (Yes/No)
3. Proceed with update? (Yes/No)
4. **[Directory Configuration]**
   - Use `/var/tmp` for temporary uploads? (Yes/No)
   - Use suggested directory for external installation? (Yes/No)
5. **[Se firmware]** Stop AVM services? (Yes/No)
6. **[Se firmware]** Use full stop? (Yes/No) - se stop AVM = Yes
7. **[Se firmware]** Reboot after firmware? (Yes/No)
8. **[Se external]** Stop/restart external services? (Yes/No)
9. **[Se external]** Delete old external files? (Yes/No)

### Progress Bar Durante Upload
Durante l'upload di file grandi (>10MB), viene mostrata una progress bar pulita senza output SCP:
```
Uploading file.external (342.0 MB) to /var/tmp/file.external
Upload in progress (this may take several minutes)...
  Progress: 45% | 154.0 MB/342.0 MB | 2.5 MB/s | ETA: 75s
✅ Upload complete
```

**L'output grezzo di SCP è completamente soppresso** per evitare confusione.

### Installazione Batch con Password da Environment
```bash
export ROUTER_PASSWORD='my_secret_password'
./router_update.py --host 192.168.178.1 --batch \
  --image images/latest.image \
  --external images/latest.external \
  --stop-services stop_avm \
  --no-reboot
```

### Solo External Update (Skip Firmware)
```bash
# Interattivo
./router_update.py --host 192.168.178.1

# Batch
./router_update.py --host 192.168.178.1 --batch \
  --skip-firmware \
  --external images/my_addon.external \
  --no-external-restart
```

## Parametri Principali

### Connessione
- `--host IP` - Indirizzo IP del router
- `--user USER` - Username SSH (default: root)
- `--password PWD` - Password (opzionale, può usare env var ROUTER_PASSWORD)

### File
- `--image FILE` - Percorso firmware image
- `--external FILE` - Percorso external package
- `--skip-firmware` - Salta aggiornamento firmware
- `--skip-external` - Salta aggiornamento external

### Servizi
- `--stop-services {stop_avm,semistop_avm,nostop_avm}` - Strategia stop servizi AVM
- `--no-reboot` - Non riavvia dopo firmware
- `--no-external-restart` - Non riavvia servizi external
- `--delete-old-external` - Cancella vecchi file external

### Modalità
- `--batch` - Modalità batch (no prompt interattivi)
- `--dry-run` - Simulazione senza modifiche
- `--dry-run-extract` - Copia file + test tar senza estrazione
- `--debug` - Output debug verboso

## Workflow Tipici

### Test Prima dell'Installazione
```bash
# 1. Prima verifica l'archivio
./router_update.py --host 192.168.178.1 --dry-run-extract

# 2. Se OK, installa in modalità interattiva
./router_update.py --host 192.168.178.1
```

### Aggiornamento Notturno Automatico
```bash
#!/bin/bash
export ROUTER_PASSWORD='secret'
./router_update.py --host 192.168.178.1 --batch \
  --stop-services stop_avm \
  --delete-old-external
```

### Update Solo External (Sviluppo Addon)
```bash
# Test
./router_update.py --host 192.168.178.1 --dry-run-extract \
  --skip-firmware --external build/my_addon.external

# Installa
./router_update.py --host 192.168.178.1 \
  --skip-firmware --external build/my_addon.external
```

## Note Importanti

⚠️ **Modalità dry-run-extract**:
- I file vengono copiati sul router in `/var/tmp/`
- Gli archivi vengono testati ma NON estratti
- I servizi NON vengono fermati/riavviati
- Utile per verificare archivi corrotti prima dell'installazione

⚠️ **Gestione Servizi**:
- In modalità interattiva, le scelte dei servizi vengono chieste DOPO la conferma "Proceed with update?"
- In modalità batch, usa i parametri CLI o i default
- nostop_avm è sconsigliato (mostra warning)

⚠️ **Password**:
1. Cerca in `--password` argument
2. Cerca in `ROUTER_PASSWORD` environment variable
3. Chiede interattivamente con getpass (nascosto)
