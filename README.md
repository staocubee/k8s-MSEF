# k8s-MSEF
K8s-MSEF/
│
├── Project Overview
├── Architecture
├── Research Objectives
├── Framework Layers
│     ├── Prevention
│     ├── Integrity
│     └── Detection
│
├── Repository Structure
│
├── Prerequisites
│
├── Local Deployment
│
├── Cloud Deployment (GCP)
│
├── Terraform Deployment
│     ├── Foundation
│     ├── Infrastructure
│     ├── Bootstrap
│
├── GitHub Actions
│
├── GitOps Deployment
│
├── Supply Chain Security
│
├── Runtime Security
│
├── Security Evaluation
│
├── Composite Metrics
│
├── Report Generation
│
├── HTML Report Server
│
├── Destroy Environment
│
├── Screenshots
│
├── Citation
│
└── License

1. Project Overview

K8s-MSEF is a Kubernetes Multi-Layer Security Evaluation Framework that quantitatively evaluates Kubernetes security across Prevention, Integrity and Detection layers using reproducible experiments.

2. Architecture
Developer

↓

GitHub

↓

GitHub Actions

↓

Terraform

↓

GKE

↓

ArgoCD

↓

Platform Services

↓

Workloads

↓

Security Evaluation

↓

HTML Report

3. Research Objectives

- automate Kubernetes hardening
- evaluate security posture
- produce reproducible metrics

4. Framework Layers
Prevention Layer

Components

Gatekeeper
Pod Security Admission
NetworkPolicy
Secrets Policy

Metrics

MBR
NPER
SMER
PES
Integrity Layer

Components

Cosign
Kyverno

Metrics

SPR
IES
Detection Layer

Components

Falco

Metrics

RDR
MTTD
FPR
RRSR
DES

5. Repository Structure
terraform/

foundation/

infra/

bootstrap/

gitops/

platform/

workloads/

k8s/

insecure-manifests/

network-test/

secret-test/

response-test/

integrity-test/

scripts/

results/

.github/

workflows/

README.md

6. Prerequisites
Terraform
kubectl
Helm
gcloud
Docker
Cosign
GitHub CLI
ArgoCD CLI
jq
bc

7. Local Deployment
Colima was used for local deployment

8. Cloud Deployment
GCP Project
↓
Artifact Registry
↓
GKE
↓
Workload Identity
↓
IAM
↓
State Bucket
9. Terraform Deployment

Foundation Creates
APIs
Service Accounts
Workload Identity
Artifact Registry
State Bucket

Run
terraform init
terraform plan
terraform apply
Infrastructure Creates
VPC
Subnet
NAT
Router
GKE
Node Pool
Bootstrap

Installs
ArgoCD
cert-manager
Gatekeeper
Kyverno
Falco

10. GitHub Actions
Workflow	Purpose
terraform-foundation.yml	Provision foundation resources
terraform-infra.yml	Deploy networking and GKE
terraform-bootstrap.yml	Install ArgoCD and platform services
build-sign-deploy-report.yml	Build, sign, and publish report server
run-security-evaluation.yml	Execute all MSEF experiments
security-orchestrator.yml	End-to-end security workflow
terraform-destroy.yml	Destroy infrastructure

11. GitOps Deployment
gitops/
platform/
workloads/


12. Supply Chain Security
Build
docker build
Scan
Trivy
Generate SBOM
Sign
cosign sign
Verify
Kyverno VerifyImages

Docker Build
↓
Trivy
↓
Cosign
↓
Artifact Registry
↓
Kyverno
↓
Kubernetes
13. Runtime Security
Falco
Rules
Runtime Detection
Automatic Response

14. Security Evaluation
Script	Metric
measure-mbr.sh	MBR
measure-nper.sh	NPER
measure-smer.sh	SMER
measure-pes.sh	PES
measure-spr.sh	SPR
measure-ies.sh	IES
measure-rdr.sh	RDR
measure-mttd.sh	MTTD
measure-fpr.sh	FPR
measure-rrsr.sh	RRSR
measure-des.sh	DES

15. Composite Metrics
Layer	Composite
Prevention	PES
Integrity	IES
Detection	DES

PES=Average(MBR, NPER, SMER)
IES=SPR
DES=Average(RDR,RRSR,1−FPR,Normalized MTTD)

16. Running Evaluation
./scripts/run-k8s-security-evaluation.sh
Outputs
results/
json/
txt/
logs/
index.html
17. HTML Report
generate-security-report.sh
↓
generate-html-report.sh
↓
results/index.html

18. Security Report

MBR
NPER
SMER
PES
SPR
IES
RDR
MTTD
FPR
RRSR
DES
19. Destroy
terraform-destroy.yml
20. Screenshots
ArgoCD
Falco
Kyverno
Gatekeeper
GitHub Actions
Evaluation Report
HTML Dashboard

21. Citation
@misc{solomon2026k8smsef,
  title={Kubernetes Multi-Layer Security Evaluation Framework},
  author={Solomon, Oluwatobi Seun},
  year={2026},
  publisher={GitHub}
}
22. License
MIT

terraform destroy

gcloud storage rm -r gs://msef-2026-dev-tfstate

gcloud artifacts repositories delete dev-k8s-msef \
  --location=us-central1 \
  --quiet

gcloud iam workload-identity-pools delete dev-github-pool \
  --location=global \
  --quiet

  TF_LOG=DEBUG terraform apply