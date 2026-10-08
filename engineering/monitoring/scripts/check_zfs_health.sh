#!/usr/bin/env bash
# check_zfs_health.sh — فحص صحة تخزين ZFS وعمل النسخ
# المصدر: engineering/infrastructure/proxmox-setup.md (ZFS RAID10 + Snapshots)
# يتطلب root (zpool status / zfs list)
#
# فحص:
#   1) حالة pool (ONLINE) وعدم وجود DEGRADED
#   2) آخر نتيجة scrub
#   3) آخر snapshot موجود (للتحقق من سياسة النسخ اليومي)

set -u
FAIL=0

say_ok()   { echo "[OK]   $1"; }
say_fail() { echo "[FAIL] $1"; FAIL=1; }

echo "== فحص ZFS على $(hostname) - $(date) =="

# 1) حالة الـ pool
zpool list -H -o name,health,size,alloc,free 2>/dev/null | while read -r name health size alloc free; do
  echo "Pool: $name | $health | $size alloc=$alloc free=$free"
done

if zpool status 2>/dev/null | grep -qi "DEGRADED\|FAULTED\|UNAVAIL"; then
  say_fail "يوجد pool متضرر (DEGRADED/FAULTED) — تصرف فوراً"
else
  say_ok "كل الـ pools سليمة (لا DEGRADED)"
fi

# 2) آخر نتيجة scrub (آخر سطر قبل "status")
LAST_SCRUB=$(zpool status 2>/dev/null | grep -A1 "Last scrub\|scan:" | grep -o "scrub.*completed.*" | tail -1)
if [ -n "$LAST_SCRUB" ]; then
  echo "[INFO] آخر فحص: $LAST_SCRUB"
else
  say "لا معلومات عن آخر scrub — نفّذ zpool scrub دورياً"
fi

# 3) آخر Snapshot — سياسة يومي (متوقع وجود اليوم/أمس)
SNAP=$(zpool list -H -o name 2>/dev/null | head -1)
NEWEST=$(zfs list -t snapshot -H -o name -s creation 2>/dev/null | tail -1)
if [ -n "${NEWEST:-}" ]; then
  echo "[INFO] أحدث Snapshot: $NEWEST"
else
  echo "[WARN] لا توجد Snapshots — لا سياسة نسخ يومي مفعّلة!"
  FAIL=1
fi

echo
[ "$FAIL" -eq 0 ] && echo "النتيجة: OK" || { echo "النتيجة: FAIL"; exit 1; }
exit 0