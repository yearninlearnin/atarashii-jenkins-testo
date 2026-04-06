# Jenkins Homelab Webhook + Terraform AWS Credentials Troubleshooting

## Context

Migrated a Jenkins pipeline from an AWS EC2 instance to a homelab Jenkins (Docker-based) with Cloudflare DNS. The pipeline runs Terraform to manage AWS S3 resources via a GitHub webhook trigger.

---

## Issue 1: Terraform — "No valid credential sources found"

**Error:**
```
Error: No valid credential sources found
Error: failed to refresh cached credentials, no EC2 IMDS role found
```

**Why it failed:**
On EC2, Jenkins gets AWS credentials automatically through the Instance Metadata Service (IMDS) via the IAM Role attached to the instance. A homelab machine has no IMDS, so Terraform's credential chain (env vars -> shared credentials file -> IMDS) finds nothing.

**Fix:**
AWS credentials must be explicitly injected into the pipeline from Jenkins' credential store. The original Jenkinsfile had no credential injection because the EC2 version never needed it.

---

## Issue 2: Wrong credential binding — `credentials('aws-access-key-id')`

**Error:**
```
ERROR: aws-access-key-id
```

**Why it failed:**
The credentials stored in Jenkins were of type **AWS Credentials** (a single entry bundling both Access Key ID and Secret Access Key) with ID `JenkinsTest`. The Jenkinsfile was referencing two separate **Secret text** credentials (`aws-access-key-id` and `aws-secret-access-key`) which didn't exist.

**Fix:**
Use `withCredentials` with `AmazonWebServicesCredentialsBinding` to correctly bind the AWS Credentials type. This automatically sets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as environment variables within the block.

```groovy
withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'JenkinsTest']]) {
    sh 'terraform init -reconfigure'
}
```

---

## Issue 3: Empty steps block — Jenkins compilation error

**Error:**
```
No steps specified for branch @ line 24, column 19.
```

**Why it failed:**
The `terraform init` command was commented out for debugging, leaving the `steps {}` block empty. Jenkins does not allow empty steps blocks in declarative pipelines.

**Fix:**
Uncommented the `sh 'terraform init -reconfigure'` line. Never leave a `steps` block empty — use `echo 'skip'` as a placeholder if needed.

---

## Issue 4: Webhook delivered (200) but no build triggered

**Symptoms:**
GitHub webhook showed successful 200 delivery, but Jenkins did not start a build.

**Why it failed:**
A combination of factors:
- Adding an incomplete GitHub Server configuration in Manage Jenkins > System may have disrupted webhook-to-job matching
- Using `git commit --allow-empty` creates a commit with no file changes, which can cause Jenkins SCM polling to skip the build

**Fix:**
- Removed the incomplete GitHub Server configuration (it wasn't needed — the webhook worked without it before)
- Pushed real commits with actual file changes instead of `--allow-empty`

---

## Key Takeaways

| EC2 Jenkins | Homelab Jenkins |
|---|---|
| IAM Role provides credentials via IMDS automatically | Must inject credentials explicitly in the Jenkinsfile |
| No credential config needed in pipeline | Use `withCredentials` with `AmazonWebServicesCredentialsBinding` |
| GitHub Server config may already be set up | Verify webhook-to-job matching works before adding GitHub Server config |

### Credential types matter

- **AWS Credentials** plugin type (bundles access key + secret) -> use `withCredentials` with `AmazonWebServicesCredentialsBinding`
- **Secret text** type (individual values) -> use `credentials('id')` in the `environment` block
- Never put actual keys in the Jenkinsfile — `credentials()` and `withCredentials` are references to Jenkins' secure credential store

### Working Jenkinsfile pattern for homelab

```groovy
stage('Terraform Init') {
    steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'JenkinsTest']]) {
            sh 'terraform init -reconfigure'
        }
    }
}
```
