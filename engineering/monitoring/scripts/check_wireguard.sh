#!/usr/bin/env bash
# check_wireguard.sh — فحص اتصال VPN الداخلي (WireGuard)
# المصدر: engineering/networking/wireguard-vpn.md + troubleshooting
# فحص: وجود interface wg0 + وجود Handshake (لأي Peer نشط)
#
# ملاحظة: Monitored عبر cron — عند تكرار الفشل راجع wg0.conf و PostUp/NAT rules.

set -u
FAIL=0
say_ok()   { echo "[OK]   $1"; }
say_fail() { echo "[FAIL] $1"; FAIL=1; }

echo "== فحص WireGuard على $(hostname) - $(date) =="

# 1) Interface wg0 موجود وعامل؟
if ip link show wg0 >/dev/null 2>&1; then
  state=$(ip link show wg0 | grep -o "state [A-Z]*")
  say_ok "interface wg0 موجود ($state)"
else
  say_fail "interface wg0 غير موجود — شغّله: wg-quick up wg0"
  echo "النتيجة: FAIL"; exit 1
fi

# 2) هل يوجد Peer على اتصال (Handshake)؟
if wg show wg0 latest-handshakes 2>/dev/null | grep -q "\s[1-9]"; then
  say_ok "يوجد Peer ذو Handshake حديثة (الاتصال VPN شغال)"
else
  say_fail "لا يوجد Peer متصل — العميل غير مربوط حالياً أو مشكلة في Endpoint/Firewall (UDP 51820)"
fi

# 3) المنفذ يستمع؟
if ss -ulnp 2>/dev/null | grep -q ":51820"; then
  say_ok "المنفذ 51820/UDP يستمع على السيرفر"
else
  say_fail "51820/UDP غير مفتوح — تأكد من wireguard ومن Hetzner Firewall"
fi

echo
[ "$FAIL" -eq 0 ] && echo "النتيجة: OK" || { echo "النتيجة: FAIL"; exit 1; }
exit 0