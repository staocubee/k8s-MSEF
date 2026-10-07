# HASE-APH: Hypergraph Attack-Surface Evaluation and Autonomous Policy Healing

HASE-APH extends MSEF from control measurement into relationship-aware policy repair.

MSEF asks:

> Can Kubernetes security controls be systematically evaluated across prevention, integrity, and runtime detection/response?

HASE-APH asks:

> Can Kubernetes attack-surface relationships be modeled as a hypergraph and used to identify, validate, deploy, and verify policy healing actions?

## Research Evolution

```text
MSEF
Security Controls -> Measurement -> Evaluation

HASE-APH
Security Controls
  -> Attack-Surface Hypergraph
  -> Evaluation
  -> Policy Gap
  -> Candidate Healing Policy
  -> Validation
  -> GitOps Deployment
  -> Re-evaluation
  -> Confirm or Rollback
```

## Why Hypergraphs

Kubernetes weaknesses are often caused by combinations of resources, not a single manifest field.

Example:

```text
{Pod, ServiceAccount, Role, Secret, NetworkPolicy}
  -> Attack Surface Condition
```

This captures conditions such as:

```text
Privileged Pod
  + Over-permissive ServiceAccount
  + Secret reference
  + Unrestricted egress
  -> High-risk attack surface
```

A normal graph can represent pairwise edges such as `Pod -> ServiceAccount`.
A hypergraph can represent multi-resource relationships as one security condition.

## Initial Node Types

- Namespace
- Pod
- Deployment
- Service
- ServiceAccount
- Role
- ClusterRole
- RoleBinding
- ClusterRoleBinding
- Secret
- ConfigMap
- ContainerImage
- NetworkPolicy
- Ingress
- AdmissionPolicy
- RuntimeEvent

## Initial Hyperedge Types

- `workload-security-context`: workload plus security-context risk attributes.
- `workload-image`: workload plus image supply-chain attributes.
- `service-account-rbac`: workload/service account plus bound RBAC role.
- `secret-exposure`: workload plus referenced Secret.
- `service-exposure`: workload plus matching Service and optional Ingress.
- `network-policy-coverage`: workload plus namespace-level policy coverage.
- `runtime-alert`: workload plus Falco/runtime observation.

## Healing Loop Boundary

HASE-APH should only claim autonomous policy healing when the implementation performs the full loop:

```text
Identify
  -> Generate or modify policy
  -> Validate
  -> Deploy
  -> Verify
  -> Roll back if necessary
```

If the system only detects gaps and emits YAML, it should be described as:

> Hypergraph-based attack-surface evaluation with automated policy recommendation.

## Policy-Constrained Healing Flow

```text
Security Event
  -> Attack Surface Analyzer
  -> Policy Gap Identification
  -> Candidate Policy Generation
  -> Policy Validation
       -> FAIL: reject candidate
       -> PASS: apply through GitOps
  -> Post-Healing Test
       -> Attack surface not reduced: rollback
       -> Attack surface reduced: confirm
```

## Suggested Metrics

- `ASCR`: Attack Surface Coverage Rate.
- `PGDR`: Policy Gap Detection Rate.
- `PHR`: Policy Healing Rate.
- `HTTV`: Healing Time To Validation.
- `HTTD`: Healing Time To Deployment.
- `HSSR`: Healing Success and Stability Rate.
- `RBR`: Rollback Rate.
- `BIR`: Benign Impact Rate.

## First Runnable Artifact

Build a static attack-surface hypergraph from repository manifests:

```bash
ruby hase-aph/scripts/build_attack_surface_graph.rb \
  --input k8s \
  --input gitops \
  --runtime results/json/runtime-events.jsonl \
  --output results/hase-aph/attack-surface.json
```

The generated JSON contains:

- `nodes`
- `hyperedges`
- `policy_gaps`
- `summary`

This is the foundation for the later autonomous healing controller.
