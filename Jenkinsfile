pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION    = 'us-west-1'
        TF_IN_AUTOMATION      = 'true'
        
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'fugakujenkins']]) {
                    sh 'terraform init'
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