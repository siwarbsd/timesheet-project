pipeline {
    agent any

    stages {

        stage('CHECKOUT') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/siwarbsd/timesheet-project.git'
            }
        }





        stage('CLEAN') {
            steps {
                sh 'mvn clean'
            }
        }

        stage('COMPILE') {
            steps {
                sh 'mvn compile'
            }
        }

        stage('TEST') {
            steps {
                sh 'mvn test'
            }
        }
       stage('OWASP DEPENDENCY-CHECK') {
    steps {
        withCredentials([string(
            credentialsId: 'nvd-api-key',
            variable: 'NVD_API_KEY'
        )]) {
            sh '''
                NVD_OPTION="-Dnvd.api.key"
		mvn org.owasp:dependency-check-maven:check "$NVD_OPTION=$NVD_API_KEY" -Dformats=HTML,JSON
            '''
        }
    }
}

       stage('OWASP REPORT') {
    steps {
        publishHTML([
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'target',
            reportFiles: 'dependency-check-report.html',
            reportName: 'OWASP Dependency-Check Report'
        ])
    }
}
        stage('THREAT INTELLIGENCE - CISA KEV + EPSS') {
            steps {
                sh '''
                    set -e

                    mkdir -p threat-intel-results

                    OWASP_JSON="target/dependency-check-report.json"
                    CISA_KEV="threat-intel-results/cisa-kev.json"
                    EPSS_JSON="threat-intel-results/epss.json"
                    REPORT="threat-intel-results/threat-intel-report.json"
                    SUMMARY="threat-intel-results/threat-intel-summary.txt"

                    echo "========================================"
                    echo "     THREAT INTELLIGENCE - CISA KEV + EPSS"
                    echo "========================================"

                    echo ""
                    echo "[1] OWASP JSON"

                    test -s "$OWASP_JSON" || {
                        echo "ERROR: rapport OWASP JSON introuvable : $OWASP_JSON"
                        exit 1
                    }

                    echo "OWASP Dependency-Check JSON : OK"

                    echo ""
                    echo "[2] CISA KEV"

                    curl -4 --retry 3 --retry-delay 2 -fsSL \
                        "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json" \
                        -o "$CISA_KEV"

                    test -s "$CISA_KEV" || {
                        echo "ERROR: catalogue CISA KEV non récupéré"
                        exit 1
                    }

                    echo "CISA KEV : OK"

                    echo ""
                    echo "[3] EXTRACTION DES CVE"

                    python3 - "$OWASP_JSON" "$CISA_KEV" "threat-intel-results/cves.txt" <<'PYCVES'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    owasp = json.load(f)

with open(sys.argv[2], encoding="utf-8") as f:
    cisa = json.load(f)

cves = set()

for dependency in owasp.get("dependencies", []):
    for vulnerability in dependency.get("vulnerabilities", []) or []:
        cve = vulnerability.get("name", "")
        if re.fullmatch(r"CVE-[0-9]{4}-[0-9]{4,}", cve):
            cves.add(cve)

cisa_cves = {
    item.get("cveID")
    for item in cisa.get("vulnerabilities", [])
    if item.get("cveID")
}

with open(sys.argv[3], "w", encoding="utf-8") as f:
    for cve in sorted(cves):
        f.write(cve + "\\n")

print(f"CVE OWASP détectées : {len(cves)}")
print(f"CVE présentes dans CISA KEV : {len(cves & cisa_cves)}")
PYCVES

                    CVE_COUNT=$(wc -l < threat-intel-results/cves.txt)

                    echo "CVE détectées : $CVE_COUNT"

                    if [ "$CVE_COUNT" -eq 0 ]; then
                        echo '{"status":"OK","vulnerabilities":[]}' > "$REPORT"
                        echo "Aucune CVE à enrichir." > "$SUMMARY"
                        echo "Threat Intelligence : SCAN COMPLETED"
                        exit 0
                    fi

                    echo ""
                    echo "[4] EPSS"

                    : > "$EPSS_JSON"

                    rm -f threat-intel-results/cve-batch-*

                    split -l 100 \
                        threat-intel-results/cves.txt \
                        threat-intel-results/cve-batch-

                    for batch in threat-intel-results/cve-batch-??; do
                        CVE_LIST=$(paste -sd, "$batch")

                        curl -4 --retry 3 --retry-delay 2 -fsSLG \
                            --data-urlencode "cve=$CVE_LIST" \
                            "https://api.first.org/data/v1/epss" \
                            > "${batch}.json"
                    done

                    python3 - "$EPSS_JSON" <<'PYTHON'
import glob
import json
import sys

output = {
    "status": "OK",
    "status-code": 200,
    "version": "1.0",
    "access": "public",
    "total": 0,
    "offset": 0,
    "limit": 100,
    "data": []
}

for filename in sorted(glob.glob("threat-intel-results/cve-batch-*.json")):
    with open(filename, encoding="utf-8") as f:
        data = json.load(f)

    output["data"].extend(data.get("data", []))

output["total"] = len(output["data"])

with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(output, f)

print(f"EPSS entries merged : {output['total']}")
PYTHON

                    rm -f threat-intel-results/cve-batch-* \
                          threat-intel-results/cves.txt

                    echo "EPSS : OK"

                    echo ""
                    echo "[5] CORRELATION CISA KEV + EPSS"

                    python3 - "$OWASP_JSON" "$CISA_KEV" "$EPSS_JSON" "$REPORT" "$SUMMARY" <<'PYCORRELATION'
import json
import sys

owasp_file = sys.argv[1]
cisa_file = sys.argv[2]
epss_file = sys.argv[3]
report_file = sys.argv[4]
summary_file = sys.argv[5]

with open(owasp_file, encoding="utf-8") as f:
    owasp = json.load(f)

with open(cisa_file, encoding="utf-8") as f:
    cisa = json.load(f)

cisa_map = {
    item.get("cveID"): item
    for item in cisa.get("vulnerabilities", [])
    if item.get("cveID")
}

epss_map = {}

with open(epss_file, encoding="utf-8") as f:
    for line in f:
        if not line.strip():
            continue
        try:
            data = json.loads(line)
            for item in data.get("data", []):
                epss_map[item.get("cve")] = item
        except json.JSONDecodeError:
            pass

findings = {}

for dependency in owasp.get("dependencies", []):
    for vulnerability in dependency.get("vulnerabilities", []) or []:
        cve = vulnerability.get("name")

        if not cve:
            continue

        cvss = vulnerability.get("cvssv3") or {}

        finding = findings.setdefault(cve, {
            "cve": cve,
            "severity": vulnerability.get("severity"),
            "cvss": cvss.get("baseScore"),
            "description": vulnerability.get("description"),
            "kev": False,
            "kev_date_added": None,
            "kev_due_date": None,
            "kev_vendor": None,
            "kev_product": None,
            "epss": None,
            "epss_percentile": None
        })

        if vulnerability.get("severity"):
            finding["severity"] = vulnerability.get("severity")

        if cvss.get("baseScore") is not None:
            finding["cvss"] = cvss.get("baseScore")

for cve, finding in findings.items():
    kev = cisa_map.get(cve)

    if kev:
        finding["kev"] = True
        finding["kev_date_added"] = kev.get("dateAdded")
        finding["kev_due_date"] = kev.get("dueDate")
        finding["kev_vendor"] = kev.get("vendorProject")
        finding["kev_product"] = kev.get("product")

    epss = epss_map.get(cve)

    if epss:
        try:
            finding["epss"] = float(epss.get("epss"))
        except (TypeError, ValueError):
            pass

        try:
            finding["epss_percentile"] = float(epss.get("percentile"))
        except (TypeError, ValueError):
            pass

def get_priority(item):
    if item["kev"]:
        return "CRITICAL"

    if item["epss"] is not None and item["epss"] >= 0.70:
        return "HIGH"

    if item["epss"] is not None and item["epss"] >= 0.30:
        return "MEDIUM"

    return "LOW"

for item in findings.values():
    item["priority"] = get_priority(item)

items = sorted(
    findings.values(),
    key=lambda x: (
        {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}[x["priority"]],
        -(x["epss"] or 0)
    )
)

summary = {
    "total_cves": len(items),
    "cisa_kev": sum(1 for x in items if x["kev"]),
    "epss_high": sum(
        1 for x in items
        if x["epss"] is not None and x["epss"] >= 0.70
    ),
    "critical": sum(1 for x in items if x["priority"] == "CRITICAL"),
    "high": sum(1 for x in items if x["priority"] == "HIGH"),
    "medium": sum(1 for x in items if x["priority"] == "MEDIUM"),
    "low": sum(1 for x in items if x["priority"] == "LOW")
}

result = {
    "status": "OK",
    "sources": {
        "owasp_dependency_check": True,
        "cisa_kev": True,
        "epss": True
    },
    "summary": summary,
    "vulnerabilities": items
}

with open(report_file, "w", encoding="utf-8") as f:
    json.dump(result, f, indent=2)

with open(summary_file, "w", encoding="utf-8") as f:
    f.write("========================================\\n")
    f.write("     THREAT INTELLIGENCE REPORT\\n")
    f.write("========================================\\n\\n")
    f.write(f"Total CVE       : {summary['total_cves']}\\n")
    f.write(f"CISA KEV        : {summary['cisa_kev']}\\n")
    f.write(f"EPSS >= 0.70    : {summary['epss_high']}\\n")
    f.write(f"CRITICAL        : {summary['critical']}\\n")
    f.write(f"HIGH            : {summary['high']}\\n")
    f.write(f"MEDIUM          : {summary['medium']}\\n")
    f.write(f"LOW             : {summary['low']}\\n\\n")

    f.write("TOP PRIORITY VULNERABILITIES\\n")
    f.write("-----------------------------\\n")

    for item in items[:20]:
        f.write(
            f"{item['cve']} | "
            f"priority={item['priority']} | "
            f"severity={item['severity']} | "
            f"cvss={item['cvss']} | "
            f"epss={item['epss']} | "
            f"KEV={item['kev']}\\n"
        )
PYCORRELATION

                    cat "$SUMMARY"

                    echo ""
                    echo "Rapport JSON : $REPORT"
                    echo "Résumé : $SUMMARY"
                    echo ""
                    echo "Threat Intelligence : SCAN COMPLETED"

                    echo ""
                    echo "[6] PUSHGATEWAY - PROMETHEUS"

                    python3 - "$REPORT" > threat-intel-results/threat-intel.prom <<'PYMETRICS'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    report = json.load(f)

summary = report.get("summary", {})
vulnerabilities = report.get("vulnerabilities", [])

print("# TYPE timesheet_threat_cves_total gauge")
print(f"timesheet_threat_cves_total {summary.get('total_cves', 0)}")

print("# TYPE timesheet_threat_cisa_kev gauge")
print(f"timesheet_threat_cisa_kev {summary.get('cisa_kev', 0)}")

print("# TYPE timesheet_threat_epss_high gauge")
print(f"timesheet_threat_epss_high {summary.get('epss_high', 0)}")

print("# TYPE timesheet_threat_critical gauge")
print(f"timesheet_threat_critical {summary.get('critical', 0)}")

print("# TYPE timesheet_threat_high gauge")
print(f"timesheet_threat_high {summary.get('high', 0)}")

print("# TYPE timesheet_threat_medium gauge")
print(f"timesheet_threat_medium {summary.get('medium', 0)}")

print("# TYPE timesheet_threat_low gauge")
print(f"timesheet_threat_low {summary.get('low', 0)}")

print("# TYPE timesheet_threat_finding gauge")

for item in vulnerabilities[:10]:
    cve = item.get("cve")
    epss = item.get("epss")
    priority = item.get("priority", "LOW")
    severity = item.get("severity") or "UNKNOWN"
    kev = str(item.get("kev", False)).lower()

    if not cve or epss is None:
        continue

    print(
        f'timesheet_threat_finding{{cve="{cve}",priority="{priority}",severity="{severity}",kev="{kev}"}} {float(epss)}'
    )
PYMETRICS

                    cat threat-intel-results/threat-intel.prom

                    curl -fsS \
                        --data-binary @threat-intel-results/threat-intel.prom \
                        http://192.168.203.161:9091/metrics/job/timesheet-threat-intelligence

                    echo "Threat Intelligence : METRICS PUSHED TO PROMETHEUS"
                '''
              }

              post {
                  always {
                      archiveArtifacts artifacts: 'threat-intel-results/**',
                                       allowEmptyArchive: false,
                                       fingerprint: true
                  }
              }
          }

        stage('SONARQUBE') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'mvn sonar:sonar'
                }
            }
        }

        stage('PACKAGE') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }

        stage('NEXUS') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_SECRET'
                )]) {
                    sh '''
                        cat > settings-nexus.xml <<EOF
<settings>
    <servers>
        <server>
            <id>nexus</id>
            <username>${NEXUS_USER}</username>
            <password>${NEXUS_SECRET}</password>
        </server>
    </servers>
</settings>
EOF

                        mvn deploy -DskipTests -s settings-nexus.xml

                        rm -f settings-nexus.xml
                    '''
                }
            }
        }

        stage('DOCKER BUILD') {
            steps {
                sh 'docker build -t siwarbessoud/timesheet-devops:1.0.13 .'
            }
        }

        stage('DOCKER PUSH') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_TOKEN'
                )]) {
                    sh '''
                        echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push siwarbessoud/timesheet-devops:1.0.13
                        docker logout
                    '''
                }
            }
          }
        stage('DOCKER SECRET') {
            steps {
                sh '''
                    set +x

                    REPORT="docker-secret-report.txt"

                    echo "========================================" > "$REPORT"
                    echo "          DOCKER SECRET REPORT" >> "$REPORT"
                    echo "========================================" >> "$REPORT"
                    echo "" >> "$REPORT"

                    echo "[1] Docker Swarm" >> "$REPORT"
                    docker info --format 'Swarm state: {{.Swarm.LocalNodeState}}' >> "$REPORT"
                    echo "" >> "$REPORT"

                    echo "[2] Docker Secret" >> "$REPORT"
                    if docker secret inspect timesheet_db_password >/dev/null 2>&1; then
                        echo "Secret: timesheet_db_password" >> "$REPORT"
                        echo "Status: PRESENT" >> "$REPORT"
                    else
                        echo "ERROR: Docker Secret not found." >> "$REPORT"
                        exit 1
                    fi
                    echo "" >> "$REPORT"

                    echo "[3] Secret Injection" >> "$REPORT"
                    docker service ls \
                        --filter name=timesheet-secret-test >> "$REPORT"
                    echo "" >> "$REPORT"

                    echo "[4] Secret Mount" >> "$REPORT"
                    docker service logs timesheet-secret-test 2>&1 \
                        | tail -20 >> "$REPORT"
                    echo "" >> "$REPORT"

                    echo "[5] Service Status" >> "$REPORT"
                    docker service ps timesheet-secret-test >> "$REPORT"
                    echo "" >> "$REPORT"

                    echo "[6] Security Verification" >> "$REPORT"
                    echo "Secret value is not exposed in this report." >> "$REPORT"
                    echo "Secret is mounted through /run/secrets/." >> "$REPORT"
                    echo "" >> "$REPORT"

                    echo "========================================" >> "$REPORT"
                    echo "RESULT: Docker Secret validation successful." >> "$REPORT"
                    echo "========================================" >> "$REPORT"
                '''
            }

            post {
                always {
                    archiveArtifacts artifacts: 'docker-secret-report.txt',
                                     allowEmptyArchive: false,
                                     fingerprint: true
                }
            }
        }
stage('VAULT → KUBERNETES SECRET') {
steps {
withVault([
configuration: [
    vaultUrl: 'http://127.0.0.1:8200',
    vaultCredentialId: 'vault-timesheet'
],
vaultSecrets: [[
path: 'secret/timesheet',
engineVersion: 2,
secretValues: [
[envVar: 'MYSQL_USERNAME', vaultKey: 'mysql_username'],
[envVar: 'MYSQL_PASSWORD', vaultKey: 'mysql_password']
]
]]
]) {
sh '''
set +x


            kubectl create secret generic timesheet-secret \
                -n chap4 \
                --from-literal=DB_USER="$MYSQL_USERNAME" \
                --from-literal=DB_PASSWORD="$MYSQL_PASSWORD" \
                --dry-run=client \
                -o yaml | kubectl apply -f -

            echo "Kubernetes Secret synchronisé depuis HashiCorp Vault."
        '''
    }
}

}

        stage('KUBERNETES DEPLOY') {
            steps {
                sh '''
                    kubectl apply -f timesheet-deployment.yml
                '''
            }
        }

        stage('KUBERNETES VERIFICATION') {
            steps {
                sh '''
                    kubectl rollout status deployment/timesheet-dep -n chap4
                    kubectl get pods -n chap4
                    kubectl get deployments -n chap4
                '''
            }
        }
stage('SECURITY SMOKE TESTS') {
    steps {
        sh '''
            set +x

            NMAP_REPORT="nmap-security-report.txt"
            ZAP_HTML="zap-baseline-report.html"
            ZAP_JSON="zap-baseline-report.json"

            echo "========================================" > "$NMAP_REPORT"
            echo "       NMAP SECURITY SMOKE TEST" >> "$NMAP_REPORT"
            echo "========================================" >> "$NMAP_REPORT"
            echo "" >> "$NMAP_REPORT"

            echo "Waiting for rollout..."
            kubectl -n chap4 rollout status deploy/timesheet-dep --timeout=300s
            for i in $(seq 1 90); do
                if kubectl -n chap4 logs deploy/timesheet-dep 2>/dev/null | grep -q "Started "; then
                    echo "Spring Boot started."
                    break
                fi
                sleep 2
            done
            echo "Starting Kubernetes port-forward..."

            kubectl port-forward -n chap4 svc/timesheet-serv 18080:8080 \
                > /tmp/timesheet-port-forward.log 2>&1 &
            PF_PID=$!

            cleanup() {
                kill "$PF_PID" 2>/dev/null || true
            }
            trap cleanup EXIT

            echo "Waiting for application on port 18080..."

            APP_READY=false

            for i in $(seq 1 60); do

                if ! kill -0 "$PF_PID" 2>/dev/null; then
                    echo "ERROR: port-forward process stopped unexpectedly."
                    cat /tmp/timesheet-port-forward.log
                    exit 1
                fi

                if curl -s -m 3 http://127.0.0.1:18080 >/dev/null 2>&1; then
                    echo "Application is reachable on port 18080."
                    APP_READY=true
                    break
                fi

                echo "Attempt $i/60: application not ready yet..."
                sleep 2
            done

            if [ "$APP_READY" != "true" ]; then
                echo "ERROR: Application is not reachable on port 18080."
                cat /tmp/timesheet-port-forward.log
                exit 1
            fi

            echo "[1] Nmap port scan" >> "$NMAP_REPORT"
            echo "Target: 127.0.0.1:18080" >> "$NMAP_REPORT"
            echo "" >> "$NMAP_REPORT"

            nmap -Pn -p 18080 localhost \
                -oN "$NMAP_REPORT"

            echo "" >> "$NMAP_REPORT"
            echo "Nmap security smoke test completed." >> "$NMAP_REPORT"

            echo "========================================"
            echo "Starting OWASP ZAP Baseline Scan..."
            echo "========================================"

                          echo ""
              echo "========================================"
              echo "Starting OWASP ZAP Baseline Scan..."
              echo "========================================"

              mkdir -p "$WORKSPACE/zap-reports"
              chmod 777 "$WORKSPACE/zap-reports"

                            mkdir -p "$WORKSPACE/zap-reports"
              chmod 777 "$WORKSPACE/zap-reports"

              docker run --rm \
                  --network host \
                  -v "$WORKSPACE/zap-reports:/zap/wrk/:rw" \
                  ghcr.io/zaproxy/zaproxy:stable \
                  zap-baseline.py \
                  -t http://127.0.0.1:18080/timesheet-devops/ \
                  -r zap-baseline-report.html \
                  -J zap-baseline-report.json \
                  || true

              cp "$WORKSPACE/zap-reports/zap-baseline-report.html" \
                 "$WORKSPACE/zap-baseline-report.html" 2>/dev/null || true

              cp "$WORKSPACE/zap-reports/zap-baseline-report.json" \
                 "$WORKSPACE/zap-baseline-report.json" 2>/dev/null || true

              echo "Reports generated:"
              ls -lh \
                  "$NMAP_REPORT" \
                  "$ZAP_HTML" \
                  "$ZAP_JSON"

              echo ""
              echo "ZAP scan completed."

              if [ -f "$WORKSPACE/zap-reports/zap-baseline-report.html" ]; then
                  cp "$WORKSPACE/zap-reports/zap-baseline-report.html" \
                     "$WORKSPACE/zap-baseline-report.html"
              fi

              if [ -f "$WORKSPACE/zap-reports/zap-baseline-report.json" ]; then
                  cp "$WORKSPACE/zap-reports/zap-baseline-report.json" \
                     "$WORKSPACE/zap-baseline-report.json"
              fi

              echo "Reports generated:"
              ls -lh \
                  "$NMAP_REPORT" \
                  "$ZAP_HTML" \
                  "$ZAP_JSON"
            echo ""
            echo "Security Smoke Tests completed."
            echo "Reports generated:"
            ls -lh "$NMAP_REPORT" "$ZAP_HTML" "$ZAP_JSON"
        '''
    }

    post {
        always {
            archiveArtifacts artifacts: '''
                nmap-security-report.txt,
                zap-baseline-report.html,
                zap-baseline-report.json
            ''',
            allowEmptyArchive: false,
            fingerprint: true
        }
    }
        }
        stage('CHAOS MONKEY - FAULT INJECTION') {
            steps {
                sh '''
                    set -e

                    echo "=== CHAOS MONKEY / KUBE-MONKEY ==="

                    kubectl get deployment kube-monkey -n kube-monkey

                    echo "=== CIBLE ==="
                    kubectl get deployment timesheet-dep -n chap4                         -o jsonpath='{.metadata.labels}'
                    echo ""

                    echo "=== PODS AVANT TEST ==="
                    kubectl get pods -n chap4 -l app=timesheet -o wide

                    echo "=== REDÉMARRAGE KUBE-MONKEY ==="
                    kubectl rollout restart deployment/kube-monkey -n kube-monkey
                    kubectl rollout status deployment/kube-monkey -n kube-monkey

                    echo "=== ATTENTE DU CYCLE CHAOS ==="

                    for i in $(seq 1 20); do
                        if kubectl logs deployment/kube-monkey                             -n kube-monkey                             --since=2m 2>/dev/null                             | grep -q 'DryRun Mode.*timesheet-dep'; then
                            break
                        fi
                        sleep 5
                    done

                    mkdir -p chaos-results

                    echo "=== KUBE-MONKEY LOG ==="
                    kubectl logs deployment/kube-monkey                         -n kube-monkey                         --since=2m                         | tee chaos-results/kube-monkey-report.txt

                    echo "=== VERIFICATION DRY RUN ==="
                    grep -q 'DryRun Mode' chaos-results/kube-monkey-report.txt
                    grep -q 'timesheet-dep' chaos-results/kube-monkey-report.txt

                    echo "=== PODS APRES TEST ==="
                    kubectl get pods -n chap4 -l app=timesheet -o wide                         | tee -a chaos-results/kube-monkey-report.txt

                    echo "=== DEPLOYMENT ==="
                    kubectl get deployment timesheet-dep -n chap4                         | tee -a chaos-results/kube-monkey-report.txt

                    echo "Fault Injection Chaos Monkey : TEST DRY-RUN REUSSI"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'chaos-results/**',
                        allowEmptyArchive: true
                }
            }
        }

        stage('DAST - SQLMAP SCAN') {
            steps {
                sh '''
                    echo "=== ATTENTE DU DEPLOIEMENT TIMESHEET APRES CHAOS MONKEY ==="
                    kubectl rollout status deployment/timesheet-dep -n chap4 --timeout=180s

                    echo "=== PODS TIMESHEET PRETS ==="
                    kubectl get pods -n chap4 -l app=timesheet -o wide

                    sleep 10

                    kubectl port-forward -n chap4 svc/timesheet-serv 18080:8080 &
                    PF_PID=$!
                    sleep 8

                    mkdir -p sqlmap-results

sqlmap -u "http://127.0.0.1:18080/timesheet-devops/user/retrieve-user/1*" \
  --batch \
  --level=3 \
  --risk=2 \
  --output-dir=./sqlmap-results \
  2>&1 | tee sqlmap-results/sqlmap-report.txt

                    kill $PF_PID || true
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'sqlmap-results/**', allowEmptyArchive: true
                }
            }
        }
stage('SAFETY CHECKS - OSQUERY') {
    steps {
        sh '''
            set +x

            echo "========================================"
            echo "       OSQUERY SAFETY CHECKS"
            echo "========================================"

            mkdir -p osquery-results

            echo "[1] OSQuery version"
            /usr/bin/osqueryi --version \
                > osquery-results/osquery-version.txt 2>&1

            echo "[2] System information"
            /usr/bin/osqueryi \
                "SELECT hostname, computer_name, cpu_brand, physical_memory FROM system_info;" \
                > osquery-results/system-info.txt 2>&1

            echo "[3] Local users"
            /usr/bin/osqueryi \
                "SELECT uid, username, directory, shell FROM users;" \
                > osquery-results/users.txt 2>&1

            echo "[4] Running processes"
            /usr/bin/osqueryi \
                "SELECT pid, name, path, cmdline FROM processes;" \
                > osquery-results/processes.txt 2>&1

            echo "[5] Listening network ports"
/usr/bin/osqueryi \
    "SELECT listening_ports.address, listening_ports.port, listening_ports.protocol, listening_ports.pid, process.name FROM listening_ports LEFT JOIN processes AS process ON listening_ports.pid = process.pid;" \
    > osquery-results/listening-ports.txt 2>&1

            echo "[6] Installed packages"
            /usr/bin/osqueryi \
                "SELECT name, version FROM deb_packages;" \
                > osquery-results/packages.txt 2>&1

            echo "========================================"
            echo "OSQUERY SAFETY CHECKS completed."
            echo "========================================"

            ls -lh osquery-results/
        '''
    }

    post {
        always {
            archiveArtifacts artifacts: 'osquery-results/**',
                             allowEmptyArchive: false,
                             fingerprint: true
        }
    }
}
        stage('HIDS - FAIL2BAN') {
            steps {
                sh '''
                    set +x

                    mkdir -p fail2ban-results
                    REPORT="fail2ban-results/fail2ban-report.txt"

                    echo "========================================" > "$REPORT"
                    echo "       HIDS - FAIL2BAN SECURITY CHECK" >> "$REPORT"
                    echo "========================================" >> "$REPORT"
                    echo "" >> "$REPORT"

                    echo "[1] Fail2Ban service status" >> "$REPORT"
                    systemctl is-active fail2ban >> "$REPORT"

                    echo "" >> "$REPORT"
                    echo "[2] Fail2Ban jails" >> "$REPORT"
                    sudo /usr/bin/fail2ban-client status >> "$REPORT"

                    echo "" >> "$REPORT"
                    echo "[3] Jenkins jail status" >> "$REPORT"
                    sudo /usr/bin/fail2ban-client status jenkins >> "$REPORT"

                    echo "" >> "$REPORT"
                    echo "[4] Jenkins access log" >> "$REPORT"
                    ls -lh /var/log/jenkins/access_log >> "$REPORT"

                    echo "" >> "$REPORT"
                    echo "[5] Recent Jenkins access events" >> "$REPORT"
                    tail -20 /var/log/jenkins/access_log >> "$REPORT"

                    echo "" >> "$REPORT"
                    echo "========================================" >> "$REPORT"
                    echo "RESULT: HIDS - Fail2Ban validation successful." >> "$REPORT"
                    echo "========================================" >> "$REPORT"

                    cat "$REPORT"
                '''
            }

            post {
                always {
                    archiveArtifacts artifacts: 'fail2ban-results/**',
                                     allowEmptyArchive: false,
                                     fingerprint: true
                }
            }
        }

        stage('SERVER HARDENING - ANSIBLE') {
            steps {
                withCredentials([string(
                    credentialsId: 'ansible-vault-password',
                    variable: 'ANSIBLE_VAULT_PASSWORD'
                )]) {
                    sh '''
                        set +x

                        mkdir -p ansible-results

                        echo -n "$ANSIBLE_VAULT_PASSWORD" > ansible-results/.vault-password
                        chmod 600 ansible-results/.vault-password

                        sudo -n /usr/bin/ansible-playbook \
                            -i ansible/inventory.ini \
                            ansible/playbook.yml \
                            --vault-password-file ansible-results/.vault-password

                        rm -f ansible-results/.vault-password
                    '''
                }
            }

            post {
                always {
                    archiveArtifacts artifacts: 'ansible-results/server-hardening-report.txt',
                                     allowEmptyArchive: false,
                                     fingerprint: true

                    sh 'rm -f ansible-results/.vault-password'
                }
            }
        }

        stage('PROMETHEUS') {
            steps {
                sh '''
                    echo "Vérification de Prometheus..."
                    curl -s http://localhost:9090/-/ready
                    echo ""
                    echo "Prometheus est opérationnel."
                '''
            }
        }

        stage('CONTINUOUS MONITORING') {
            steps {
                sh '''
                    set -e

                    mkdir -p monitoring-results

                    REPORT="monitoring-results/monitoring-report.txt"

                    echo "========================================" | tee "$REPORT"
                    echo "       CONTINUOUS MONITORING REPORT" | tee -a "$REPORT"
                    echo "========================================" | tee -a "$REPORT"
                    echo "" | tee -a "$REPORT"

                    echo "[1] PROMETHEUS" | tee -a "$REPORT"
                    curl -fsS http://localhost:9090/-/ready | tee -a "$REPORT"
                    echo "" | tee -a "$REPORT"

                    echo "[2] KUBE-STATE-METRICS TARGET" | tee -a "$REPORT"

                    TARGETS=$(curl -fsS http://localhost:9090/api/v1/targets)

                    echo "$TARGETS" | grep -q '"job":"kube-state-metrics"' || {
                            echo "ERROR: kube-state-metrics target introuvable" | tee -a "$REPORT"
                            exit 1
                        }

                    echo "$TARGETS" | grep -q '"scrapeUrl":"http://192.168.49.2:30418/metrics"' || {
                            echo "ERROR: URL kube-state-metrics introuvable" | tee -a "$REPORT"
                            exit 1
                        }

                    echo "$TARGETS" | grep -q '"health":"up"' || {
                            echo "ERROR: kube-state-metrics target DOWN" | tee -a "$REPORT"
                            exit 1
                        }

                    echo "kube-state-metrics : UP" | tee -a "$REPORT"
                    echo "" | tee -a "$REPORT"

                    echo "[3] TIMESHEET DEPLOYMENT" | tee -a "$REPORT"

                    DEPLOYMENT_JSON=$(curl -fsS http://localhost:9090/api/v1/query                         --data-urlencode 'query=kube_deployment_status_replicas_available{namespace="chap4",deployment="timesheet-dep"}')

                    AVAILABLE=$(printf '%s' "$DEPLOYMENT_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["data"]["result"][0]["value"][1] if d["data"]["result"] else "0")')

                    if [ -z "$AVAILABLE" ]; then
                        echo "ERROR: impossible de récupérer les replicas Timesheet" | tee -a "$REPORT"
                        exit 1
                    fi

                    echo "Available replicas : $AVAILABLE" | tee -a "$REPORT"

                    if [ "$AVAILABLE" -lt 1 ]; then
                        echo "ERROR: aucun replica Timesheet disponible" | tee -a "$REPORT"
                        exit 1
                    fi

                    echo "Timesheet deployment : OK" | tee -a "$REPORT"
                    echo "" | tee -a "$REPORT"

                    echo "[4] TIMESHEET PODS" | tee -a "$REPORT"

                    PODS_JSON=$(curl -fsS http://localhost:9090/api/v1/query                         --data-urlencode 'query=count(kube_pod_status_phase{namespace="chap4",pod=~"timesheet-dep-.*",phase="Running"} == 1)')

                    RUNNING=$(printf '%s' "$PODS_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["data"]["result"][0]["value"][1] if d["data"]["result"] else "0")')

                    echo "Running Timesheet pods : $RUNNING" | tee -a "$REPORT"

                    if [ "$RUNNING" -lt 1 ]; then
                        echo "ERROR: aucun pod Timesheet Running" | tee -a "$REPORT"
                        exit 1
                    fi

                    echo "Timesheet pods : OK" | tee -a "$REPORT"
                    echo "" | tee -a "$REPORT"

                    echo "[5] PROMETHEUS ALERT RULES" | tee -a "$REPORT"

                    RULES=$(curl -fsS http://localhost:9090/api/v1/rules)

                    echo "$RULES" | grep -q 'TimesheetDeploymentUnavailable' || {
                        echo "ERROR: règle TimesheetDeploymentUnavailable absente" | tee -a "$REPORT"
                        exit 1
                    }

                    echo "$RULES" | grep -q 'TimesheetPodNotRunning' || {
                        echo "ERROR: règle TimesheetPodNotRunning absente" | tee -a "$REPORT"
                        exit 1
                    }

                    echo "$RULES" | grep -q '"health":"ok"' || {
                        echo "ERROR: règle Prometheus non saine" | tee -a "$REPORT"
                        exit 1
                    }

                    echo "Alert rules : OK" | tee -a "$REPORT"
                    echo "" | tee -a "$REPORT"

                    echo "========================================" | tee -a "$REPORT"
                    echo "RESULT: CONTINUOUS MONITORING SUCCESS" | tee -a "$REPORT"
                    echo "========================================" | tee -a "$REPORT"

                    cat "$REPORT"
                '''
            }

            post {
                always {
                    archiveArtifacts artifacts: 'monitoring-results/**',
                                     allowEmptyArchive: false,
                                     fingerprint: true
                }
            }
        }

        stage('CONTINUOUS SCANNING - OPENSCAP') {
            steps {
                sh '''
                    set -e

                    mkdir -p openscap-results

                    DATASTREAM="tools/openscap/ssg/ssg-ubuntu2404-ds.xml"
                    PROFILE="xccdf_org.ssgproject.content_profile_cis_level1_server"
                    RESULTS="openscap-results/openscap-results.xml"
                    REPORT="openscap-results/openscap-report.html"
                    SUMMARY="openscap-results/openscap-summary.txt"

                    echo "========================================"
                    echo "     CONTINUOUS SCANNING - OPENSCAP"
                    echo "========================================"

                    echo "[1] OPENSCAP"

                    command -v oscap >/dev/null 2>&1 || {
                        echo "ERROR: oscap introuvable"
                        exit 1
                    }

                    oscap --version | head -1

                    echo ""
                    echo "[2] DATASTREAM"

                    test -r "$DATASTREAM" || {
                        echo "ERROR: DataStream OpenSCAP introuvable : $DATASTREAM"
                        exit 1
                    }

                    echo "DataStream Ubuntu 24.04 : OK"

                    echo ""
                    echo "[3] PROFILE"

                    oscap info "$DATASTREAM" | grep -q "$PROFILE" || {
                        echo "ERROR: profil OpenSCAP introuvable"
                        exit 1
                    }

                    echo "CIS Ubuntu 24.04 Level 1 Server : OK"

                    echo ""
                    echo "[4] SCAN"

                    set +e

                    oscap xccdf eval \
                        --profile "$PROFILE" \
                        --results "$RESULTS" \
                        --report "$REPORT" \
                        "$DATASTREAM"

                    SCAN_RC=$?

                    set -e

                    test -s "$RESULTS" || {
                        echo "ERROR: résultat OpenSCAP non généré"
                        exit 1
                    }

                    test -s "$REPORT" || {
                        echo "ERROR: rapport HTML OpenSCAP non généré"
                        exit 1
                    }

                    echo ""
                    echo "Code retour OpenSCAP : $SCAN_RC"

                    echo ""
                    echo "[5] RESULTS"

                    read_counts=$(python3 - "$RESULTS" <<'PYCOUNTS'
import sys
import xml.etree.ElementTree as ET
from collections import Counter

root = ET.parse(sys.argv[1]).getroot()
counts = Counter()

for element in root.iter():
    if element.tag.endswith("result") and element.text:
        counts[element.text.strip()] += 1

print(
    counts.get("pass", 0),
    counts.get("fail", 0),
    counts.get("notapplicable", 0),
    counts.get("notselected", 0)
)
PYCOUNTS
                    )

                    read -r PASS FAIL NOT_APPLICABLE NOT_SELECTED <<EOF_COUNTS
$read_counts
EOF_COUNTS

                    {
                        echo "========================================"
                        echo "     CONTINUOUS SCANNING - OPENSCAP"
                        echo "========================================"
                        echo ""
                        echo "OS      : $(. /etc/os-release && echo "$PRETTY_NAME")"
                        echo "Profile : CIS Ubuntu Linux 24.04 LTS Benchmark for Level 1 - Server"
                        echo "Scanner : $(oscap --version | head -1)"
                        echo ""
                        echo "RESULTS"
                        echo "-------"
                        echo "PASS          : $PASS"
                        echo "FAIL          : $FAIL"
                        echo "NOT APPLICABLE: $NOT_APPLICABLE"
                        echo "NOT SELECTED  : $NOT_SELECTED"
                        echo ""
                        echo "OpenSCAP exit code : $SCAN_RC"
                        echo ""
                        echo "========================================"
                        echo "STATUS: SCAN COMPLETED"
                        echo "========================================"
                    } > "$SUMMARY"

                    cat "$SUMMARY"

                    echo ""
                    echo "Rapport HTML : $REPORT"
                    echo "Résultats XML : $RESULTS"
                    echo "Résumé : $SUMMARY"

                    echo ""
                    echo "Continuous Scanning OpenSCAP : SCAN COMPLETED"
                '''
            }

            post {
                always {
                    archiveArtifacts artifacts: 'openscap-results/**',
                                     allowEmptyArchive: false,
                                     fingerprint: true
                }
            }
        }
    }

    post {
        always {
            sh '''
                REPORTS_DIR="$WORKSPACE" \
                PUSHGATEWAY=http://192.168.203.161:9091 \
                bash export_security_metrics.sh || true
            '''
        }

        success {
            echo 'Pipeline CI/CD terminée avec succès.'
        }

        failure {
            echo 'Pipeline CI/CD échouée.'
        }
    }
}                
       
