# Cloud & DevOps Skills with Ansible

This Ansible POC now includes roles for AWS, GCP, and Kubernetes tools - giving you hands-on experience with the most in-demand cloud technologies.

## 🎯 Resume-Boosting Skills

### What You'll Learn

**Cloud Platforms:**
- ✅ **AWS (Amazon Web Services)** - World's leading cloud platform
- ✅ **GCP (Google Cloud Platform)** - Google's cloud infrastructure
- ✅ **Multi-cloud** - Experience with multiple providers

**Container Orchestration:**
- ✅ **Kubernetes** - Industry-standard container orchestration
- ✅ **Helm** - Kubernetes package management
- ✅ **Docker/containers** - Containerization fundamentals

**Infrastructure as Code:**
- ✅ **Ansible** - Configuration management
- ✅ **Terraform** - Infrastructure provisioning (installed via Homebrew)

**Resume Keywords You'll Gain:**
```
AWS CLI, EC2, S3, IAM, EKS, Lambda
Google Cloud Platform, GCP, GKE, Cloud Run
Kubernetes, kubectl, Helm, K8s, container orchestration
Docker, containers, containerization
Infrastructure as Code, IaC, Ansible, automation
CI/CD, DevOps, cloud engineering
Multi-cloud, hybrid cloud
```

## 📦 What Gets Installed

### AWS Tools

**Core:**
- **AWS CLI v2** - Official AWS command-line interface
- **aws-vault** - Secure credential storage
- **awscli-local** - LocalStack integration for local AWS testing
- **chamber** - Secrets management with AWS SSM

**Configuration:**
- `~/.aws/config` - AWS profiles and settings
- `~/.aws/credentials` - AWS access keys (you configure)

### GCP Tools

**Core:**
- **Google Cloud SDK (gcloud)** - Official GCP CLI
- **gke-gcloud-auth-plugin** - GKE cluster authentication

**Components you can add:**
```bash
gcloud components install kubectl    # Kubernetes
gcloud components install terraform  # Infrastructure as Code
gcloud components install beta       # Beta features
```

### Kubernetes Tools

**CLI Tools:**
- **kubectl** - Kubernetes CLI (latest stable)
- **helm** - Package manager for Kubernetes
- **k9s** - Terminal UI for Kubernetes clusters
- **kubectx** - Fast context switching
- **kubens** - Fast namespace switching
- **stern** - Multi-pod log tailing
- **kustomize** - Template-free Kubernetes configuration

**Local Development:**
- **kind** - Kubernetes in Docker (local clusters)
- **minikube** - Local Kubernetes clusters
- **skaffold** - Continuous development for Kubernetes

**Shell Aliases:**
- 50+ kubectl aliases in `~/.config/zsh/k8s-aliases`
- Auto-completion for kubectl

## 🚀 Quick Start

### Install All Cloud Tools

```bash
cd ~/dots/ansible-poc

# Install all cloud tools
ansible-playbook playbook.yml --tags cloud

# Or install individually:
ansible-playbook playbook.yml --tags aws
ansible-playbook playbook.yml --tags gcp
ansible-playbook playbook.yml --tags kubernetes
```

### AWS Setup

**1. Install AWS CLI:**
```bash
ansible-playbook playbook.yml --tags aws
```

**2. Configure credentials:**
```bash
# Method 1: Interactive
aws configure

# Method 2: Environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

# Method 3: AWS SSO (recommended for organizations)
aws configure sso
```

**3. Test your setup:**
```bash
# Verify CLI works
aws --version

# Check current identity
aws sts get-caller-identity

# List S3 buckets
aws s3 ls

# List EC2 instances
aws ec2 describe-instances --region us-east-1
```

### GCP Setup

**1. Install Google Cloud SDK:**
```bash
ansible-playbook playbook.yml --tags gcp
```

**2. Initialize and authenticate:**
```bash
# Interactive setup
gcloud init

# Or manual authentication
gcloud auth login

# For application default credentials
gcloud auth application-default login
```

**3. Set project:**
```bash
# List projects
gcloud projects list

# Set default project
gcloud config set project PROJECT_ID
```

**4. Test your setup:**
```bash
# Verify installation
gcloud --version

# Check current config
gcloud config list

# List compute instances
gcloud compute instances list

# List GKE clusters
gcloud container clusters list
```

### Kubernetes Setup

**1. Install Kubernetes tools:**
```bash
ansible-playbook playbook.yml --tags kubernetes
```

**2. Connect to a cluster:**

**For AWS EKS:**
```bash
# Update kubeconfig for EKS cluster
aws eks update-kubeconfig \
  --name my-cluster \
  --region us-east-1

# Verify connection
kubectl cluster-info
kubectl get nodes
```

**For Google GKE:**
```bash
# Get credentials for GKE cluster
gcloud container clusters get-credentials my-cluster \
  --region us-central1 \
  --project my-project

# Verify connection
kubectl cluster-info
kubectl get nodes
```

**For local development:**
```bash
# Create local cluster with kind
kind create cluster --name dev

# Or with minikube
minikube start

# Verify
kubectl get nodes
```

**3. Use the tools:**

```bash
# List pods (use alias)
kgp  # same as: kubectl get pods

# Get pods from all namespaces
kubectl get pods --all-namespaces

# Launch k9s terminal UI
k9s

# Switch context with kubectx
kubectx  # List contexts
kubectx production  # Switch to production

# Switch namespace with kubens
kubens  # List namespaces
kubens kube-system  # Switch to kube-system

# View logs with stern
stern pod-name

# Install Helm chart
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-release bitnami/nginx
```

## 💼 Resume-Building Projects

### Beginner Projects

**1. AWS EC2 Instance Management**
```bash
# Launch an instance
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t2.micro \
  --key-name my-key

# List instances
aws ec2 describe-instances

# Stop instance
aws ec2 stop-instances --instance-ids i-1234567890abcdef0
```

**2. GCP VM Management**
```bash
# Create instance
gcloud compute instances create my-instance \
  --zone=us-central1-a \
  --machine-type=e2-micro

# List instances
gcloud compute instances list

# SSH into instance
gcloud compute ssh my-instance --zone=us-central1-a
```

**3. Local Kubernetes Cluster**
```bash
# Create cluster
kind create cluster --name learning

# Deploy nginx
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# View deployment
kubectl get all
```

### Intermediate Projects

**4. Deploy Application to EKS**
```bash
# Create EKS cluster (via AWS Console or eksctl)
eksctl create cluster --name dev-cluster --region us-east-1

# Update kubeconfig
aws eks update-kubeconfig --name dev-cluster --region us-east-1

# Deploy application
kubectl apply -f deployment.yaml

# Expose with LoadBalancer
kubectl expose deployment my-app --type=LoadBalancer --port=80
```

**5. GKE with Helm**
```bash
# Create GKE cluster
gcloud container clusters create my-cluster \
  --zone us-central1-a \
  --num-nodes 3

# Get credentials
gcloud container clusters get-credentials my-cluster --zone us-central1-a

# Install app with Helm
helm repo add stable https://charts.helm.sh/stable
helm install my-app stable/wordpress
```

**6. Multi-environment Setup**
```yaml
# Use Kubernetes namespaces for dev/staging/prod
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod

# Deploy to different environments
kubectl apply -f app.yaml --namespace dev
kubectl apply -f app.yaml --namespace prod
```

### Advanced Projects

**7. CI/CD Pipeline**
```bash
# Use GitHub Actions + AWS/GCP + Kubernetes
# - Build Docker image
# - Push to ECR/GCR
# - Deploy to EKS/GKE
# - Run tests
```

**8. Infrastructure as Code**
```hcl
# Terraform + Ansible
# Use Terraform to provision infrastructure
# Use Ansible to configure instances
```

**9. Observability Stack**
```bash
# Deploy Prometheus + Grafana to Kubernetes
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack
```

## 📚 Learning Resources

### AWS

**Official:**
- [AWS Documentation](https://docs.aws.amazon.com/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
- [AWS Free Tier](https://aws.amazon.com/free/) - Practice for free

**Tutorials:**
- [AWS Getting Started](https://aws.amazon.com/getting-started/)
- [AWS Skill Builder](https://skillbuilder.aws/) - Free training
- [A Cloud Guru](https://acloudguru.com/) - Video courses

### GCP

**Official:**
- [GCP Documentation](https://cloud.google.com/docs)
- [gcloud CLI Reference](https://cloud.google.com/sdk/gcloud/reference)
- [GCP Free Tier](https://cloud.google.com/free) - $300 free credit

**Tutorials:**
- [GCP Quickstarts](https://cloud.google.com/docs/tutorials)
- [Qwiklabs](https://www.cloudskillsboost.google/) - Hands-on labs
- [Google Cloud Skills Boost](https://www.cloudskillsboost.google/) - Learning paths

### Kubernetes

**Official:**
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Tutorials](https://kubernetes.io/docs/tutorials/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

**Courses:**
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Deep dive
- [KodeKloud](https://kodekloud.com/) - Interactive K8s courses
- [Linux Academy/A Cloud Guru](https://acloudguru.com/) - Comprehensive courses

**Books:**
- "Kubernetes in Action" - Marko Lukša
- "Kubernetes Up & Running" - Kelsey Hightower
- "The Kubernetes Book" - Nigel Poulton

## 🎓 Certification Paths

### AWS Certifications

**Associate Level:**
- **AWS Certified Solutions Architect - Associate**
  - Most popular AWS cert
  - Great for career advancement
  - Covers EC2, S3, VPC, IAM, etc.

- **AWS Certified Developer - Associate**
  - For developers using AWS
  - Covers Lambda, DynamoDB, API Gateway

**Professional Level:**
- AWS Certified Solutions Architect - Professional
- AWS Certified DevOps Engineer - Professional

### GCP Certifications

**Associate:**
- **Google Cloud Associate Cloud Engineer**
  - Entry-level certification
  - Covers GCE, GCS, GKE, IAM

**Professional:**
- Google Cloud Professional Cloud Architect
- Google Cloud Professional DevOps Engineer

### Kubernetes Certifications

- **CKA (Certified Kubernetes Administrator)**
  - Hands-on exam
  - Highly valued
  - Focuses on cluster management

- **CKAD (Certified Kubernetes Application Developer)**
  - For developers
  - Application deployment focus

- **CKS (Certified Kubernetes Security Specialist)**
  - Advanced security focus

## 💡 Practice Environments

### Free Tier Accounts

**AWS Free Tier:**
- 750 hours/month of t2.micro EC2 instances
- 5 GB S3 storage
- Limited Lambda executions
- Many services free for 12 months

**GCP Free Tier:**
- $300 credit for 90 days
- Always-free tier afterwards
- e2-micro VM instances
- Cloud Storage, Cloud Functions

### Local Development

**Docker Desktop:**
```bash
# Included Kubernetes
# Settings → Kubernetes → Enable Kubernetes
kubectl config use-context docker-desktop
```

**kind (Kubernetes in Docker):**
```bash
# Create multi-node cluster
kind create cluster --config kind-config.yaml

# Example config for 3-node cluster
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
```

**Minikube:**
```bash
# Start cluster
minikube start --nodes 3

# Enable addons
minikube addons enable dashboard
minikube addons enable ingress
```

## 🔧 Troubleshooting

### AWS

**Credentials not working:**
```bash
# Check current credentials
aws sts get-caller-identity

# Check config files
cat ~/.aws/credentials
cat ~/.aws/config

# Test with specific profile
aws s3 ls --profile dev
```

### GCP

**Authentication issues:**
```bash
# Re-authenticate
gcloud auth login

# Check active account
gcloud auth list

# Check current project
gcloud config get-value project
```

### Kubernetes

**Connection issues:**
```bash
# Check kubeconfig
kubectl config view

# Check current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context my-cluster
```

**Pod debugging:**
```bash
# Get pod logs
kubectl logs pod-name

# Describe pod
kubectl describe pod pod-name

# Execute command in pod
kubectl exec -it pod-name -- /bin/bash

# Port forward
kubectl port-forward pod-name 8080:80
```

## 📋 Useful Aliases (Installed)

All in `~/.config/zsh/k8s-aliases`:

```bash
# kubectl shortcuts
k='kubectl'
kgp='kubectl get pods'
kgs='kubectl get svc'
kgd='kubectl get deployments'
kgn='kubectl get nodes'
klf='kubectl logs -f'
kaf='kubectl apply -f'
kex='kubectl exec -it'

# Context/namespace switching
kx='kubectx'   # Switch context
kn='kubens'    # Switch namespace

# Helm shortcuts
h='helm'
hls='helm list'
hi='helm install'
hu='helm upgrade'

# K9s
k9='k9s'
```

## 🎯 Resume Impact

**Before:**
```
Skills: Python, Git, Linux
```

**After:**
```
Skills:
- Cloud Platforms: AWS (EC2, S3, Lambda, EKS), Google Cloud Platform (GCE, GKE)
- Container Orchestration: Kubernetes, Docker, Helm
- Infrastructure as Code: Ansible, Terraform
- CI/CD: GitHub Actions, GitLab CI
- DevOps Tools: kubectl, gcloud, aws-cli, k9s
- Automation: Bash, Python, Ansible playbooks
```

**Project Examples for Resume:**
- "Deployed multi-tier application to AWS EKS with Kubernetes and Helm"
- "Automated infrastructure provisioning using Ansible and Terraform"
- "Managed multi-cloud environments across AWS and GCP"
- "Implemented CI/CD pipeline with GitHub Actions deploying to Kubernetes"
- "Configured and managed Kubernetes clusters with kubectl and k9s"

## 🚀 Next Steps

1. **Install the tools:**
   ```bash
   ansible-playbook playbook.yml --tags cloud
   ```

2. **Create free accounts:**
   - AWS Free Tier
   - GCP Free Trial ($300 credit)

3. **Start with basics:**
   - Deploy a VM on each platform
   - Create a local Kubernetes cluster
   - Practice kubectl commands

4. **Build projects:**
   - Start with beginner projects
   - Document everything
   - Add to GitHub portfolio

5. **Consider certification:**
   - AWS Solutions Architect Associate
   - Or GCP Associate Cloud Engineer
   - Or CKA (Kubernetes)

6. **Apply knowledge:**
   - Use at current job
   - Contribute to open source
   - Build side projects
   - Interview for DevOps roles

---

**These tools + Ansible experience = Strong DevOps/Cloud Engineer Resume!**
