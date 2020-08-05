#!/usr/bin/env bash

set -euo pipefail

OUTFILE=dist/manage

rm -rf dist
mkdir dist

cat <<'TEXT' >> $OUTFILE
#!/usr/bin/env bash

set -euo pipefail

TEXT

cat <<'TEXT' >> $OUTFILE
#== UTILITIES ==================================================================

TEXT
cat src/lib/util.sh >> $OUTFILE

cat <<'TEXT' >> $OUTFILE

#== COMMON =====================================================================

TEXT
cat src/lib/common.sh >> $OUTFILE

cat <<'TEXT' >> $OUTFILE

#== INSTALL ====================================================================

TEXT
cat src/lib/install.sh >> $OUTFILE

cat <<'TEXT' >> $OUTFILE

#== UNINSTALL ==================================================================

TEXT
cat src/lib/uninstall.sh >> $OUTFILE

cat <<'TEXT' >> $OUTFILE

#== MAIN ======================================================================

TEXT
cat src/lib/main.sh >> $OUTFILE

cat <<'TEXT' >> $OUTFILE

main "$@"
TEXT

echo "Successfully built: $OUTFILE"
