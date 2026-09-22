#!/usr/bin/env bash
# §11.11: "a ban on DateTime.now() outside zen_app (enforced with a custom lint
# or a CI grep)". This is the CI grep. A custom lint would be more precise, but
# §11.13's standing instructions prefer deleting code to adding configuration,
# and this is twenty lines with no dependency.
#
# zen_domain enforces the same rule as a unit test as well, so the constraint
# fails locally too (packages/zen_domain/test/architecture_test.dart).
#
# Comment lines are skipped: doc comments legitimately name the construct they
# forbid, and the first run of this script flagged its own prose.

set -uo pipefail

cd "$(dirname "$0")/.."

violations=0
for package in zen_domain zen_data zen_sync; do
  hits="$(grep -rn --include='*.dart' 'DateTime\.now()' "packages/$package/lib" 2>/dev/null \
    | grep -vE ':[0-9]+:[[:space:]]*(//|\*)' || true)"

  if [ -n "$hits" ]; then
    echo "$hits"
    echo "ERROR: DateTime.now() is banned in $package (§11.11)." >&2
    echo "       Take the instant as a parameter, or inject a Clock (§11.4.3)." >&2
    violations=1
  fi
done

if [ "$violations" -ne 0 ]; then
  exit 1
fi

echo "OK: no DateTime.now() outside zen_app (§11.11)."
