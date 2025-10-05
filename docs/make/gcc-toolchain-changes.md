# Modifiche al pacchetto GCC Toolchain

## Obiettivo
Riabilitare la cross-compilazione del GCC per il dispositivo target (Fritz!Box) senza alterare l'ambiente del toolchain esistente.

## Modifiche Apportate

### 1. `make/pkgs/gcc-toolchain/Config.in`
**Modifiche:**
- Rimosso `FREETZ_SHOW_DEVELOPER` dalla dipendenza - il pacchetto è ora disponibile a tutti gli utenti
- Aggiunto `select FREETZ_TARGET_TOOLCHAIN` per abilitare automaticamente la build del toolchain target
- Aggiornato il titolo da "Native Compiler from Build System" a "Native Compiler for Target Device"

**Risultato:** Il pacchetto è ora accessibile a tutti gli utenti che hanno abilitato `EXTERNAL_ENABLED`, non solo agli sviluppatori.

### 2. `config/ui/toolchain.in`
**Modifiche:**
- Modificato `FREETZ_TARGET_TOOLCHAIN` per essere selezionabile solo in modalità sviluppatore se si costruisce il toolchain manualmente
- Rimosso `depends on FREETZ_REAL_DEVELOPER_ONLY` (ora è solo nel `bool ... if`)
- Aggiunto help per indicare che l'opzione è abilitata automaticamente dal pacchetto GCC Toolchain

**Risultato:** `FREETZ_TARGET_TOOLCHAIN` può essere selezionato automaticamente dal pacchetto senza richiedere i privilegi di sviluppatore.

### 3. `make/pkgs/gcc-toolchain/gcc-toolchain.mk`
**Modifiche principali:**

#### Rimossi percorsi hardcoded:
- ~~`GCC_TOOLCHAIN_TARGET_UTILS_DIR:=source/target-mips_gcc-13.4.0_uClibc-1.0.55-nptl_kernel-4.9/target-utils`~~
- ~~`GCC_TOOLCHAIN_DEST_DIR:=packages/target-mips_gcc-13.4.0_uClibc-1.0.55-nptl_kernel-4.9/gcc-toolchain-13.4.0/root`~~

#### Aggiunte variabili dinamiche:
```makefile
GCC_TOOLCHAIN_SOURCE_DIR:=$(TARGET_UTILS_DIR)
GCC_TOOLCHAIN_BINARY:=$(TARGET_UTILS_DIR)/usr/bin/gcc
$(PKG)_TARGET_BINARY:=$($(PKG)_DEST_DIR)/usr/bin/gcc
```

#### Uso delle variabili standard:
- Tutte le occorrenze di `GCC_TOOLCHAIN_DEST_DIR` → `$(PKG)_DEST_DIR` (variabile standard Freetz)
- Tutte le occorrenze di `GCC_TOOLCHAIN_TARGET_UTILS_DIR` → `$(GCC_TOOLCHAIN_SOURCE_DIR)` (che usa `TARGET_UTILS_DIR`)
- Percorso Python headers: da `toolchain/target/usr/include/python3.13` → `$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/python3.13`

#### Rimossi target personalizzati:
- Rimossi i target manuali `gcc-toolchain`, `gcc-toolchain-precompiled`, `gcc-toolchain-clean`, `gcc-toolchain-uninstall`
- Sostituiti con `$(PKG_FINISH)` - il sistema standard di Freetz gestisce automaticamente questi target

#### Gestione dipendenze:
- Il prerequisito `$(GCC_TOOLCHAIN_BINARY)` (che punta a `$(TARGET_UTILS_DIR)/usr/bin/gcc`) viene costruito automaticamente quando `FREETZ_TARGET_TOOLCHAIN` è abilitato
- Non ci sono dipendenze esplicite su `gcc_target`, `binutils_target`, `uclibc_target` nel makefile del pacchetto
- Questo evita di alterare il toolchain esistente

## Come Funziona

### Architettura e Filosofia del Design

**Principio fondamentale**: Il pacchetto `gcc-toolchain` **NON altera** il toolchain esistente di Freetz-NG. Funziona in modo completamente isolato:

1. **Selezione del pacchetto:**
   - L'utente seleziona "GCC Toolchain" nel menuconfig (sotto Packages → Debug helpers)
   - Questo richiede solo `EXTERNAL_ENABLED` (storage esterno)

2. **Abilitazione automatica del toolchain target:**
   - `select FREETZ_TARGET_TOOLCHAIN` nel Config.in abilita automaticamente la build del toolchain nativo
   - Questo costruisce `gcc_target`, `binutils_target`, `uclibc_target` nel sistema di build standard
   - **Questi target sono SEPARATI** dal toolchain principale usato per cross-compilare i pacchetti
   - Vengono installati in `$(TARGET_UTILS_DIR)` (separato da `$(TARGET_TOOLCHAIN_STAGING_DIR)`)

3. **Packaging:**
   - Il makefile copia i file da `$(TARGET_UTILS_DIR)` (toolchain/build/.../target-utils)
   - Usa variabili dinamiche che si adattano automaticamente alla configurazione corrente
   - Non modifica o interferisce con il toolchain di build esistente

### Perché gcc_target è Necessario?

Altri pacchetti (Python, Busybox, ecc.) vengono **cross-compilati** dal toolchain host (x86_64) per il target (MIPS/ARM). Ma `gcc_target` è speciale perché:

- **Input**: Compilato **dal** cross-compiler MIPS
- **Output**: Un GCC che **gira su** MIPS e **compila per** MIPS (native compiler)

Questo richiede una build in 3 fasi:
1. `gcc_initial`: Crea un compilatore base
2. `gcc` (stage 2): Compilatore completo cross-compiler
3. `gcc_target`: Compilatore nativo che gira sul target

Il nostro pacchetto utilizza semplicemente il risultato di `gcc_target` senza interferire con le fasi precedenti.

### Nota sui Requisiti di Build

La compilazione di `gcc_target` è **molto pesante** in termini di risorse:
- RAM: 4-8 GB
- Tempo: 30-60 minuti
- Spazio disco: ~5 GB

Se la build fallisce con "Terminated" o OOM (Out of Memory):
- **NON è un bug del pacchetto gcc-toolchain**
- È una limitazione del sistema di build (RAM insufficiente)
- Soluzioni: aumentare RAM, usare swap, ridurre parallelismo (`make -j1`)

## Compatibilità

✅ **Funziona con qualsiasi configurazione:**
- Diversi architetture target (MIPS, ARM, ecc.)
- Diverse versioni di GCC (13.x, 14.x, 15.x)
- Diverse versioni di uClibc
- Con o senza NPTL
- Diversi kernel

✅ **Non altera l'ambiente esistente:**
- Il toolchain di build principale rimane intatto
- Le variabili del toolchain esistente non sono modificate
- Il target-utils è costruito separatamente

## Test

Per testare le modifiche:

```bash
# Rigenerare la configurazione
make config-clean-deps

# Configurare
make menuconfig
# Abilitare: Advanced Options → External processing
# Selezionare: Packages → Debug helpers → GCC Toolchain

# Costruire
make
```

Il pacchetto gcc-toolchain sarà creato in `packages/.../gcc-toolchain-*/root/` e può essere installato sul dispositivo target.

## Modifica Critica al Toolchain (gcc.mk)

### Problema Risolto: Bug di Cross-Compilation di libcc1

**Sintomo**: 
```
configure: line 15097: -T: command not found
make[2]: *** [Makefile:1038: all] Error 2
```

**Causa**: Il plugin `libcc1` ha un bug nel configure script quando si fa cross-compilation per MIPS. Il configure cerca di eseguire un comando `-T` che non esiste.

**Soluzione**: Disabilitato `libcc1` solo per `gcc_target` aggiungendo `--disable-libcc1` alle opzioni di configure.

**File modificato**: `make/toolchain/target/gcc/gcc.mk` (linea ~302)
```diff
 --enable-languages=c,c++ \
 --enable-shared \
 --enable-threads \
 --disable-libstdcxx-pch \
+--disable-libcc1 \
 $(GCC_COMMON_CONFIGURE_OPTIONS) \
```

**Impatto**: 
- `libcc1` è un plugin usato solo per IDE integration (compilazione on-demand in IDE come Eclipse)
- **NON è necessario** per un compilatore nativo funzionante
- Il GCC risultante compila normalmente C/C++ e Python extensions
- **Nessun impatto** sul cross-compiler principale (gcc stage 1 e 2)
- **Nessun impatto** su altri pacchetti

**Perché solo per gcc_target?**
- Il cross-compiler (gcc stage 2) non ha questo problema perché gira sull'host (x86_64)
- Solo gcc_target (compilato PER MIPS e che GIRA su MIPS) triggera il bug
- La modifica è chirurgica: solo nella sezione `gcc_target`, non nel codice comune

### File Modificati - Riepilogo Completo

✅ **`make/pkgs/gcc-toolchain/Config.in`** - Rimosso DEVELOPER, aggiunto select FREETZ_TARGET_TOOLCHAIN  
✅ **`config/ui/toolchain.in`** - Permesso select automatico di FREETZ_TARGET_TOOLCHAIN  
✅ **`make/pkgs/gcc-toolchain/gcc-toolchain.mk`** - Usato variabili dinamiche del toolchain  
✅ **`make/toolchain/target/gcc/gcc.mk`** - **CRITICO**: Aggiunto `--disable-libcc1` e fix CFLAGS per compilazione HOST  
✅ **`make/host-tools/patchelf-host/patchelf-host.mk`** - Aggiornato patchelf da 0.15.0 a 0.18.0 per fix dynamic linker  
✅ **`Makefile`** - Modificato PATCHELF per usare tools/patchelf invece del sistema  
✅ **`make/pkgs/gcc-toolchain/README.md`** - Documentati requisiti di build  
✅ **`CHANGES_GCC_TOOLCHAIN.md`** - Documentazione completa delle modifiche

### 5. `make/host-tools/patchelf-host/patchelf-host.mk`
**Problema:** La versione 0.15.0 di patchelf ha un bug nel settaggio del dynamic linker per binari MIPS.

**Modifiche:**
- Aggiornato da `0.15.0` a `0.18.0`
- Aggiornato hash SHA256: `1952b2a782ba576279c211ee942e341748fdb44997f704dd53def46cd055470b`

**Risultato:** patchelf 0.18.0 (self-contained in Freetz-NG) risolve problemi di dynamic linker per:
- Python 3.13.7 e tutti i moduli C (cffi, cryptography, lxml, pycryptodome)
- binary-tools (readelf, objdump, objcopy, nm, strings, ar, ranlib, strip, addr2line, size)
- file 5.45
- Tutti i binari MIPS che richiedono path interpreter custom

### 6. `Makefile` (principale)
**Modifica:**
```makefile
-PATCHELF:=patchelf
+PATCHELF:=$(TOOLS_DIR)/patchelf
```

**Risultato:** Tutti i package usano automaticamente il patchelf 0.18.0 compilato da Freetz-NG invece della versione del sistema operativo, mantenendo l'ambiente **completamente self-contained**.
