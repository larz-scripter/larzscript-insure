#!/bin/sh
# An unclaimed policy that reaches its expiry just lapses - the premium
# stays in the pool, it is never refunded (the deliberate opposite of
# LarzCrowd's/LarzBounty's refund-on-miss behavior).
set -e
DB="tests/data/expiry.json"
rm -f "$DB"
I="$LARZINSURE --board=$DB"

$I fund bob 100
$I create-pool "Quick Expiry Test" "n/a" 0.1
pool="$($I list | awk 'NR==3{print $2}')"
$I buy "$pool" bob 5 20 999999 --duration=1
$I balance bob
sleep 2
$I sweep
$I show "$pool"
$I balance bob
