
pipeline {
    agent any

    stages {

        stage('GIT') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/siwarbsd/timesheet-project.git'
            }
        }

        stage('COMPILATION') {
            steps {
                sh 'mvn clean install'
            }
        }

        stage('ANALYSIS') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'mvn sonar:sonar'
                }
            }
        }

        stage('DEPLOY') {
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
                sh 'docker build -t timesheet-devops:1.0.2 .'
            }
        }
    }
}

