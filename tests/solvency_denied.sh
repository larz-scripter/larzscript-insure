#!/bin/sh
# An under-capitalized pool (tiny premiums relative to coverage) must
# deny a valid, threshold-clearing claim outright rather than drain
# below what it owes its other active policies.
set -e
DB="tests/data/solvency_denied.json"
rm -f "$DB"
I="$LARZINSURE --board=$DB"

$I fund alice 100
$I fund bob 100
$I fund carol 100
$I create-pool "Flight Delay" "delay minutes >= threshold" 0.3
pool="$($I list | awk 'NR==3{print $2}')"
$I buy "$pool" alice 10 200 60 --duration=86400
apolicy="$($I show "$pool" | grep alice | awk '{print $2}')"
$I buy "$pool" bob 10 200 60 --duration=86400
$I buy "$pool" carol 10 200 60 --duration=86400
$I show "$pool"
$I claim "$pool" "$apolicy" 75
$I balance alice
