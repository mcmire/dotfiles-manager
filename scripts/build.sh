#!/usr/bin/env bash

set -euo pipefail

rm -rf build
mkdir build

cat <<'TEXT' >> build/manage
#!/usr/bin/env bash

set -euo pipefail

TEXT

cat <<'TEXT' >> build/manage
#== UTILITIES ==================================================================

TEXT
cat src/lib/util.sh >> build/manage

cat <<'TEXT' >> build/manage
#== COMMON =====================================================================

TEXT
cat src/lib/common.sh >> build/manage

cat <<'TEXT' >> build/manage
#== INSTALL ====================================================================

TEXT
cat src/lib/install.sh >> build/manage

cat <<'TEXT' >> build/manage
#== UNINSTALL ==================================================================

TEXT
cat src/lib/uninstall.sh >> build/manage

cat <<'TEXT' >> build/manage
#== MAIN ======================================================================

TEXT
cat src/lib/main.sh >> build/manage

cat <<'TEXT' >> build/manage

main "$@"
TEXT
