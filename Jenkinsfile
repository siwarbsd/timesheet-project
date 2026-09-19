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
                sh 'mvn deploy -DskipTests'
            }
        }

        stage('DOCKER BUILD') {
            steps {
                sh 'docker build -t timesheet-devops:1.0.2 .'
            }
        }
    }
}
