#!/usr/bin/env bash
# Transforme les rapports de securite en metriques Prometheus (format texte).
set -u
D="${REPORTS_DIR:-/var/lib/jenkins/workspace/Timesheet-CI-CD}"
mkdir -p "$D/metrics-results"
OUT="${OUT:-$D/metrics-results/timesheet-security.prom}"
F2B="$D/fail2ban-results/fail2ban-report.txt"
HARD="$D/ansible-results/server-hardening-report.txt"
SCAP="$D/openscap-results/openscap-summary.txt"
CHAOS="$D/chaos-results/kube-monkey-report.txt"
: > "$OUT.tmp"
m() { echo "$@" >> "$OUT.tmp"; }
num() { grep -m1 -E "$1" "$2" 2>/dev/null | grep -oE '[0-9]+' | tail -1; }
sec() { awk -v s="$1" '$0==s{f=1;next} /^\[/{f=0} f&&NF{print;exit}' "$2" 2>/dev/null; }
ok() { [ "$1" = "active" ] && echo 1 || echo 0; }

# ---------- Fail2Ban ----------
if [ -f "$F2B" ]; then
  m "timesheet_fail2ban_service_up $(ok "$(sec '[1] Fail2Ban service status' "$F2B")")"
  m "timesheet_fail2ban_jails $(num 'Number of jail' "$F2B")"
  m "timesheet_fail2ban_currently_banned{jail=\"jenkins\"} $(num 'Currently banned' "$F2B")"
  m "timesheet_fail2ban_total_banned{jail=\"jenkins\"} $(num 'Total banned' "$F2B")"
  m "timesheet_fail2ban_total_failed{jail=\"jenkins\"} $(num 'Total failed' "$F2B")"
  grep -q "successful" "$F2B" && v=1 || v=0
  m "timesheet_security_stage_status{stage=\"fail2ban\"} $v"
fi

# ---------- Ansible hardening ----------
if [ -f "$HARD" ]; then
  for c in DOCKER JENKINS AUDITD; do
    m "timesheet_hardening_service_up{service=\"$(echo $c | tr A-Z a-z)\"} $(ok "$(sec "[$c]" "$HARD")")"
  done
  grep -q "apparmor module is loaded" "$HARD" && v=1 || v=0
  m "timesheet_hardening_service_up{service=\"apparmor\"} $v"
  grep -E '^net\.ipv4\.[a-z_.]+ = [0-9]+' "$HARD" | while read -r k _ val; do
    m "timesheet_hardening_sysctl{key=\"$k\"} $val"
  done
  grep -q "COMPLETED" "$HARD" && v=1 || v=0
  m "timesheet_security_stage_status{stage=\"ansible\"} $v"
fi

# ---------- OpenSCAP ----------
if [ -f "$SCAP" ]; then
  P=$(num '^PASS' "$SCAP"); Fl=$(num '^FAIL' "$SCAP")
  m "timesheet_openscap_pass $P"
  m "timesheet_openscap_fail $Fl"
  m "timesheet_openscap_not_applicable $(num '^NOT APPLICABLE' "$SCAP")"
  m "timesheet_openscap_not_selected $(num '^NOT SELECTED' "$SCAP")"
  m "timesheet_openscap_compliance_percent $(awk -v p="$P" -v f="$Fl" 'BEGIN{t=p+f; printf "%.1f", t?100*p/t:0}')"
  grep -q "SCAN COMPLETED" "$SCAP" && v=1 || v=0
  m "timesheet_security_stage_status{stage=\"openscap\"} $v"
fi

# ---------- Chaos (kube-monkey) ----------
if [ -f "$CHAOS" ]; then
  m "timesheet_chaos_pods_terminated_total $(grep -c 'Terminated pod' "$CHAOS")"
  m "timesheet_chaos_terminations_ok_total $(grep -c 'Termination successfully executed' "$CHAOS")"
  grep -q "DryRun" "$CHAOS" && v=1 || v=0
  m "timesheet_chaos_dry_run $v"
  m "timesheet_security_stage_status{stage=\"chaos\"} 1"
fi

mv "$OUT.tmp" "$OUT"
if [ -n "${PUSHGATEWAY:-}" ]; then
  curl -s --data-binary @"$OUT" "$PUSHGATEWAY/metrics/job/timesheet-security-reports" && echo "pushed"
fi
cat "$OUT"
