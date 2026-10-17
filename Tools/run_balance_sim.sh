#!/bin/sh
# Builds the game's pure-Swift Models + Engine for macOS together with a
# greedy AI player, then simulates every map. Useful after tuning numbers.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/bastion-balance-sim"
xcrun swiftc -O -swift-version 5 \
  $(ls "$ROOT"/TowerDefense/Models/*.swift | grep -v PlayerProgress.swift | grep -v Medals.swift) \
  "$ROOT"/TowerDefense/Engine/*.swift \
  "$ROOT"/Tools/BalanceSim/main.swift \
  -o "$OUT"
"$OUT"
