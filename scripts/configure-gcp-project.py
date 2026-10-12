#!/usr/bin/env python3
"""
Point the whole repository at one GCP project, region and GitHub repo.

  python3 scripts/configure-gcp-project.py --project <PROJECT_ID> --region <REGION> \
      [--github-owner staocubee --github-repo k8s-MSEF] [--envs dev] [--dry-run]

Rewrites, for each selected environment:
  terraform/{bootstrap-state,foundation,infra}/envs/<env>/terraform.tfvars
      project_id, region, state_bucket_name (= <project>-<env>-tfstate), github_owner/repo
  terraform/{bootstrap-state,foundation,infra}/envs/<env>/backend.tf     bucket
  terraform/bootstrap/envs/<env>/{terraform.tfvars,versions.tf}         project_id, region, repo_url, bucket
and, when the GitHub owner/repo changes, every repoURL under gitops/.
Deliberately untouched: pre-deployment/test-artifacts (scanner fixtures).
Bucket names are global: the script refuses names GCS would reject.
"""
import argparse, glob, os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def sub(path, pattern, repl, changes, dry, flags=re.M):
    if not os.path.exists(path): return
    s = open(path).read(); n = re.sub(pattern, repl, s, flags=flags)
    if n != s:
        changes.append(os.path.relpath(path, ROOT))
        if not dry: open(path, "w").write(n)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True); ap.add_argument("--region", required=True)
    ap.add_argument("--github-owner", default="staocubee"); ap.add_argument("--github-repo", default="k8s-MSEF")
    ap.add_argument("--envs", default="dev", help="comma-separated, e.g. dev or dev,stg,prod")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", a.project):
        sys.exit(f"'{a.project}' is not a valid GCP project ID")
    if not re.fullmatch(r"[a-z]+-[a-z]+[0-9]", a.region):
        sys.exit(f"'{a.region}' does not look like a GCP region (e.g. us-east1)")
    changes = []
    for env in a.envs.split(","):
        bucket = f"{a.project}-{env}-tfstate"
        if len(bucket) > 63: sys.exit(f"bucket name {bucket} exceeds 63 characters")
        for layer in ("bootstrap-state", "foundation", "infra"):
            d = os.path.join(ROOT, "terraform", layer, "envs", env)
            tv = os.path.join(d, "terraform.tfvars")
            sub(tv, r'^(\s*project_id\s*=\s*)"[^"]*"', rf'\1"{a.project}"', changes, a.dry_run)
            sub(tv, r'^(\s*region\s*=\s*)"[^"]*"', rf'\1"{a.region}"', changes, a.dry_run)
            sub(tv, r'^(\s*state_bucket_name\s*=\s*)"[^"]*"', rf'\1"{bucket}"', changes, a.dry_run)
            sub(tv, r'^(\s*github_owner\s*=\s*)"[^"]*"', rf'\1"{a.github_owner}"', changes, a.dry_run)
            sub(tv, r'^(\s*github_repo\s*=\s*)"[^"]*"', rf'\1"{a.github_repo}"', changes, a.dry_run)
            sub(os.path.join(d, "backend.tf"), r'^(\s*bucket\s*=\s*)"[^"]*"', rf'\1"{bucket}"', changes, a.dry_run)
        bd = os.path.join(ROOT, "terraform", "bootstrap", "envs", env)
        tv = os.path.join(bd, "terraform.tfvars")
        sub(tv, r'^(\s*project_id\s*=\s*)"[^"]*"', rf'\1"{a.project}"', changes, a.dry_run)
        sub(tv, r'^(\s*region\s*=\s*)"[^"]*"', rf'\1"{a.region}"', changes, a.dry_run)
        sub(tv, r'^(\s*repo_url\s*=\s*)"[^"]*"', rf'\1"https://github.com/{a.github_owner}/{a.github_repo}.git"', changes, a.dry_run)
        sub(os.path.join(bd, "versions.tf"), r'^(\s*bucket\s*=\s*)"[^"]*"', rf'\1"{bucket}"', changes, a.dry_run)
    new_url = f"https://github.com/{a.github_owner}/{a.github_repo}.git"
    for f in glob.glob(os.path.join(ROOT, "gitops", "**", "*.yaml"), recursive=True):
        sub(f, r'(repoURL:\s*)https://github\.com/[^/\s]+/k8s-MSEF(\.git)?\b', rf'\1{new_url}', changes, a.dry_run)
    print(("Would change" if a.dry_run else "Changed"), len(set(changes)), "files:")
    for c in sorted(set(changes)): print("  ", c)
    print(f"\nGitHub repository variables to set:\n  GCP_PROJECT_ID = {a.project}\n  GCP_REGION     = {a.region}")
    print("  GCP_WORKLOAD_IDENTITY_PROVIDER / GCP_SERVICE_ACCOUNT = outputs of terraform/bootstrap-state/envs/<env>")

if __name__ == "__main__":
    main()
