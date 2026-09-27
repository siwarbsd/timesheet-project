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
                sh 'docker build -t siwarbessoud/timesheet-devops:1.0.10 .'
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
                        docker push siwarbessoud/timesheet-devops:1.0.10
                        docker logout
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
