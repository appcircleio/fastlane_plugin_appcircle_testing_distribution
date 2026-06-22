pipeline {
    agent { label 'agent' }

    environment {
        GEM_HOST_API_KEY = credentials('Appcircle-Fastlane-RubyGems-Cred')
    }

    stages {
        stage('Pre-release (beta)') {
            when { expression { env.BRANCH_NAME ==~ /release\/\d+\.\d+\.\d+/ } }
            steps {
                sh './pipeline.sh prerelease'
            }
        }

        stage('Production release') {
            when { branch 'main' }
            steps {
                sh './pipeline.sh production'
            }
        }
    }

    post {
        always {
            script {
                sendBuildSummaryToSlack(currentBuild.currentResult, currentBuild.durationString, [])
            }
        }
    }
}
