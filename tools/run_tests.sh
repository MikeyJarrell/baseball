#!/bin/bash
# Runs the game-logic tests (rules, stats, storage, box score text, team loading).
# Used as the check before a task is accepted with /done.
set -euo pipefail
cd "$(dirname "$0")/../app/Packages/ScorebookCore"
swift test
