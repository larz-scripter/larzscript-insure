#!/bin/sh
# A narrated walkthrough - two pools with very different economics. One
# is dangerously under-capitalized (tiny premiums against large coverage)
# and correctly DENIES a real, threshold-clearing claim to protect its
# other policyholders. The other is properly capitalized and pays a
# claim out in full. Run from the repo root: sh examples/demo.sh
set -e
DB="/tmp/larzinsure-demo-$$.json"
rm -f "$DB"
LARZINSURE="larzscript bin/larzinsure.lz --board=$DB"

echo "--- fund three policyholders (demo-only faucet) ---"
$LARZINSURE fund alice 100
$LARZINSURE fund bob 100
$LARZINSURE fund carol 100

echo "--- pool 1: Flight Delay, badly under-capitalized (\$10 premium vs \$200 coverage) ---"
$LARZINSURE create-pool "Flight Delay" "delay minutes >= threshold" 0.3
p1="$($LARZINSURE list | awk 'NR==3{print $2}')"
$LARZINSURE buy "$p1" alice 10 200 60 --duration=86400
a1="$($LARZINSURE show "$p1" | grep alice | awk '{print $2}')"
$LARZINSURE buy "$p1" bob 10 200 60 --duration=86400
$LARZINSURE buy "$p1" carol 10 200 60 --duration=86400
$LARZINSURE show "$p1"

echo "--- alice's flight really was delayed 75 minutes - a real, valid claim ---"
$LARZINSURE claim "$p1" "$a1" 75
echo "--- but the pool denies it: paying out would breach the solvency floor ---"
$LARZINSURE balance alice

echo
echo "--- pool 2: Crop Rainfall, properly capitalized (\$50 premium vs \$60 coverage) ---"
$LARZINSURE create-pool "Crop Rainfall" "rainfall inches >= threshold" 0.2
p2="$($LARZINSURE list | awk 'NR==4{print $2}')"
$LARZINSURE buy "$p2" alice 50 60 10 --duration=86400
$LARZINSURE buy "$p2" bob 50 60 10 --duration=86400
$LARZINSURE buy "$p2" carol 50 60 10 --duration=86400
c2="$($LARZINSURE show "$p2" | grep carol | awk '{print $2}')"
$LARZINSURE show "$p2"

echo "--- carol's rainfall reading really did clear the threshold ---"
$LARZINSURE claim "$p2" "$c2" 15
echo "--- this pool can afford it: claim pays out in full ---"
$LARZINSURE balance carol
$LARZINSURE show "$p2"

rm -f "$DB"
