#!/bin/bash

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"

echo "=============================================="
echo "  TIMESHEET DEVSECOPS - GRAFANA DASHBOARD"
echo "=============================================="

echo "[1/4] Recherche de la datasource Prometheus..."

PROM_UID=$(curl -fsS \
  -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
  "$GRAFANA_URL/api/datasources" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); p=[x for x in d if x.get("type")=="prometheus"]; print(p[0]["uid"] if p else "")')

if [ -z "$PROM_UID" ]; then
    echo "ERREUR: datasource Prometheus introuvable."
    exit 1
fi

echo "Prometheus UID: $PROM_UID"

echo "[2/4] Génération du dashboard..."

export PROM_UID

python3 <<'PY'
import json
import os

prom_uid = os.environ["PROM_UID"]

def datasource():
    return {
        "type": "prometheus",
        "uid": prom_uid
    }

def stat_panel(panel_id, title, expr, x, y, w=4, h=4,
               unit="short", thresholds=None):
    if thresholds is None:
        thresholds = [
            {"color": "green", "value": None},
            {"color": "red", "value": 1}
        ]

    return {
        "id": panel_id,
        "type": "stat",
        "title": title,
        "description": "Timesheet DevSecOps security metric",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": datasource(),
        "targets": [{
            "refId": "A",
            "expr": expr,
            "instant": True,
            "legendFormat": "__auto"
        }],
        "fieldConfig": {
            "defaults": {
                "unit": unit,
                "decimals": 0,
                "thresholds": {
                    "mode": "absolute",
                    "steps": thresholds
                }
            },
            "overrides": []
        },
        "options": {
            "reduceOptions": {
                "values": False,
                "calcs": ["lastNotNull"],
                "fields": ""
            },
            "orientation": "auto",
            "textMode": "auto",
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "center"
        }
    }

def gauge_panel(panel_id, title, expr, x, y, w=6, h=7):
    return {
        "id": panel_id,
        "type": "gauge",
        "title": title,
        "description": "OpenSCAP compliance",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": datasource(),
        "targets": [{
            "refId": "A",
            "expr": expr,
            "instant": True,
            "legendFormat": "Compliance"
        }],
        "fieldConfig": {
            "defaults": {
                "unit": "percent",
                "min": 0,
                "max": 100,
                "decimals": 1,
                "thresholds": {
                    "mode": "absolute",
                    "steps": [
                        {"color": "red", "value": None},
                        {"color": "orange", "value": 70},
                        {"color": "yellow", "value": 85},
                        {"color": "green", "value": 95}
                    ]
                }
            },
            "overrides": []
        },
        "options": {
            "reduceOptions": {
                "values": False,
                "calcs": ["lastNotNull"],
                "fields": ""
            },
            "showThresholdLabels": True,
            "showThresholdMarkers": True,
            "orientation": "auto"
        }
    }

def bar_panel(panel_id, title, queries, x, y, w=12, h=8):
    targets = []
    for ref, expr, legend in queries:
        targets.append({
            "refId": ref,
            "expr": expr,
            "instant": True,
            "legendFormat": legend
        })

    return {
        "id": panel_id,
        "type": "barchart",
        "title": title,
        "description": "Security findings by severity",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": datasource(),
        "targets": targets,
        "fieldConfig": {
            "defaults": {
                "unit": "short",
                "decimals": 0
            },
            "overrides": []
        },
        "options": {
            "orientation": "horizontal",
            "xTickLabelRotation": 0,
            "xTickLabelMaxLength": 0,
            "showValue": "always",
            "stacking": "none",
            "groupWidth": 0.7
        }
    }

def timeseries_panel(panel_id, title, queries, x, y, w=12, h=8):
    targets = []
    for ref, expr, legend in queries:
        targets.append({
            "refId": ref,
            "expr": expr,
            "legendFormat": legend
        })

    return {
        "id": panel_id,
        "type": "timeseries",
        "title": title,
        "description": "Timesheet security monitoring over time",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": datasource(),
        "targets": targets,
        "fieldConfig": {
            "defaults": {
                "unit": "short",
                "lineWidth": 2,
                "fillOpacity": 15,
                "showPoints": "auto"
            },
            "overrides": []
        },
        "options": {
            "legend": {
                "displayMode": "table",
                "placement": "bottom"
            },
            "tooltip": {
                "mode": "multi",
                "sort": "desc"
            }
        }
    }

def status_panel(panel_id, title, expr, x, y, w=6, h=4):
    return {
        "id": panel_id,
        "type": "stat",
        "title": title,
        "description": "Security control health",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": datasource(),
        "targets": [{
            "refId": "A",
            "expr": expr,
            "instant": True
        }],
        "fieldConfig": {
            "defaults": {
                "unit": "short",
                "decimals": 0,
                "thresholds": {
                    "mode": "absolute",
                    "steps": [
                        {"color": "red", "value": None},
                        {"color": "green", "value": 1}
                    ]
                }
            },
            "overrides": []
        },
        "options": {
            "reduceOptions": {
                "values": False,
                "calcs": ["lastNotNull"],
                "fields": ""
            },
            "colorMode": "background",
            "graphMode": "none",
            "textMode": "name",
            "justifyMode": "center"
        }
    }

panels = []

# ============================================================
# TOP KPI ROW
# ============================================================

panels.append(stat_panel(
    1, "🔥 TOTAL CVEs",
    "timesheet_threat_cves_total",
    0, 0, 4, 4,
    thresholds=[
        {"color": "green", "value": None},
        {"color": "orange", "value": 10},
        {"color": "red", "value": 50}
    ]
))

panels.append(stat_panel(
    2, "🚨 CRITICAL",
    "timesheet_threat_critical",
    4, 0, 4, 4,
    thresholds=[
        {"color": "green", "value": None},
        {"color": "orange", "value": 1},
        {"color": "red", "value": 5}
    ]
))

panels.append(stat_panel(
    3, "🟠 HIGH",
    "timesheet_threat_high",
    8, 0, 4, 4,
    thresholds=[
        {"color": "green", "value": None},
        {"color": "orange", "value": 5},
        {"color": "red", "value": 20}
    ]
))

panels.append(stat_panel(
    4, "🟡 MEDIUM",
    "timesheet_threat_medium",
    12, 0, 4, 4
))

panels.append(stat_panel(
    5, "🔵 LOW",
    "timesheet_threat_low",
    16, 0, 4, 4
))

panels.append(stat_panel(
    6, "☠️ CISA KEV",
    "timesheet_threat_cisa_kev",
    20, 0, 4, 4,
    thresholds=[
        {"color": "green", "value": None},
        {"color": "orange", "value": 1},
        {"color": "red", "value": 5}
    ]
))

# ============================================================
# THREAT INTELLIGENCE
# ============================================================

panels.append(bar_panel(
    10,
    "🔥 THREAT INTELLIGENCE — CVE SEVERITY",
    [
        ("A", "timesheet_threat_critical", "Critical"),
        ("B", "timesheet_threat_high", "High"),
        ("C", "timesheet_threat_medium", "Medium"),
        ("D", "timesheet_threat_low", "Low")
    ],
    0, 4, 12, 8
))

panels.append(stat_panel(
    11,
    "🎯 EPSS HIGH",
    "timesheet_threat_epss_high",
    12, 4, 6, 4,
    thresholds=[
        {"color": "green", "value": None},
        {"color": "orange", "value": 1},
        {"color": "red", "value": 5}
    ]
))

panels.append(stat_panel(
    12,
    "⚠️ THREAT FINDINGS",
    "timesheet_threat_finding",
    18, 4, 6, 4
))

panels.append(timeseries_panel(
    13,
    "📈 THREAT INTELLIGENCE TREND",
    [
        ("A", "timesheet_threat_cves_total", "Total CVEs"),
        ("B", "timesheet_threat_critical", "Critical"),
        ("C", "timesheet_threat_high", "High"),
        ("D", "timesheet_threat_cisa_kev", "CISA KEV")
    ],
    12, 8, 12, 8
))

# ============================================================
# OPENSCAP
# ============================================================

panels.append(gauge_panel(
    20,
    "🛡️ OPENSCAP COMPLIANCE",
    "timesheet_openscap_compliance_percent",
    0, 12, 8, 8
))

panels.append(bar_panel(
    21,
    "📋 OPENSCAP SECURITY RESULTS",
    [
        ("A", "timesheet_openscap_pass", "PASS"),
        ("B", "timesheet_openscap_fail", "FAIL"),
        ("C", "timesheet_openscap_not_applicable", "N/A"),
        ("D", "timesheet_openscap_not_selected", "NOT SELECTED")
    ],
    8, 12, 16, 8
))

# ============================================================
# FAIL2BAN
# ============================================================

panels.append(stat_panel(
    30,
    "🚫 CURRENTLY BANNED",
    "timesheet_fail2ban_currently_banned",
    0, 20, 6, 4
))

panels.append(stat_panel(
    31,
    "🔨 TOTAL BANNED",
    "timesheet_fail2ban_total_banned",
    6, 20, 6, 4
))

panels.append(stat_panel(
    32,
    "💥 FAILED ATTEMPTS",
    "timesheet_fail2ban_total_failed",
    12, 20, 6, 4
))

panels.append(status_panel(
    33,
    "🟢 FAIL2BAN SERVICE",
    "timesheet_fail2ban_service_up",
    18, 20, 6, 4
))

panels.append(timeseries_panel(
    34,
    "📊 FAIL2BAN ACTIVITY",
    [
        ("A", "timesheet_fail2ban_total_failed", "Failed"),
        ("B", "timesheet_fail2ban_total_banned", "Banned"),
        ("C", "timesheet_fail2ban_currently_banned", "Currently banned")
    ],
    0, 24, 12, 8
))

# ============================================================
# HARDENING
# ============================================================

panels.append(status_panel(
    40,
    "🔐 HARDENING SERVICE",
    "timesheet_hardening_service_up",
    12, 24, 6, 4
))

panels.append(status_panel(
    41,
    "⚙️ SYSCTL HARDENING",
    "timesheet_hardening_sysctl",
    18, 24, 6, 4
))

# ============================================================
# CHAOS ENGINEERING
# ============================================================

panels.append(stat_panel(
    50,
    "☠️ PODS TERMINATED",
    "timesheet_chaos_pods_terminated_total",
    0, 32, 6, 4
))

panels.append(stat_panel(
    51,
    "✅ SUCCESSFUL TERMINATIONS",
    "timesheet_chaos_terminations_ok_total",
    6, 32, 6, 4
))

panels.append(status_panel(
    52,
    "🧪 CHAOS DRY RUN",
    "timesheet_chaos_dry_run",
    12, 32, 6, 4
))

panels.append(timeseries_panel(
    53,
    "☠️ CHAOS ENGINEERING ACTIVITY",
    [
        ("A", "timesheet_chaos_pods_terminated_total", "Pods terminated"),
        ("B", "timesheet_chaos_terminations_ok_total", "Successful")
    ],
    18, 32, 6, 8
))

# ============================================================
# SECURITY PIPELINE
# ============================================================

panels.append(status_panel(
    60,
    "🚀 SECURITY PIPELINE",
    "timesheet_security_stage_status",
    0, 40, 12, 5
))

panels.append(timeseries_panel(
    61,
    "🚀 DEVSECOPS SECURITY MONITORING",
    [
        ("A", "timesheet_security_stage_status", "Security Stage"),
        ("B", "timesheet_hardening_service_up", "Hardening"),
        ("C", "timesheet_fail2ban_service_up", "Fail2ban")
    ],
    12, 40, 12, 8
))

# ============================================================
# DASHBOARD
# ============================================================

dashboard = {
    "id": None,
    "uid": "timesheet-devsecops-security",
    "title": "🛡️ Timesheet DevSecOps — Security Command Center",
    "description": (
        "Centralized DevSecOps security monitoring for the Timesheet project. "
        "Threat Intelligence, CVEs, CISA KEV, EPSS, OpenSCAP, Fail2ban, "
        "system hardening, Chaos Engineering and Security Pipeline."
    ),
    "tags": [
        "timesheet",
        "devsecops",
        "security",
        "threat-intelligence",
        "openscap",
        "fail2ban",
        "chaos-engineering"
    ],
    "timezone": "browser",
    "schemaVersion": 39,
    "version": 1,
    "refresh": "30s",
    "time": {
        "from": "now-6h",
        "to": "now"
    },
    "templating": {
        "list": []
    },
    "annotations": {
        "list": []
    },
    "panels": panels
}

payload = {
    "dashboard": dashboard,
    "folderId": 0,
    "overwrite": True,
    "message": "Created Timesheet DevSecOps Security Command Center automatically"
}

with open("timesheet-security-dashboard.json", "w") as f:
    json.dump(payload, f, indent=2)

print("Dashboard JSON generated.")
print(f"Panels: {len(panels)}")
PY

echo "[3/4] Import du dashboard dans Grafana..."

HTTP_CODE=$(curl -s -o /tmp/grafana-response.json -w "%{http_code}" \
  -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
  --data-binary @timesheet-security-dashboard.json)

echo "HTTP: $HTTP_CODE"

if [ "$HTTP_CODE" != "200" ]; then
    echo ""
    echo "ERREUR Grafana:"
    cat /tmp/grafana-response.json
    echo ""
    exit 1
fi

echo "[4/4] Dashboard créé avec succès."
echo ""
cat /tmp/grafana-response.json

echo ""
echo "=============================================="
echo "       ✅ DASHBOARD READY"
echo "=============================================="
echo ""
echo "URL:"
echo "$GRAFANA_URL/d/timesheet-devsecops-security"
echo ""
echo "Ouvre:"
echo "$GRAFANA_URL/d/timesheet-devsecops-security"
echo ""
