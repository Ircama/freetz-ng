# tools 2026-09-06
  - Host-Tool: [master/make/host-tools/tools-host/](https://github.com/Freetz-NG/freetz-ng/tree/master/make/host-tools/tools-host/)
  - Steward: [@fda77](https://github.com/fda77)


This package contains almost all host tools as *precompiled* binaries, except those listed in `TOOLS_BUILD_LOCAL`.
To compile the tools yourself, `FREETZ_HOSTTOOLS_DOWNLOAD` must be disabled, for example when using an incompatible CPU without AVX support.
Compiling all tools takes about half an hour; this package avoids that build time.

