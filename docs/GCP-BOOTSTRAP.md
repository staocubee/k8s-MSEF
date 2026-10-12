# Bringing MSEF up on a blank GCP project

Order: **A** configure the repo → **B** one-time bootstrap in Cloud Shell →
**C** GitHub settings → **D** GitHub Actions → **E** verify → experiments
(`MSEFv2-RUNBOOK.md`). Steps marked *owner* need Owner on the new project.

Why step B is manual: every workflow authenticates through Workload Identity
Federation, and the WIF pool is itself created by `terraform/bootstrap-state`.
A human applies that layer once; after that, CI runs everything else.

## A. Configure the repository (your machine)

1. Merge `msefv2-harness-fixes` into `main`. Argo CD deploys from `main`, so
   the cluster would otherwise sync the v1 KRE and rules.
2. Point the repo at the new project (dev only; add `--envs dev,stg,prod` later if needed):
   ```bash
   python3 scripts/configure-gcp-project.py --project <PROJECT_ID> --region <REGION>
   ```
   Use one region for everything (e.g. `us-east1`). Commit, **but push after step C**:
   a push to `main` runs a `dev` plan, which needs the GitHub variables from step C.

## B. One-time bootstrap (Cloud Shell, *owner*)

```bash
# 1. Project and billing (or use the console)
gcloud projects create <PROJECT_ID>
gcloud billing projects link <PROJECT_ID> --billing-account=<BILLING_ACCOUNT_ID>
gcloud config set project <PROJECT_ID>
gcloud services enable serviceusage.googleapis.com cloudresourcemanager.googleapis.com

# 2. Apply bootstrap-state with LOCAL state (its own bucket does not exist yet)
git clone https://github.com/staocubee/k8s-MSEF.git && cd k8s-MSEF   # your configured commit
cd terraform/bootstrap-state/envs/dev
cat > backend_override.tf <<'HCL'
terraform {
  backend "local" {}
}
HCL
terraform init
terraform apply          # APIs, state bucket, Artifact Registry, WIF pool + provider, CI service account + roles

# 3. Move that state into the bucket it just created
rm backend_override.tf
terraform init -migrate-state      # answer "yes"
rm -f terraform.tfstate terraform.tfstate.backup

# 4. Values for step C
terraform output -raw workload_identity_provider
terraform output -raw github_actions_service_account
```

If you cloned before pushing, copy your configured `terraform/` changes into
Cloud Shell first (or push to a branch and clone that branch).

## C. GitHub settings (repo admin)

Repository variables (Settings → Secrets and variables → Actions → Variables):

| Variable | Value |
| --- | --- |
| `GCP_PROJECT_ID` | new project ID |
| `GCP_REGION` | region used in step A |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `workload_identity_provider` output |
| `GCP_SERVICE_ACCOUNT` | `github_actions_service_account` output |

Unchanged and still required: variables `DOCKERHUB_USERNAME`, `REPORT_IMAGE_NAME`;
secrets `DOCKERHUB_TOKEN`, `COSIGN_PRIVATE_KEY`, `COSIGN_PASSWORD`. Keep the same
Cosign key: the public key in `k8s/policies/kyverno/verify-signed-images.yaml`
must match it, and existing image signatures on Docker Hub stay valid.

Environment (Settings → Environments): create `dev-apply` and add yourself as a
required reviewer, so every apply waits for approval.

Now push `main`. The push runs a `dev` plan of bootstrap-state only.

## D. GitHub Actions, in this order

| # | Workflow | Inputs | Creates |
| --- | --- | --- | --- |
| 1 | Terraform Foundation | dev, apply | workload service accounts + IAM |
| 2 | Terraform Infra | dev, apply | VPC, NAT, regional GKE (Calico NetworkPolicy, Workload Identity) |
| 3 | Build and Sign KRE Image | `v2.1.0` | signed `staocube/msef-kre-handler:v2.1.0` |
| 4 | Terraform Bootstrap | dev, apply | Argo CD + root app; Argo then syncs `gitops/` |

Run 3 before 4 so Kyverno admits the KRE pod on first sync (otherwise it retries until signed).

## E. Verify before any experiment

```bash
gcloud container clusters get-credentials dev-msef-gke --region <REGION>
kubectl -n argocd get applications            # all Synced / Healthy
kubectl -n falco get pods                      # one per node, Running
kubectl -n falco logs ds/falco -c falco | grep -i -m3 "msef\|error"
kubectl -n hardened get deploy msef-kre-handler
kubectl -n hardened logs deploy/msef-kre-handler | grep "rule plans"   # "10 rule plans"
kubectl get constraints                        # Gatekeeper constraints present
kubectl get clusterpolicy verify-signed-images # Kyverno policy present
kubectl -n kube-system get pods -l k8s-app=calico-node   # NetworkPolicy enforcement running
python3 tests/test_rule_consistency.py         # repo-side consistency
```

Capacity: the regional node pool counts nodes **per zone** (`node_count = 1` →
3 nodes). Gatekeeper, Kyverno, Falco, Argo CD, Istio, Kafka, Elasticsearch and
monitoring together can leave pods Pending on `e2-standard-2`; if so, raise
`node_machine_type` or `node_count` in `terraform/infra/envs/dev/terraform.tfvars`.
Whatever you choose, keep the node shape and the set of background components
identical across C0–C5, and record them; they affect latency and resource results.

## F. Evaluation workflows

Run **Run Security Orchestrator** (or **Security Evaluation**; both now call
`scripts/run-k8s-security-evaluation.sh`). It starts with
`scripts/preflight-cluster.sh` and stops if Argo CD apps, Gatekeeper, Kyverno,
Falco, KRE or metrics-server are not ready. Each harness runs once:

| Layer | Script | Produces |
| --- | --- | --- |
| L2 | `measure-mbr.sh` (seeded fuzzer), `measure-nper.sh`, `measure-smer.sh`, `measure-pes.sh` | MBR, NPER, SMER, PES |
| L3 | `measure-spr.sh` → `measure-ies.sh` reports | SPR, IES |
| L4 | `measure-rdr.sh` runs the runtime suite once → `measure-mttd/-fpr/-rrsr.sh` report | RDR, MTTD, MTTC, OFPR, RRSR |
| L4 | `measure-des.sh` | DES |

Results upload as an artifact even if a later step fails. Admission latency and
the C0–C5 ablation are run from a workstation (`MSEFv2-RUNBOOK.md`), because
each configuration requires deliberately reconfiguring the cluster.
`terraform-bootstrap` no longer auto-starts an evaluation.

## Teardown

Run **Terraform Destroy** (dev). The state bucket is kept (`force_destroy = false`).
To stop all charges, delete the project. The old `msef-2026` project is not touched
by any of this; delete it separately if it is no longer needed.
