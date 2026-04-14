
# **Requirements**
- Security Group:

**Inbound Rules**
- Custom TCP: port 8080 for jenkins
- SSH: 22 to SSH into our EC2

**Outbound Rules** 
- Leave default 
____
## **VPC**
- Availability Zone: 1
- Public & Private subnet: 1
- Customize subnets CIDR blocks:
	- Public `10.81.1.0/24`
	- Private `10.81.11.0/24`
- NAT Gateway: none
___
## **EC2 for Jenkins**
- At least a T3 Medium, 4GB RAM and up according to your needs
- Make sure Auto-assign public IP is set to `Enable`
- Provision at least 30-40 GB storage (EBS)
- Insert startup script from `user-data.sh` into Advanced section
- Startup script handles most of the installs including terraform, java 21, and plugins.
- While in AWS, we also need to make sure we have an IAM user we can use for AWS Credentials in Jenkins.
- IAM access key & IAM secret key is needed. Keep them safe and hidden, will need them Jenkins.
___
## **Jenkins**

To access Jemnkins: EC2 publics DNS/ ipv4 address:8080

- SSH into EC2 and cat into secrets folder to get initial admin password:
`sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
- Add Credentials: Create an ID and add IAM access key and IAM Secret key
- Set up pipeline in Jenkins
    - Select GitHub hook trigger for GITScm Polling
    - Pipeline script from SCM
    - SCM - GIT
    - Repository URL: https://github.com/yearninlearnin/atarashii-jenkins-testo.git
    - Branch: */main
    - Script Path: Jenkinsfile
## **Webhook**
- Set up webhook in github
- Payload URL: http://jenkinsURL/github-webhook/
- Content type : application/json
- Add webhook
___



## Troubleshooting

### Expected Result
- Push event occurs on repo
- Webhook sent from GitHub
- Jenkins job starts automatically

### Common issues
Jenkins not reachable:
- Ensure public IP or DNS
- Open port 8080 in security group

Incorrect webhook URL:
- Must end with `/github-webhook/`

No build triggered:
- Verify trigger enabled in Jenkins
- Check webhook delivery status (200 OK)

## What Is Happing and How It Works

### What a Webhook Is

A webhook is an HTTP callback.

- One system sends an HTTP request to another system when an event happens
- No polling is required
- It is event-driven

In this case:
- GitHub = sender
- Jenkins = receiver

---

### What Happens Step by Step

1. You push code to GitHub
2. GitHub detects a `push` event
3. GitHub sends an HTTP POST request to:
   `http://<jenkins-url>/github-webhook/`
4. Jenkins receives the request
5. Jenkins matches the event to a configured job
6. Jenkins triggers the pipeline
7. Jenkins reads the `Jenkinsfile` from the repo
8. Pipeline runs

---

### What the Webhook Sends

GitHub sends a JSON payload that includes:

- Repository name
- Branch
- Commit ID
- Commit message
- Author

Example (simplified):

```json
{
  "ref": "refs/heads/main",
  "repository": {
    "full_name": "aaron-dm-mcdonald/new-jenkins-s3-test"
  },
  "head_commit": {
    "id": "abc123",
    "message": "update"
  }
}
```

