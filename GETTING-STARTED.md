# 🎓 Getting Started - Modern DevOps Workshop

## Welcome! 👋

This guide will help you quickly get started with upgrading your k8s-mario application from a classic Jenkins pipeline to a modern GitOps DevSecOps pipeline.

## ⚡ Two Ways to Start

### Option A: Automated Setup (Recommended for Beginners)
**Time:** ~30-45 minutes  
**Difficulty:** Easy

```bash
# 1. Navigate to the project
cd /Users/trdr/Documents/k8s-mario

# 2. Run the automated setup
./setup.sh

# 3. Validate the installation
./validate.sh
```

That's it! The script will guide you through the entire setup.

### Option B: Manual Workshop (Recommended for Learning)
**Time:** 6-8 hours  
**Difficulty:** Intermediate to Advanced

Follow the complete step-by-step workshop in:
📘 [MODERN-DEVOPS-WORKSHOP.md](MODERN-DEVOPS-WORKSHOP.md)

## 📋 Before You Begin

### Prerequisites Checklist

Make sure you have:

- ✅ **AWS Account** with admin access
- ✅ **AWS CLI** configured (`aws configure`)
- ✅ **kubectl** installed
- ✅ **helm** installed
- ✅ **docker** installed and running
- ✅ **terraform** installed
- ✅ **git** installed

Quick check:
```bash
aws --version
kubectl version --client
helm version
docker --version
terraform --version
git --version
```

### AWS Permissions Required

Your AWS user needs permissions for:
- EKS (create clusters, node groups)
- EC2 (create instances, security groups)
- VPC (use default VPC)
- ECR (create repositories)
- IAM (create roles for EKS)

## 🗺️ Your Learning Path

### Phase 1: Infrastructure Setup (30 minutes)
- Provision EKS cluster with Terraform
- Configure kubectl access

### Phase 2: GitOps Foundation (45 minutes)
- Restructure repository with Kustomize
- Install and configure Argo CD
- Deploy application via GitOps

### Phase 3: Security & Policies (1 hour)
- Install OPA Gatekeeper
- Create and apply policies
- Test policy enforcement

### Phase 4: Progressive Delivery (1.5 hours)
- Install Istio service mesh
- Configure Flagger for canary deployments
- Test automated rollouts and rollbacks

### Phase 5: Observability (45 minutes)
- Deploy Prometheus & Grafana
- Configure metrics collection
- Import dashboards

### Phase 6: CI/CD Pipeline (1 hour)
- Set up GitHub Actions
- Configure security scanning
- Automate GitOps updates

### Phase 7: Testing & Validation (1 hour)
- End-to-end deployment testing
- Policy validation
- Canary deployment testing

## 🚀 Quick Start Commands

### Start the Workshop

```bash
# Clone or navigate to repository
cd /Users/trdr/Documents/k8s-mario

# Option 1: Automated
./setup.sh

# Option 2: Manual - start with EKS
cd EKS-TF
terraform init
terraform plan
terraform apply
```

### Verify Each Stage

```bash
# Check EKS cluster
kubectl cluster-info

# Check Argo CD
kubectl get pods -n argocd

# Check policies
kubectl get constrainttemplates

# Check canary setup
kubectl get canary -n production

# Check monitoring
kubectl get pods -n monitoring
```

### Access the UIs

```bash
# Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
# Get password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Grafana UI
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open: http://localhost:3000
# Get password:
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d

# Mario App (once deployed)
kubectl get svc -n production mario-service
# Access the EXTERNAL-IP
```

## 📚 Documentation Structure

```
📁 k8s-mario/
├── 📄 README.md                    ← Overview & quick start
├── 📘 MODERN-DEVOPS-WORKSHOP.md    ← Complete workshop (START HERE for manual)
├── 📗 QUICK-REFERENCE.md           ← Command cheat sheet
├── 📄 GETTING-STARTED.md           ← This file
├── 🔧 setup.sh                     ← Automated setup script
└── ✅ validate.sh                  ← Validation script
```

**Reading Order:**
1. **README.md** - Understand what you're building
2. **GETTING-STARTED.md** (this file) - Choose your path
3. **MODERN-DEVOPS-WORKSHOP.md** - Follow the detailed workshop
4. **QUICK-REFERENCE.md** - Keep handy for commands

## 🎯 What You'll Build

### Classic Pipeline (Before)
```
Developer → Jenkins → kubectl apply → EKS
```

### Modern GitOps Pipeline (After)
```
┌─────────────┐
│ Developer   │
│ git push    │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────┐
│ GitHub Actions (CI)              │
│ • Lint & Test                    │
│ • Security Scan (Trivy)          │
│ • Build Image                    │
│ • Push to ECR                    │
│ • Update GitOps Repo             │
└──────┬───────────────────────────┘
       │
       ▼
┌──────────────────────────────────┐
│ Argo CD (GitOps)                 │
│ • Detect Git changes             │
│ • Run OPA Policy Gates           │
│ • Deploy to K8s                  │
└──────┬───────────────────────────┘
       │
       ▼
┌──────────────────────────────────┐
│ Flagger (Progressive Delivery)   │
│ • Canary → 10% → 20% → 50%      │
│ • Monitor metrics                │
│ • Auto promote or rollback       │
└──────────────────────────────────┘
```

## 🔑 Key Concepts You'll Learn

### GitOps
- **Git as single source of truth** - All config in Git
- **Declarative infrastructure** - Describe desired state
- **Automated sync** - System auto-heals on drift
- **Easy rollbacks** - Just `git revert`

### Progressive Delivery
- **Canary deployments** - Gradual traffic shifting
- **Automated rollback** - Based on metrics
- **Blue-green** - Zero-downtime deployments

### Policy as Code
- **Admission control** - Block bad configs before they deploy
- **Compliance** - Enforce security standards
- **Shift-left** - Catch issues early

### Observability
- **Metrics** - Prometheus collects data
- **Visualization** - Grafana displays dashboards
- **Alerts** - Get notified of issues

## 💡 Tips for Success

### 1. Take Your Time
Don't rush. Understand each concept before moving on.

### 2. Use the Validation Script
After each major step, run:
```bash
./validate.sh
```

### 3. Check the Quick Reference
Keep [QUICK-REFERENCE.md](QUICK-REFERENCE.md) open for commands.

### 4. Experiment
Try breaking things! That's how you learn:
- Deploy with `:latest` tag (should be blocked)
- Manually scale pods (GitOps will reconcile)
- Deploy a bad version (canary will rollback)

### 5. Use the Troubleshooting Guide
If stuck, check the troubleshooting section in the main workshop.

## 🐛 Common Issues & Quick Fixes

### "kubectl: command not found"
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/
```

### "AWS credentials not configured"
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Region: ap-south-1
# Output format: json
```

### "Cannot connect to Docker daemon"
```bash
# macOS - start Docker Desktop
open -a Docker

# Linux
sudo systemctl start docker
```

### "EKS cluster not accessible"
```bash
# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name EKS_CLOUD

# Verify
kubectl cluster-info
```

## 📞 Getting Help

### During the Workshop

1. **Check the logs**
   ```bash
   kubectl logs <pod-name> -n <namespace>
   ```

2. **Describe resources**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```

3. **Check events**
   ```bash
   kubectl get events -n <namespace> --sort-by='.lastTimestamp'
   ```

4. **Review the troubleshooting guide**
   See Module 11 in [MODERN-DEVOPS-WORKSHOP.md](MODERN-DEVOPS-WORKSHOP.md)

### Additional Resources

- **Argo CD Docs:** https://argo-cd.readthedocs.io/
- **Flagger Docs:** https://docs.flagger.app/
- **OPA Gatekeeper:** https://open-policy-agent.github.io/gatekeeper/
- **Istio Docs:** https://istio.io/latest/docs/

## ✅ Success Criteria

You'll know you're successful when:

- ✅ You can deploy by just pushing to Git
- ✅ Argo CD automatically syncs your changes
- ✅ Policies block insecure configurations
- ✅ Canary deployments work with auto-rollback
- ✅ You can rollback with `git revert`
- ✅ You understand each component's purpose

## 🎓 What's Next?

After completing the workshop:

### 1. Enhance Your Setup
- Add more environments (staging, QA)
- Implement secrets management (External Secrets)
- Add disaster recovery (Velero backups)
- Multi-cluster deployments

### 2. Learn More
- Get GitOps Certified (CNCF)
- Kubernetes certifications (CKA, CKAD, CKS)
- Service mesh deep dive

### 3. Apply to Real Projects
- Migrate your existing applications
- Build new projects with GitOps from day 1
- Share knowledge with your team

## 🚀 Ready?

Choose your path and let's get started!

**For automated setup:**
```bash
./setup.sh
```

**For manual workshop:**
Open [MODERN-DEVOPS-WORKSHOP.md](MODERN-DEVOPS-WORKSHOP.md) and start with Module 1.

---

**Good luck! 🍀**

You're about to build a production-grade, modern DevOps pipeline. Enjoy the journey!
