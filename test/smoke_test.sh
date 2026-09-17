#!/bin/sh
set -e

echo "Checking sranime-cli syntax..."
if command -v bash >/dev/null 2>&1; then
    bash -n ./sranime-cli
fi

echo "Checking version output..."
./sranime-cli -V >/dev/null

echo "Checking help message..."
./sranime-cli -h >/dev/null

echo "All smoke tests passed!"