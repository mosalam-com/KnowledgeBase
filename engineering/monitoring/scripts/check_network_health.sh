#!/usr/bin/env bash
# check_network_health.sh — فحص سلامة الشبكة والنات على Proxmox
# المصدر: troubleshooting/vm-no-internet.md + proxmox-networking.md
# يجب تشغيله بصلاحيات root (iptables -t nat يتطلبها).
#
# فحص:
#   1) IP Forwarding مفعل (net.ipv4.ip_forward == 1)
#   2) قاعدة MASQUERADE للشبكة الداخلية موجودة
#   3) لا سلاسل DOCKER/DOCKER-USER (عزل Docker سليم)
#   4) default route على vmbr0 فقط (لا على docker0)

set -u

FAIL=0
WARN=0

say_ok()   { echo "[OK]   $1"; }
say_fail() { echo "[FAIL] $1"; FAIL=1; }
say_warn() { echo "[WARN] $1"; WARN=1; }

echo "== فحص الشبكة والصحة على $(hostname) - $(date) =="

# 1) IP Forwarding
FORWARD=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "0")
if [ "$FORWARD" = "1" ]; then
  say_ok "IP forwarding مفعل (net.ipv4.ip_forward=1)"
else
  say_fail "IP forwarding معطل — VM لن تخرج للإنترنت. فعّله في /etc/sysctl.conf ثم sysctl -p"
fi

# 2) قاعدة MASQUERADE (اختياري مثال للتحديث حسب شبكتك الفعلية)
if iptables -t nat -L POSTROUTING -n | grep -q "MASQUERADE" 2>/dev/null; then
  say_ok "يوجد مسكريد (NAT خروج) في POSTROUTING"
else
  say_warn "لا قاعدة MASQUERADE — لا خروج إنترنت للـ VMs إن لم يكن NAT عبر OPNsense"
fi

# 3) عزل Docker عن iptables
if iptables -t nat -L -n 2>/dev/null | grep -qE "DOCKER"; then
  say_fail "سلاسل DOCKER موجودة في iptables — Docker غير معزول؛ اضبط /etc/docker/daemon.json إلى \"iptables\": false"
else
  say_ok "لا سلاسل DOCKER — Docker معزول كما يجب"
fi

# 4) default route
DEFAULT_NIC=$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1)
if [ "${DEFAULT_NIC:-}" = "vmbr0" ]; then
  say_ok "default route على vmbr0 (الإنترنت الحقيقي)"
else
  say_fail "default route على '${DEFAULT_NIC:-غير معروف}' وليس vmbr0 — راجع الشبكات فوراً"
fi

echo
if [ "$FAIL" -eq 1 ]; then
  echo "النتيجة: FAIL — فشل فحص ثم إصلاح"
  exit 1
elif [ "$WARN" -eq 1 ]; then
  echo "النتيجة: WARN — تحذيرات لا تقطع الخدمة"
  exit 2
else
  echo "النتيجة: OK — الشبكة سليمة"
  exit 0
fi