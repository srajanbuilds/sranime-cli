#!/bin/sh
set -e

echo "[1/6] Checking sranime-cli syntax..."
if command -v bash >/dev/null 2>&1; then
    bash -n ./sranime-cli
    bash -n ./_sranime-cli-bash
    bash -n ./completions/sranime-cli.bash
fi

echo "[2/6] Checking executable bit..."
[ -x "./sranime-cli" ] || (echo "Error: ./sranime-cli is not executable" && exit 1)

echo "[3/6] Checking version and help outputs..."
./sranime-cli -V >/dev/null
./sranime-cli --version >/dev/null
./sranime-cli -h >/dev/null
./sranime-cli --help >/dev/null

echo "[4/6] Checking configuration loading..."
tmp_conf=$(mktemp 2>/dev/null || echo "/tmp/test_sranime.conf")
printf 'quality="720p"\nmode="dub"\n' > "$tmp_conf"
SRANIME_CLI_CONFIG="$tmp_conf" ./sranime-cli -V >/dev/null
rm -f "$tmp_conf"

echo "[5/6] Verifying no awk or wget in script (CI compliance)..."
! grep -w awk "./sranime-cli"
! grep -w wget "./sranime-cli"

echo "[6/6] Checking Makefile dry-run..."
if command -v make >/dev/null 2>&1; then
    make -n install >/dev/null
fi

echo "All smoke tests passed successfully!"
