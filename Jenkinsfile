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
		mvn org.owasp:dependency-check-maven:check "$NVD_OPTION=$NVD_API_KEY"		
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
                sh 'docker build -t siwarbessoud/timesheet-devops:1.0.11 .'
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
                        docker push siwarbessoud/timesheet-devops:1.0.11
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
vaultCredentialsId: 'vault-timesheet',
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

            echo "Starting Kubernetes port-forward..."

            kubectl port-forward -n chap4 svc/timesheet-serv 18080:8080 \
                > /tmp/timesheet-port-forward.log 2>&1 &
            PF_PID=$!

            cleanup() {
                kill "$PF_PID" 2>/dev/null || true
            }
            trap cleanup EXIT

            echo "Waiting for application on port 18080..."

            for i in $(seq 1 15); do
                if curl -s http://127.0.0.1:18080 >/dev/null 2>&1; then
                    echo "Application is reachable."
                    break
                fi
                sleep 2
            done

            if ! curl -s http://127.0.0.1:18080 >/dev/null 2>&1; then
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
        stage('DAST - SQLMAP SCAN') {
            steps {
                sh '''
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
                    fail2ban-client status >> "$REPORT"

                    echo "" >> "$REPORT"
                    echo "[3] Jenkins jail status" >> "$REPORT"
                    fail2ban-client status jenkins >> "$REPORT"

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
    }

    post {
        success {
            echo 'Pipeline CI/CD terminée avec succès.'
        }

        failure {
            echo 'Pipeline CI/CD échouée.'
        }
    }
}                
       
