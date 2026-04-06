#!/bin/bash
#
#
#
# V3.0 build 04-04-26
# ## Removed Portainer; special characters in password:on ; updated plugins list
#
### Works on Ubuntu, might test RHEL version
#
# ==============================================================================
# Jenkins-in-Docker Provisioning Script (with Cloudflare Tunnel)
# ==============================================================================
# Installs Docker, builds a custom Jenkins image (Java 21, AWS CLI, Terraform,
# Python), installs plugins, creates admin user, skips the setup wizard,
# and sets up a Cloudflare Tunnel for public webhook access.
#
# Target: Ubuntu Server 22.04/24.04 LTS
#   - Linux VM (Proxmox, VMware, UTM, VirtualBox, etc.)
#   - Cloud instance (AWS EC2, GCP Compute Engine, Azure VM)
#   - Bare metal
#
# Requirements:
#   - 2+ CPU, 4+ GB RAM, 32+ GB disk
#   - Internet access
#   - sudo privileges
#
# Usage:
#   chmod +x setup-jenkins.sh
#   ./setup-jenkins.sh
#
# ==============================================================================

set -euo pipefail

# ========================
# CONFIGURATION — EDIT HERE
# ========================
JENKINS_ADMIN_USER="admin"
JENKINS_ADMIN_PASS='password'
TERRAFORM_VERSION="1.7.5"

# Cloudflare Tunnel mode:
#   "quick"  = Free, no domain needed. Random trycloudflare.com URL (changes on restart).
#   "named"  = Requires a domain on Cloudflare. Stable URL. Requires manual auth after script.
#   "skip"   = Don't install cloudflared (e.g. for EC2 with a public IP).
TUNNEL_MODE="quick"

# Only used if TUNNEL_MODE="named"
TUNNEL_NAME="jenkins"
TUNNEL_HOSTNAME="jenkins.yourdomain.com"

# ==============================================================================
# STEP 1: Install Docker
# ==============================================================================
echo "=========================================="
echo "[1/6] Installing Docker..."
echo "=========================================="

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo usermod -aG docker "$USER"

echo "[1/6] Docker installed successfully."

# ==============================================================================
# STEP 2: Build custom Jenkins image
# ==============================================================================
echo "=========================================="
echo "[2/6] Building custom Jenkins image..."
echo "=========================================="

DOCKERFILE_DIR=$(mktemp -d)

# --- Admin credentials files (avoids shell/Groovy special char issues) ---
mkdir -p "$DOCKERFILE_DIR/init-scripts"
printf '%s' "$JENKINS_ADMIN_USER" > "$DOCKERFILE_DIR/init-scripts/admin-user.txt"
printf '%s' "$JENKINS_ADMIN_PASS" > "$DOCKERFILE_DIR/init-scripts/admin-pass.txt"

# --- Groovy init script: reads creds from files, no variable expansion issues ---
cat > "$DOCKERFILE_DIR/init-scripts/01-create-admin.groovy" << 'GROOVY'
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

def userFile = new File("/var/jenkins_home/init.groovy.d/admin-user.txt")
def passFile = new File("/var/jenkins_home/init.groovy.d/admin-pass.txt")

if (!userFile.exists() || !passFile.exists()) {
    println(">>> Credential files not found. Skipping admin creation.")
    return
}

def adminUser = userFile.text.trim()
def adminPass = passFile.text.trim()

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount(adminUser, adminPass)
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()

// Clean up credential files after first use
userFile.delete()
passFile.delete()

println(">>> Admin user '${adminUser}' created. Credential files removed.")
GROOVY

# --- plugins.txt ---
# If any plugin fails to resolve, remove it from this list and re-run.
cat > "$DOCKERFILE_DIR/plugins.txt" << 'EOF'
# ---- Core pipeline and Git ----
git
github
github-branch-source
github-pullrequest
github-oauth
pipeline-github
pipeline-githubnotify-step
workflow-aggregator
pipeline-stage-view
blueocean
credentials
credentials-binding
configuration-as-code
job-dsl
ssh-agent
publish-over-ssh
timestamper
ws-cleanup
antisamy-markup-formatter
build-timeout

# ---- AWS ----
aws-credentials
pipeline-aws
ec2
amazon-ecs
codedeploy
aws-lambda
aws-codebuild
aws-secrets-manager-credentials-provider
aws-codepipeline
configuration-as-code-secret-ssm
jenkins-cloudformation-plugin
aws-sam
aws-bucket-credentials

# ---- GCP ----
google-storage-plugin
google-kubernetes-engine
google-oauth-plugin

# ---- Terraform ----
terraform

# ---- Kubernetes ----
kubernetes

# ---- Java / Maven ----
maven-plugin
pipeline-maven

# ---- Security / Code Quality ----
snyk-security-scanner
sonar
EOF

# --- Dockerfile ---
cat > "$DOCKERFILE_DIR/Dockerfile" << EOF
FROM jenkins/jenkins:lts-jdk21

USER root

RUN apt-get update && apt-get install -y \\
    curl unzip python3 python3-pip python3-venv jq \\
    && ln -sf /usr/bin/python3 /usr/bin/python \\
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \\
    && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws \\
    && curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o "/tmp/terraform.zip" \\
    && unzip /tmp/terraform.zip -d /usr/local/bin/ && rm /tmp/terraform.zip \\
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER jenkins

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY init-scripts/01-create-admin.groovy /usr/share/jenkins/ref/init.groovy.d/01-create-admin.groovy
COPY init-scripts/admin-user.txt /usr/share/jenkins/ref/init.groovy.d/admin-user.txt
COPY init-scripts/admin-pass.txt /usr/share/jenkins/ref/init.groovy.d/admin-pass.txt
EOF

sudo docker build -t jenkins-custom "$DOCKERFILE_DIR"
rm -rf "$DOCKERFILE_DIR"

echo "[2/6] Custom Jenkins image built successfully."

# ==============================================================================
# STEP 3: Run Jenkins
# ==============================================================================
echo "=========================================="
echo "[3/6] Starting Jenkins container..."
echo "=========================================="

sudo docker rm -f jenkins 2>/dev/null || true

sudo docker run -d \
  --name jenkins\
  --hostname jenkins \
  --restart=unless-stopped \
  -p 8080:8080 \
  -v jenkins_home:/var/jenkins_home \
  jenkins-custom

echo "[3/6] Jenkins container started."

# ==============================================================================
# STEP 4: Install Cloudflare Tunnel
# ==============================================================================
if [ "$TUNNEL_MODE" != "skip" ]; then
  echo "=========================================="
  echo "[4/6] Installing cloudflared..."
  echo "=========================================="

  curl -L https://pkg.cloudflare.com/cloudflare-main.gpg \
    | sudo tee /usr/share/keyrings/cloudflare-archive-keyring.gpg >/dev/null

  echo "deb [signed-by=/usr/share/keyrings/cloudflare-archive-keyring.gpg] \
  https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/cloudflared.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y cloudflared

  if [ "$TUNNEL_MODE" = "quick" ]; then
    sudo tee /etc/systemd/system/cloudflared-quick.service > /dev/null << 'EOF'
[Unit]
Description=Cloudflare Quick Tunnel for Jenkins
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/cloudflared tunnel --url http://localhost:8080 --no-autoupdate
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable cloudflared-quick.service
  fi

  echo "[4/6] cloudflared installed."
else
  echo "=========================================="
  echo "[4/6] Skipping cloudflared (TUNNEL_MODE=skip)."
  echo "=========================================="
fi

# ==============================================================================
# STEP 5: Wait for Jenkins to be ready
# ==============================================================================
echo "=========================================="
echo "[5/6] Waiting for Jenkins to initialize..."
echo "=========================================="

JENKINS_URL="http://localhost:8080"
MAX_WAIT=180
WAITED=0

while ! curl -s -o /dev/null -w "%{http_code}" "$JENKINS_URL/login" 2>/dev/null | grep -q "200"; do
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    echo "ERROR: Jenkins did not start within ${MAX_WAIT} seconds."
    echo "Check logs: sudo docker logs jenkins"
    exit 1
  fi
  echo "  Waiting for Jenkins... (${WAITED}s)"
  sleep 10
  WAITED=$((WAITED + 10))
done

echo "[5/6] Jenkins is up and running."

# Start quick tunnel now that Jenkins is ready
TUNNEL_URL=""
if [ "$TUNNEL_MODE" = "quick" ]; then
  sudo systemctl start cloudflared-quick.service
  sleep 5
  echo "  Quick tunnel started. Fetching public URL..."
  for i in $(seq 1 12); do
    TUNNEL_URL=$(sudo journalctl -u cloudflared-quick.service --no-pager -n 50 2>/dev/null \
      | grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1) || true
    if [ -n "$TUNNEL_URL" ]; then
      break
    fi
    sleep 5
  done
fi

# ==============================================================================
# STEP 6: Verify installation
# ==============================================================================
echo "=========================================="
echo "[6/6] Verifying installation..."
echo "=========================================="

echo ""
echo "--- Docker version ---"
sudo docker --version

echo ""
echo "--- Running containers ---"
sudo docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "--- Tools inside Jenkins container ---"
echo -n "  Java:      "; sudo docker exec jenkins java --version 2>&1 | head -1
echo -n "  AWS CLI:   "; sudo docker exec jenkins aws --version 2>&1
echo -n "  Terraform: "; sudo docker exec jenkins terraform --version 2>&1 | head -1
echo -n "  Python:    "; sudo docker exec jenkins python --version 2>&1

if [ "$TUNNEL_MODE" != "skip" ]; then
  echo -n "  Cloudflared: "; cloudflared --version 2>&1
fi

# ==============================================================================
# DONE
# ==============================================================================
VM_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "=========================================="
echo " SETUP COMPLETE"
echo "=========================================="
echo ""
echo " Jenkins UI (local):  http://${VM_IP}:8080"
echo ""
echo " Jenkins login:"
echo "   Username: ${JENKINS_ADMIN_USER}"
echo "   Password: (set in script config)"
echo ""
echo " All plugins pre-installed. No setup wizard."
echo ""

if [ "$TUNNEL_MODE" = "quick" ]; then
  echo "=========================================="
  echo " CLOUDFLARE QUICK TUNNEL (FREE)"
  echo "=========================================="
  echo ""
  if [ -n "${TUNNEL_URL}" ]; then
    echo " Public URL:  ${TUNNEL_URL}"
    echo " Webhook URL: ${TUNNEL_URL}/github-webhook/"
  else
    echo " URL not detected yet. Check manually:"
    echo "   sudo journalctl -u cloudflared-quick -f"
    echo "   (look for the https://xxxxx.trycloudflare.com line)"
  fi
  echo ""
  echo " NOTE: This URL changes every time the tunnel restarts."
  echo " Update your GitHub webhook payload URL after each restart."
  echo ""
  echo " To get the current URL:"
  echo "   sudo journalctl -u cloudflared-quick --no-pager | grep trycloudflare"
  echo ""
  echo " To restart the tunnel:"
  echo "   sudo systemctl restart cloudflared-quick"
  echo ""

elif [ "$TUNNEL_MODE" = "named" ]; then
  echo "=========================================="
  echo " CLOUDFLARE NAMED TUNNEL — MANUAL STEPS"
  echo "=========================================="
  echo ""
  echo " cloudflared is installed. Complete setup manually:"
  echo ""
  echo " 1. Authenticate:"
  echo "    cloudflared tunnel login"
  echo ""
  echo " 2. Create tunnel:"
  echo "    cloudflared tunnel create ${TUNNEL_NAME}"
  echo ""
  echo " 3. Create config (replace <TUNNEL-ID>):"
  echo "    sudo mkdir -p /etc/cloudflared"
  echo "    sudo nano /etc/cloudflared/config.yml"
  echo ""
  echo "    tunnel: <TUNNEL-ID>"
  echo "    credentials-file: /etc/cloudflared/<TUNNEL-ID>.json"
  echo ""
  echo "    ingress:"
  echo "      - hostname: ${TUNNEL_HOSTNAME}"
  echo "        service: http://localhost:8080"
  echo "      - service: http_status:404"
  echo ""
  echo " 4. Copy credentials:"
  echo "    sudo cp ~/.cloudflared/<TUNNEL-ID>.json /etc/cloudflared/"
  echo ""
  echo " 5. DNS record:"
  echo "    cloudflared tunnel route dns ${TUNNEL_NAME} ${TUNNEL_HOSTNAME}"
  echo ""
  echo " 6. Start service:"
  echo "    sudo cloudflared service install"
  echo "    sudo systemctl enable cloudflared"
  echo "    sudo systemctl start cloudflared"
  echo ""
  echo " 7. GitHub webhook URL:"
  echo "    https://${TUNNEL_HOSTNAME}/github-webhook/"
  echo ""
fi

echo "=========================================="
echo " SECURITY REMINDERS"
echo "=========================================="
echo ""
echo "  - Change the default password after first login."
echo "  - Do not commit this script to a public repo"
echo "    with the password in plaintext."
echo "  - Set Jenkins URL in Manage Jenkins > System"
echo "    to your public tunnel URL."
echo ""
echo "=========================================="