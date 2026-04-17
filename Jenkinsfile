// Jenkins Pipeline: Ansible Windows Fleet Automation
// Triggers AWX job templates via API to enforce endpoint configuration
//
// Prerequisites:
//   - Jenkins credentials: 'awx-api-token' (Secret text)
//   - Jenkins credentials: 'ansible-vault-pass' (Secret text)
//   - AWX job templates configured and named correctly
//   - Network connectivity between Jenkins and AWX


pipeline {
    agent any

    parameters {
        choice(
            name: 'PLAYBOOK',
            choices: ['site', 'deploy_software', 'compliance_check'],
            description: 'Which playbook to execute via AWX'
        )
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'prod'],
            description: 'Target environment inventory'
        )
        booleanParam(
            name: 'DRY_RUN',
            defaultValue: true,
            description: 'Run in check mode (no changes applied)'
        )
    }

    environment {
        AWX_URL       = 'http://192.168.1.198:30080'
        AWX_CRED_ID   = 'awx-api-token'
    }

    stages {
        stage('Validate Parameters') {
            steps {
                script {
                    echo "=== Ansible Windows Fleet Pipeline ==="
                    echo "Playbook:    ${params.PLAYBOOK}"
                    echo "Environment: ${params.ENVIRONMENT}"
                    echo "Dry Run:     ${params.DRY_RUN}"

                    if (params.ENVIRONMENT == 'prod' && !params.DRY_RUN) {
                        input message: '⚠️ PRODUCTION deployment with changes enabled. Approve?',
                              ok: 'Deploy to Production'
                    }
                }
            }
        }

        stage('Lint Playbooks') {
            steps {
                sh '''
                    echo "Running ansible-lint on playbooks..."
                    docker run --rm \
                        -v $(pwd):/workspace \
                        -w /workspace \
                        cytopia/ansible-lint:latest \
                        playbooks/${PLAYBOOK}.yml || true
                '''
            }
        }

        stage('Trigger AWX Job') {
            steps {
                withCredentials([string(credentialsId: "${AWX_CRED_ID}", variable: 'AWX_TOKEN')]) {
                    script {
                        def authValue = "Bearer " + AWX_TOKEN
                        def jobTemplateName = "fleet-${params.PLAYBOOK}-${params.ENVIRONMENT}"
                        def extraVars = params.DRY_RUN ? '{"ansible_check_mode": true}' : '{}'

                        echo "Launching AWX job template: ${jobTemplateName}"

                        def response = httpRequest(
                            url: "${AWX_URL}/api/v2/job_templates/${jobTemplateName}/launch/",
                            httpMode: 'POST',
                            customHeaders: [
                                [name: 'Authorization', value: authValue],
                                [name: 'Content-Type',  value: 'application/json']
                            ],
                            requestBody: """{"extra_vars": ${extraVars}}""",
                            validResponseCodes: '201'
                        )

                        def jobData = readJSON text: response.content
                        env.AWX_JOB_ID = jobData.id
                        echo "AWX Job launched: ID ${env.AWX_JOB_ID}"
                    }
                }
            }
        }

        stage('Monitor AWX Job') {
            steps {
                withCredentials([string(credentialsId: "${AWX_CRED_ID}", variable: 'AWX_TOKEN')]) {
                    script {
                        def authValue = "Bearer " + AWX_TOKEN
                        def jobComplete = false
                        def maxRetries = 60
                        def retryCount = 0

                        while (!jobComplete && retryCount < maxRetries) {
                            sleep(time: 10, unit: 'SECONDS')

                            def statusResp = httpRequest(
                                url: "${AWX_URL}/api/v2/jobs/${env.AWX_JOB_ID}/",
                                httpMode: 'GET',
                                customHeaders: [
                                    [name: 'Authorization', value: authValue]
                                ],
                                validResponseCodes: '200'
                            )

                            def statusData = readJSON text: statusResp.content
                            echo "Job ${env.AWX_JOB_ID} status: ${statusData.status}"

                            if (statusData.status in ['successful', 'failed', 'error', 'canceled']) {
                                jobComplete = true
                                if (statusData.status != 'successful') {
                                    error "AWX job ${env.AWX_JOB_ID} finished with status: ${statusData.status}"
                                }
                            }
                            retryCount++
                        }

                        if (!jobComplete) {
                            error "AWX job ${env.AWX_JOB_ID} timed out after ${maxRetries * 10} seconds"
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo "✅ Fleet automation completed successfully"
        }
        failure {
            echo "❌ Fleet automation failed — check AWX job ${env.AWX_JOB_ID} for details"
        }
        always {
            echo "AWX Dashboard: ${AWX_URL}/#/jobs/playbook/${env.AWX_JOB_ID}"
        }
    }
}
