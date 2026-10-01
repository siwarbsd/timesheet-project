pipeline {
    agent any

    stages {

        stage('CHECKOUT') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/siwarbsd/timesheet-project.git'
            }
        }
   stage('VAULT SECRETS') {
steps {
withVault([
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
test -n "$MYSQL_USERNAME"
test -n "$MYSQL_PASSWORD"

            echo "Secrets MySQL récupérés depuis HashiCorp Vault : OK"
        '''
    }
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
stage('VAULT → KUBERNETES SECRET') {
steps {
withVault([
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

```
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
```

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
       
