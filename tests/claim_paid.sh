#!/bin/sh
# A properly-capitalized pool pays a valid claim in full, and correctly
# rejects one that doesn't clear the threshold.
set -e
DB="tests/data/claim_paid.json"
rm -f "$DB"
I="$LARZINSURE --board=$DB"

$I fund alice 100
$I fund bob 100
$I fund carol 100
$I create-pool "Crop Rainfall" "rainfall inches >= threshold" 0.2
pool="$($I list | awk 'NR==3{print $2}')"
$I buy "$pool" alice 50 60 10 --duration=86400
$I buy "$pool" bob 50 60 10 --duration=86400
$I buy "$pool" carol 50 60 10 --duration=86400
cpolicy="$($I show "$pool" | grep carol | awk '{print $2}')"
bpolicy="$($I show "$pool" | grep bob | awk '{print $2}')"
$I show "$pool"
$I claim "$pool" "$cpolicy" 15
$I balance carol
$I show "$pool"
echo "--- below-threshold claim on a still-active policy ---"
$I claim "$pool" "$bpolicy" 5
echo "--- re-claiming an already-claimed policy ---"
$I claim "$pool" "$cpolicy" 15
