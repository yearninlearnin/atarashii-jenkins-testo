pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION    = 'us-west-1'
        TF_IN_AUTOMATION      = 'true'
        SNYK_ORG  = credentials('snyk-org-slug')
        
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        // introducing synk code into jenkins from charles-snyk
        // stage('Snyk IaC Scan Test') {
        //     steps {
        //         withCredentials([string(credentialsId: 'snyk-api-token-string', variable: 'SNYK_TOKEN')]) {
        //             sh '''
        //                 export PATH=$PATH:/var/lib/jenkins/tools/io.snyk.jenkins.tools.SnykInstallation/snyk
        //                 snyk-linux auth $SNYK_TOKEN
        //                 snyk-linux iac test --org=$SNYK_ORG --severity-threshold=high || true
        //             '''
        //         }
        //     }
        // }        
        stage('Snyk IaC Scan Monitor') {
            steps {
                snykSecurity(
                    snykInstallation: 'snyk',
                    snykTokenId: 'snyk-api-token',
                    additionalArguments: '--iac --report --org=$SNYK_ORG --severity-threshold=high',
                    failOnIssues: true,
                    monitorProjectOnBuild: false
                )
            }
        }


        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'fugakujenkins']]) {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',credentialsId: 'fugakujenkins']]) {
                    sh 'terraform plan'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'fugakujenkins']]) {
                    sh '''
                        terraform plan -out=tfplan
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }

        stage('Optional Destroy') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'fugakujenkins']]) {
                    script {
                        def destroyChoice = input(
                            message: 'Do you want to run terraform destroy?',
                            ok: 'Submit',
                            parameters: [
                                choice(
                                    name: 'DESTROY',
                                    choices: ['no', 'yes'],
                                    description: 'Select yes to destroy resources'
                                )
                            ]
                        )
                        if (destroyChoice == 'yes') {
                            sh 'terraform destroy -auto-approve'
                        } else {
                            echo "Skipping destroy"
                        }
                    }
                }
            }
        }
    }
}