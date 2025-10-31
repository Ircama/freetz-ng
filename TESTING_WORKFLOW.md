# Guida al Testing dei Pacchetti con GitHub Actions

## ============================================
## CONFIGURAZIONE INIZIALE (una sola volta)
## ============================================

### 1. Verifica e configura i remote
```bash
git remote -v
# Se non c'è upstream, aggiungilo:
git remote add upstream https://github.com/Freetz-NG/freetz-ng.git
```

### 2. Abilita GitHub Actions
- Vai su: https://github.com/Ircama/freetz-ng/settings/actions
- Seleziona: "Allow all actions and reusable workflows"

File necessari: make_package.yml  merge_all_prs.sh (nella directory "..")

Installazione dei file:

```bash
# Scarica TESTING_WORKFLOW.md
wget https://raw.githubusercontent.com/Ircama/freetz-ng/testing-tools/TESTING_WORKFLOW.md

# Scarica make_package.yml
wget https://raw.githubusercontent.com/Ircama/freetz-ng/testing-tools/make_package.yml

# Scarica merge_all_prs.sh
wget https://raw.githubusercontent.com/Ircama/freetz-ng/testing-tools/merge_all_prs.sh
chmod +x merge_all_prs.sh

# Oppure:
git checkout testing-tools
cp TESTING_WORKFLOW.md make_package.yml merge_all_prs.sh ..
git checkout master
```

## ============================================
## WORKFLOW PER TESTARE UN PACCHETTO
## ============================================

### Step 1: Sincronizza master con upstream
⚠️ **ATTENZIONE**: Questo comando cancellerà tutte le modifiche locali al master!

```bash
git checkout master
git fetch upstream
git reset --hard upstream/master  # Allinea con upstream
git push origin master --force    # Forza il push sul tuo fork
```

### Step 2: Genera l'ambiente di test

**Opzione A - Merge di tutte le PR aperte:**
```bash
../merge_all_prs.sh
```

**Opzione B - Merge di una specifica PR:**
```bash
git merge ircama-python3 --no-edit
git merge ircama-php --no-edit
# ... altre PR se necessario
```

### Step 3: Configura i pacchetti da testare
```bash
# Configura i pacchetti che vuoi testare
make menuconfig

# ⚠️ IMPORTANTE: Abilita le librerie necessarie, ad esempio:
# - libxml2 (per PHP)
# - libatomic (per vari pacchetti)
# - ncurses (per vari pacchetti)
```

### Step 4: Copia le configurazioni
```bash
# Copia la configurazione attuale nella directory workflows
cp .config .github/myconfig

# Copia il workflow:
rm .github/workflows/* # Cancella tutti i workflow
cp ../make_package.yml .github/workflows/make_package.yml
```

### Step 5: Commit e push
```bash
git add .github/workflows/myconfig
# Se hai modificato anche il workflow:
git add .github/workflows/make_package.yml
```

La directory dei workflow deve contenere due file: make_package.yml e myconfig

```bash
$ ls -l .github/workflows
total 120
-rw-r--r-- 1 myuser myuser 21587 Oct 31 13:07 make_package.yml
-rw-r--r-- 1 myuser myuser 97827 Oct 31 13:06 myconfig
```

```bash
git commit -m "CI: Update myconfig for testing $(date +%Y-%m-%d)"
git push origin master
```

### Step 6: Esegui il workflow manualmente

**Via interfaccia web:**
1. Vai su: https://github.com/Ircama/freetz-ng/actions
2. Clicca su: "make_package"
3. Clicca su: "Run workflow"
4. Inserisci il nome del pacchetto (esempio: `php-recompile` o `patchelf,ncurses`)
5. Clicca: "Run workflow"

**Via GitHub CLI (alternativa):**
```bash
gh repo set-default Ircama/freetz-ng

gh workflow run make_package.yml -f make_target="php-recompile"
```

### Step 7: Monitora l'esecuzione
```bash
# Via CLI
gh repo set-default Ircama/freetz-ng

gh run watch

# Via web
# https://github.com/Ircama/freetz-ng/actions
```

## ============================================
## TRIGGER AUTOMATICO VIA COMMIT
## ============================================

Puoi anche triggerare il workflow automaticamente includendo "make" nel commit message:

```bash
# Esempio 1: Test di un singolo pacchetto
git commit -m "test: make php-recompile"

# Esempio 2: Test di più pacchetti
git commit -m "test: make php-recompile,patchelf-recompile"

# Esempio 3: Fullbuild (compila firmware completo)
git commit -m "test: make gcc-toolchain-fullbuild"

# ⚠️ I commit che iniziano con "CI:", "workflow:", "build:" vengono SALTATI
```

## ============================================
## PATTERN SUPPORTATI DAL WORKFLOW
## ============================================

### Target disponibili:
- `package` → `-precompiled` (default)
- `package-precompiled` → Compila precompilato
- `package-recompile` → Ricompila da zero
- `package-compile` → Compila standard
- `package-fullbuild` → Build firmware completo (per gcc-toolchain, etc.)

### Input multipli:
```bash
# Più pacchetti con target diversi
make php-recompile,patchelf-precompiled,ncurses-compile
```

## ============================================
## VERIFICA PACCHETTI CONFIGURATI
## ============================================

```bash
# Lista dei pacchetti abilitati nella config attuale
tools/make_progress_monitor.sh --list-packages
```

## ============================================
## TROUBLESHOOTING
## ============================================

### Problema: "Package could not be enabled"
**Causa**: Dipendenze non soddisfatte per quel toolchain
**Soluzione**: Il workflow salta automaticamente (exit 0), è normale

### Problema: "libxml-2.0 not found"
**Causa**: libxml2 non abilitato in myconfig
**Soluzione**:
```bash
# Abilita in menuconfig:
# Libraries → Compression, coding & regex → libxml2
make menuconfig
cp .config .github/workflows/myconfig
git add .github/workflows/myconfig
git commit -m "config: Enable libxml2"
git push
```

### Problema: "make[2]: *** No rule to make target 'libcrypto.a'"
**Causa**: Mismatch tra versione OpenSSL configurata e toolchain
**Soluzione**: Verifica compatibilità OpenSSL con toolchain specifico
Alcuni toolchain vecchi (gcc-4.6.4, uClibc-0.9.28) potrebbero non supportare OpenSSL 3.x

### Problema: Build timeout
**Causa**: Fullbuild può richiedere ore
**Soluzione**: Usa target più specifici (package-recompile invece di fullbuild)

## ============================================
## RESET COMPLETO (dopo i test)
## ============================================

```bash
# 1. Resetta il master all'upstream
git fetch upstream
git checkout master
git reset --hard upstream/master
git push origin master --force

# 2. Pulisci file di build locali
make distclean

# 3. (Opzionale) Disabilita GitHub Actions
# Vai su: https://github.com/Ircama/freetz-ng/settings/actions
# Seleziona: "Disable actions"
```

## ============================================
## BEST PRACTICES
## ============================================

1. **Prima di ogni test**: Verifica che upstream/master sia aggiornato
2. **Commit frequenti**: Salva .github/workflows/myconfig ad ogni cambio configurazione
3. **Test incrementali**: Testa pochi pacchetti alla volta (non tutti insieme)
4. **Monitora i log**: Controlla i log delle Actions per errori specifici
5. **Branch di test**: Considera di usare un branch separato invece di master

## ============================================
## ESEMPIO COMPLETO: Test PHP
## ============================================

```bash
# 1. Reset e sync
git checkout master
git fetch upstream
git reset --hard upstream/master
git push origin master --force

# 2. Merge della PR PHP
git merge ircama-php --no-edit

# 3. Configura
make menuconfig
# Abilita: PHP, libxml2, libatomic, openssl

# 4. Salva config
cp .config .github/workflows/myconfig

# 5. Commit
git add .github/workflows/myconfig
git commit -m "test: make php-recompile

Enable PHP 8.4 with libxml2, libatomic, and openssl"

# 6. Push (trigger automatico)
git push origin master

# 7. Monitora
gh run watch
```

## ============================================
## COMANDI UTILI
## ============================================

```bash
# Verifica stato workflow
gh run list --workflow=make_package.yml --limit 5

# Cancella un workflow in esecuzione
gh run cancel <run-id>

# Scarica artifact (se configurato)
gh run download <run-id>

# Visualizza log
gh run view <run-id> --log

# Lista PR aperte upstream
gh pr list --repo Freetz-NG/freetz-ng --state open

# Merge multiplo interattivo
./merge_all_prs.sh
```
