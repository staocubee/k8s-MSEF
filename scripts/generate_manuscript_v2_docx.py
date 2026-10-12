#!/usr/bin/env python3
"""
Complete Word (.docx) Manuscript Generator for MSEFv2
Compiles the comprehensive, unabridged academic manuscript with custom styling,
dual abstracts (English & Slovenian), 6 scientific tables, and full references.
"""

import sys

try:
    import docx
    from docx import Document
    from docx.shared import Inches, Pt, RGBColor
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.enum.table import WD_TABLE_ALIGNMENT
    from docx.oxml import OxmlElement
    from docx.oxml.ns import qn
except ImportError:
    print("[!] python-docx is not installed. Please run: pip install python-docx")
    sys.exit(1)


def set_cell_background(cell, fill_hex):
    """Sets the background hex color of a table cell."""
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), fill_hex)
    tc_pr.append(shd)


def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    """Sets cell padding in dxa units."""
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = OxmlElement('w:tcMar')
    for m, val in [('w:top', top), ('w:bottom', bottom), ('w:left', left), ('w:right', right)]:
        node = OxmlElement(m)
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tc_mar.append(node)
    tc_pr.append(tc_mar)


def add_styled_table(doc, headers, data):
    """Generates and styles a formal academic grid table."""
    table = doc.add_table(rows=len(data) + 1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = True

    # Style Header Row
    for col_idx, text in enumerate(headers):
        cell = table.cell(0, col_idx)
        cell.text = text
        set_cell_background(cell, "1F4E79")
        set_cell_margins(cell, top=120, bottom=120, left=150, right=150)
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        for run in p.runs:
            run.font.bold = True
            run.font.name = 'Times New Roman'
            run.font.size = Pt(9.0)
            run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

    # Style Data Rows
    for row_idx, row_data in enumerate(data, start=1):
        bg = "F2F5F8" if row_idx % 2 == 0 else "FFFFFF"
        for col_idx, val in enumerate(row_data):
            cell = table.cell(row_idx, col_idx)
            cell.text = str(val)
            set_cell_background(cell, bg)
            set_cell_margins(cell, top=80, bottom=80, left=150, right=150)
            p = cell.paragraphs[0]
            for run in p.runs:
                run.font.name = 'Times New Roman'
                run.font.size = Pt(9.0)
                run.font.color.rgb = RGBColor(0x22, 0x22, 0x22)

    doc.add_paragraph()  # Spacing after table
    return table


def build_docx():
    doc = Document()

    # 1. Page Configuration (Standard 1.0 Inch Margins)
    for section in doc.sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)

    # 2. Typography Styles
    normal = doc.styles['Normal']
    normal.font.name = 'Times New Roman'
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = RGBColor(0x22, 0x22, 0x22)
    normal.paragraph_format.line_spacing = 1.15
    normal.paragraph_format.space_after = Pt(4)

    # 3. Document Title
    p_title = doc.add_paragraph()
    p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_title.paragraph_format.space_before = Pt(0)
    p_title.paragraph_format.space_after = Pt(8)
    r_title = p_title.add_run(
        "A Closed-Loop Multi-Layer Security Evaluation Framework for Hardening "
        "Kubernetes across the DevSecOps Lifecycle: Architecture, Mutation Testing, "
        "and Empirical Overhead Benchmarking"
    )
    r_title.font.name = 'Times New Roman'
    r_title.font.size = Pt(15)
    r_title.font.bold = True

    # 4. Authors and Metadata
    p_author = doc.add_paragraph()
    p_author.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_author.paragraph_format.space_after = Pt(2)
    r_author = p_author.add_run("Oluwatobi Seun Solomon¹, Olajide Adegunwa¹*")
    r_author.font.bold = True
    r_author.font.size = Pt(11)

    p_affil = doc.add_paragraph()
    p_affil.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_affil.paragraph_format.space_after = Pt(14)
    r_affil = p_affil.add_run(
        "¹ Department of Computer Science, Caleb University, Imota, Lagos, Nigeria\n"
        "Emails: oluwatobi.solomon@calebuniversity.edu.ng, olajide.adegunwa@calebuniversity.edu.ng*\n"
        "*Corresponding Author"
    )
    r_affil.font.italic = True
    r_affil.font.size = Pt(9.5)

    # 5. Dual Abstract Box (English & Slovenian)
    box_table = doc.add_table(rows=1, cols=1)
    box_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    b_cell = box_table.cell(0, 0)
    set_cell_background(b_cell, "F4F6F9")
    set_cell_margins(b_cell, top=140, bottom=140, left=180, right=180)

    p_eng = b_cell.paragraphs[0]
    p_eng.paragraph_format.space_after = Pt(6)
    r_e_head = p_eng.add_run("Abstract—")
    r_e_head.font.bold = True
    p_eng.add_run(
        "Kubernetes has emerged as the de facto orchestration engine for containerized microservices "
        "in enterprise DevSecOps pipelines. However, its declarative abstraction layer, distributed control plane, "
        "and dynamic runtime model introduce a complex, multi-tiered attack surface. Existing security controls "
        "are frequently evaluated in isolation, leaving organizations vulnerable to supply-chain tampering, "
        "admission-policy bypasses, and unmitigated runtime escapes. This paper proposes, implements, and "
        "comprehensively evaluates MSEFv2, an extended four-layer Multi-Layer Security Evaluation Framework "
        "designed to enforce shift-left assurance, admission-time prevention, cryptographic artifact provenance, "
        "and autonomous closed-loop runtime containment across cloud-native environments. Built upon an automated "
        "Google Kubernetes Engine (GKE) testbed orchestrated via Terraform and ArgoCD, MSEFv2 introduces: "
        "(1) an empirical pre-deployment layer combining Trivy and Snyk to establish vulnerability, secret, and "
        "infrastructure-as-code defect baselines; (2) an admission prevention layer evaluated against an automated "
        "100-mutant adversarial mutation engine mapped to the CIS Kubernetes Benchmark; (3) a cryptographic integrity "
        "layer validating container digest provenance through Sigstore Cosign and Kyverno policy-as-code; and "
        "(4) an asynchronous runtime detection and autonomous containment engine utilizing Falco eBPF probes coupled "
        "to an event-driven, queue-backed Kubernetes Runtime Evaluation (KRE) controller. The runtime engine is "
        "benchmarked against a 10-stage attack matrix grounded in the MITRE ATT&CK for Containers taxonomy. "
        "Furthermore, this study reports empirical system-overhead benchmarks, measuring admission webhook latency "
        "across percentiles (P50: 12.40 ms, P95: 28.15 ms, P99: 42.60 ms) against an unhardened vanilla baseline, "
        "alongside kernel-level eBPF resource footprints under stress. Experimental results demonstrate an updated "
        "Manifest Blocking Rate (MBR) of 98.00% under adversarial mutations, a Prevention Effectiveness Score (PES) "
        "of 99.20%, an Integrity Effectiveness Score (IES) of 100%, and an upgraded continuous exponential-decay Detection "
        "Effectiveness Score (DES) of 90.21% with a sub-second Mean Time to Contain (MTTC) of 142.60 ms. Component ablation "
        "experiments across six isolated configurations (C0 to C5) confirm that asynchronous remediation achieves a 5.89x "
        "containment speedup over synchronous pipelines, recovering 100% containment reliability without dropped events. "
        "The framework delivers a repeatable, statistically grounded reference model for securing containerized workloads across modern "
        "DevSecOps lifecycles."
    )

    p_slov = b_cell.add_paragraph()
    p_slov.paragraph_format.space_after = Pt(6)
    r_s_head = p_slov.add_run("Izvleček—")
    r_s_head.font.bold = True
    p_slov.add_run(
        "Kubernetes je postal osrednji orodje za upravljanje vsebnikov v okoljih DevSecOps, vendar njegova kompleksna "
        "konfiguracija odpira obsežne varnostne vrzeli. Obstoječe varnostne rešitve pogosto delujejo izolirano. "
        "Ta članek predstavi in empirično ovrednoti MSEFv2, razširjen štirislojni okvir za celovito varovanje delovnih obremenitev "
        "v celotnem življenjskem ciklu. Okvir vključuje preverjanje statičnih ranljivosti, preprečevanje z mutacijskim testiranjem, "
        "kriptografsko overjanje izvorne celovitosti ter asinhrono odkrivanje in samodejno omejevanje groženj na podlagi "
        "tehnologije eBPF. Eksperimentalni rezultati potrjujejo visoko stopnjo zaščite z minimalnim sistemskim vplivom na zakasnitve."
    )

    p_kw = b_cell.add_paragraph()
    p_kw.paragraph_format.space_after = Pt(2)
    r_kw = p_kw.add_run("Keywords: ")
    r_kw.font.bold = True
    p_kw.add_run("Kubernetes security, DevSecOps, admission control, eBPF, Falco, policy-as-code, closed-loop remediation, MITRE ATT&CK, container security metrics.")

    doc.add_paragraph()  # Spacing

    # Section 1: Introduction
    doc.add_heading("1. Introduction", level=1)
    doc.add_paragraph(
        "Modern cloud-native systems rely on Kubernetes to orchestrate decoupled microservices across dynamic infrastructure [1]. "
        "However, the declarative model that enables rapid deployment also creates an interconnected attack surface: "
        "unhardened manifest schemas, overly permissive Role-Based Access Control (RBAC) bindings, unverified third-party base images, "
        "exposed container-network fabrics, and kernel-sharing runtime environments [1, 10]. As demonstrated by Adegunwa and Solomon [1], "
        "siloed security mechanisms deployed across enterprise delivery pipelines fail to establish measurable defense-in-depth. "
        "Rahman et al. [2] evaluated 2,039 open-source Kubernetes manifests and identified 1,051 distinct security misconfigurations, "
        "proving that insecure-by-default configurations remain widespread in production practice. Furthermore, Shamim et al. [3] "
        "systematized cloud-native security practices and identified that least privilege, pod isolation, and admission policies are "
        "applied inconsistently throughout software lifecycles."
    )
    doc.add_paragraph(
        "Recent research has increasingly focused on kernel-level monitoring and software composition controls. Lu et al. [4] "
        "designed BPFGuard, highlighting that eBPF-based mandatory access control provides fine-grained runtime protection across "
        "multi-tenant container nodes. In parallel, network-level evaluations by Bufalino et al. [5] revealed that misconfigured "
        "pod-to-pod communications frequently facilitate lateral movement, reinforcing the necessity of strict admission-time network isolation. "
        "Chen et al. [6] introduced behavioral monitoring and honeypots to defend container clusters, while Gurajapu et al. [7] "
        "showed that validating admission webhooks forms the cornerstone of shift-left container assurance. Kamieniarz and Mazurczyk [8] "
        "conducted comparative deployments evaluating cluster vulnerability management, whereas Wang et al. [9] showed that "
        "control-plane interfaces and admission webhooks themselves present critical attack vectors requiring rate-limiting and latency controls. "
        "Finally, Morić et al. [10] emphasized compliance assessment across Kubernetes control planes and enterprise workloads."
    )
    doc.add_paragraph(
        "Despite these advances, modern research still lacks a unified, repeatable framework that links static scanning, admission fuzzing, "
        "cryptographic provenance, and autonomous closed-loop runtime containment while measuring the operational latency penalty imposed on "
        "the orchestration engine. Preliminary research into the Multi-Layer Security Evaluation Framework (MSEF) evaluated functional controls "
        "across small synthetic test suites [1]. However, as observed during pilot trials, synchronous webhook alerting can lead to dropped "
        "mitigations under event bursts, and static test cases cannot evaluate admission boundary resilience against mutated manifests."
    )
    doc.add_paragraph("To resolve these challenges, this study presents MSEFv2, featuring the following primary scientific contributions:")

    contribs = [
        ("Four-layer lifecycle integration", "We integrate pre-deployment scanning (L1), admission prevention (L2), cryptographic provenance (L3), and runtime detection/containment (L4) into an automated GitOps reconciliation loop."),
        ("Adversarial manifest mutation testing", "We replace static manifest lists with an automated fuzzer (N = 100) mapped to CIS Kubernetes Benchmark controls, evaluating boundary enforcement and policy bypasses."),
        ("Asynchronous closed-loop remediation (KRE)", "We implement an event-driven, queue-backed controller with a deduplication cache, eliminating webhook drops and reducing Mean Time to Contain (MTTC) to 142.60 ms."),
        ("MITRE ATT&CK runtime benchmarking", "We evaluate runtime detection and autonomous mitigation across 10 distinct container attack vectors using standardized hardened pod templates."),
        ("Component ablation baselines", "We isolate the security efficacy and latency contribution of six distinct cluster configurations (C0 to C5), confirming the marginal value of each defense layer."),
        ("Empirical latency and resource benchmarking", "We establish admission webhook latency distribution percentiles (P50, P90, P95, P99) relative to an unhardened vanilla cluster, alongside eBPF CPU and memory footprints under stress."),
        ("Continuous scoring formulations", "We replace unweighted linear averages with a continuous exponential decay model for detection latency, penalizing adversary dwell times asymptotically.")
    ]
    for title, desc in contribs:
        p = doc.add_paragraph(style='List Bullet')
        r = p.add_run(f"{title}: ")
        r.font.bold = True
        p.add_run(desc)

    # Section 2: Research methodology
    doc.add_heading("2. Research methodology and system architecture", level=1)
    doc.add_heading("2.1 Threat model and boundary assumptions", level=2)
    doc.add_paragraph(
        "The experimental testbed simulates an enterprise multi-tenant microservices platform hosted on Google Kubernetes Engine (GKE) [1]. "
        "Infrastructure provisioning is managed via Terraform, and configuration state is reconciled through ArgoCD GitOps pipelines. "
        "We formalize two threat profiles aligned with the MITRE ATT&CK for Containers taxonomy:\n\n"
        "1. Adversary A_supply (Supply-chain threat): An external or insider threat attempting to inject unvetted dependencies containing CVEs, "
        "deploy unsigned container images, hardcode plaintext credentials in manifests, or submit over-privileged ClusterRole bindings to default service accounts.\n"
        "2. Adversary A_runtime (In-cluster threat): An adversary with remote code execution (RCE) in an unprivileged container. "
        "A_runtime executes living-off-the-land techniques, interrogates instance metadata (IMDS: 169.254.169.254), harvests service account JWT tokens, "
        "probes internal namespace CIDRs, or attempts container escape via host cgroup release agents."
    )

    doc.add_heading("2.2 System architecture across four defense layers", level=2)
    doc.add_paragraph(
        "MSEFv2 enforces continuous defense-in-depth across the application lifecycle through four operational layers:\n"
        "• Layer 1 (Pre-deployment shift-left): Executes Trivy and Snyk scanners within CI workflows to audit application packages, container base layers, "
        "Terraform manifests, and plaintext secrets before code reaches production.\n"
        "• Layer 2 (Admission-time prevention): OPA Gatekeeper and native Pod Security Admission enforce validation constraints, denying non-compliant Pods "
        "and over-privileged RBAC bindings at the API server.\n"
        "• Layer 3 (Artifact cryptographic integrity): Sigstore Cosign cryptographically signs container digests during builds; Kyverno verifies digital "
        "signatures against trusted public keys before permitting pod scheduling.\n"
        "• Layer 4 (Runtime detection & response): Falco captures system calls via eBPF probes; alerts trigger the asynchronous KRE controller, executing multi-tier "
        "mitigations (dynamic network micro-quarantine, pod eviction, and identity revocation)."
    )

    doc.add_heading("2.3 Adversarial mutation and fuzzing formulation", level=2)
    doc.add_paragraph(
        "To avoid the bias of static test suites, we define an automated mutation engine M. Given a compliant seed workload S, "
        "the engine produces a mutated candidate S' = (μ_k ∘ μ_(k-1) ∘ ... ∘ μ_1)(S) where μ_i maps to non-compliant rules defined in "
        "CIS Kubernetes Benchmark v1.8 (run-as-root, privileged flag, hostPath mounts, dangerous capabilities, missing quotas, default service accounts, "
        "and RBAC wildcard permissions). The Manifest Blocking Rate (MBR) is measured across N = 100 mutants using server-side dry-run validation."
    )

    doc.add_heading("2.4 MITRE ATT&CK for containers experimental matrix", level=2)
    doc.add_paragraph("Runtime evaluation utilizes 10 standardized attack manifests deployed into hardened test environments:")

    p_t1 = doc.add_paragraph()
    p_t1.add_run("Table 1: ").font.bold = True
    p_t1.add_run("MITRE ATT&CK for Containers runtime evaluation matrix and defense mapping.")

    t1_headers = ["Technique ID", "MITRE Technique Name", "Attack Simulation Vector", "Target Defense Layer"]
    t1_rows = [
        ["T1059.004", "Unix Shell", "Interactive /bin/sh process spawned in container", "Runtime Detection & Eviction"],
        ["T1552.007", "Container Credentials", "Token scraping at /var/run/secrets/.../serviceaccount", "Detection & Identity Quarantine"],
        ["T1580", "Cloud Discovery", "HTTP GET request directed to 169.254.169.254 (IMDS)", "Network Policy & Detection"],
        ["T1071.001", "Outbound C2", "Outbound TCP beaconing to external endpoint over port 443", "Detection & Quarantine"],
        ["T1611", "Escape to Host", "Write operation targeting cgroups release_agent", "Prevention & Detection"],
        ["T1036", "Masquerading", "Execution of binary dropped into /tmp scratchpad", "Runtime Detection"],
        ["T1556", "Modify Auth Process", "Modification attempt of /etc/pam.d/common-auth", "Runtime Detection"],
        ["T1046", "Network Service Discovery", "Internal connect scan probing cluster service ports", "Prevention & Detection"],
        ["T1496", "Resource Hijacking", "Stratum protocol handshake to external mining pool", "Detection & Pod Eviction"],
        ["T1053", "Root Filesystem Write", "Unauthorized write to /etc/unauthorized_config", "Prevention & Detection"]
    ]
    add_styled_table(doc, t1_headers, t1_rows)

    doc.add_heading("2.5 Quantitative metric formulations", level=2)
    doc.add_paragraph(
        "To reflect operational severities and avoid arbitrary linear scoring caps, layer composite scores are formulated as follows:\n\n"
        "1. Weighted Prevention Effectiveness Score (PES):\n"
        "   PES = w_m · MBR + w_n · NPER + w_s · SMER\n"
        "   where w_m = 0.40, w_n = 0.30, and w_s = 0.30 (sum = 1.0).\n\n"
        "2. Integrity Effectiveness Score (IES):\n"
        "   IES = SPR = (Rejected Unsigned Image Deployments) / (Total Unsigned Admission Attempts)\n\n"
        "3. Continuous Exponential Latency Decay Detection Score (DES):\n"
        "   DES = w_d · RDR + w_r · RRSR + w_f · (1 - OFPR) + w_l · exp(-λ · MTTD)\n"
        "   where w_d = 0.35, w_r = 0.30, w_f = 0.15, w_l = 0.20, and λ = 0.03.\n\n"
        "4. End-to-End Mitigation Latency (E2EML):\n"
        "   E2EML = MTTD + MTTC\n"
        "   where MTTC is the Mean Time to Contain measured from webhook alert ingestion to active cluster quarantine or eviction."
    )

    doc.add_heading("2.6 Policy soundness limits, syntactic edge cases, and RBAC verification", level=2)
    doc.add_paragraph(
        "Declarative policy engines enforce constraints against the Abstract Syntax Tree (AST) of incoming admission requests. "
        "However, static policy evaluation exhibits fundamental soundness limits:\n"
        "• Syntactic vs. Semantic Gap: Static policies evaluate manifest structure, not runtime process behavior. A pod with runAsNonRoot: true "
        "can still execute binary payloads that compromise non-root system components if setuid binaries exist in the container image.\n"
        "• Regex Evaluation Boundaries: Wildcard strings and numeric representations can bypass regex filters. In our mutation trials, "
        "sub-millicore strings (e.g., cpu: 500u) bypassed standard regexes expecting 'm' or integer cores, demonstrating that policy-as-code requires continuous fuzzing.\n"
        "• RBAC Transitive Escalation: Declarative policies easily block explicit wildcards (verbs: ['*'] or resources: ['*']). "
        "However, transitive escalations—such as granting create on pods/exec or bind on roles—cannot be fully modeled via static admission "
        "without maintaining global cluster role relationship graphs, reinforcing Layer 4 runtime eBPF monitoring as a mandatory fallback."
    )

    # Section 3: Results
    doc.add_heading("3. Results and empirical evaluation", level=1)
    doc.add_heading("3.1 Layer 1: Pre-deployment scanning results", level=2)
    doc.add_paragraph("Evaluating packages, base images, and IaC modules produced comprehensive defect coverage across dual engines:")

    p_t2 = doc.add_paragraph()
    p_t2.add_run("Table 2: ").font.bold = True
    p_t2.add_run("Layer 1 pre-deployment defect detection across scanning engines.")

    t2_headers = ["Scan Target", "Evaluated Artifact", "Trivy Detections", "Snyk Detections", "Concordance"]
    t2_rows = [
        ["Dependencies", "package.json, requirements.txt", "18 vulnerabilities", "19 vulnerabilities", "0.947 (18/19)"],
        ["Container Image", "Node.js base image", "42 CVEs (6 critical)", "45 CVEs (7 critical)", "0.933 (42/45)"],
        ["IaC (Terraform)", "GKE & VPC modules", "8 misconfigurations", "8 misconfigurations", "1.000 (8/8)"],
        ["Secrets", "Repository files & .env", "4 exposed tokens", "4 exposed tokens", "1.000 (4/4)"]
    ]
    add_styled_table(doc, t2_headers, t2_rows)

    doc.add_heading("3.2 Layer 2 & 3: Prevention fuzzing and integrity verification", level=2)
    doc.add_paragraph(
        "Adversarial mutation testing evaluated N = 100 non-compliant manifests against live admission controllers. "
        "During testing, 2 resource-limit mutants bypassed admission because sub-millicore limit formatting bypassed the basic regex check "
        "in the initial constraint template, yielding MBR = 0.9800 (98.00%). With NPER = 1.00 and SMER = 1.00, the weighted PES reached 99.20%."
    )

    p_t3 = doc.add_paragraph()
    p_t3.add_run("Table 3: ").font.bold = True
    p_t3.add_run("Layer 2 admission-time prevention under mutation fuzzing (N = 100).")

    t3_headers = ["Mutation Category", "Samples", "Blocked", "Bypassed", "Enforcement Oracle"]
    t3_rows = [
        ["Privileged & Capabilities", "24", "24", "0", "Gatekeeper strict-pod-security"],
        ["Host Namespace (PID/Net)", "18", "18", "0", "Gatekeeper strict-pod-security"],
        ["Rootfs & User Escalation", "16", "16", "0", "PSA restricted / Gatekeeper"],
        ["Resource Limits & Quotas", "17", "15", "2", "Gatekeeper k8srequireresources"],
        ["Default ServiceAccount Binding", "10", "10", "0", "Gatekeeper k8sdisallowdefaultsa"],
        ["RBAC Wildcards & Secret Ingress", "15", "15", "0", "Gatekeeper k8srestrictwildcardrbac"],
        ["Total Evaluation", "100", "98", "2", "MBR = 0.9800 (98.00%)"]
    ]
    add_styled_table(doc, t3_headers, t3_rows)

    doc.add_paragraph(
        "In Layer 3, Kyverno blocked all 10 unsigned image attempts and 2 digest-mismatched images while permitting valid Cosign-signed digests, "
        "confirming IES = SPR = 1.00 (100%). Mutation-safe verification resolved multi-architecture image index (manifest.list) references "
        "by pinning immutable SHA-256 digests, preventing TOCTOU registry rewrite attacks."
    )

    doc.add_heading("3.3 Layer 4: Runtime detection, autonomous containment, and telemetry", level=2)
    doc.add_paragraph("Evaluating the 10 MITRE ATT&CK runtime scenarios against Falco eBPF and the asynchronous KRE controller produced:")

    p_t4 = doc.add_paragraph()
    p_t4.add_run("Table 4: ").font.bold = True
    p_t4.add_run("Layer 4 runtime detection and containment performance metrics.")

    t4_headers = ["Runtime Metric", "Observed Value", "95% Conf. Interval", "Interpretation"]
    t4_rows = [
        ["Runtime Detection Rate (RDR)", "1.00 (10/10)", "[1.00, 1.00]", "All 10 MITRE attack vectors detected"],
        ["Operational False Positive Rate (OFPR)", "0.00 (0/5)", "[0.00, 0.00]", "Zero false alerts across 5 benign windows"],
        ["Mean Time to Detect (MTTD)", "22.40 s", "[20.15, 24.65] s", "Average detection delay"],
        ["Response Success Rate (RRSR)", "1.00 (10/10)", "[1.00, 1.00]", "Asynchronous KRE executed containment"],
        ["Mean Time to Contain (MTTC)", "142.60 ms", "[131.20, 154.00] ms", "Sub-second webhook containment speed"],
        ["End-to-End Mitigation Latency (E2EML)", "22.54 s", "[20.28, 24.80] s", "Total exposure window (MTTD + MTTC)"]
    ]
    add_styled_table(doc, t4_headers, t4_rows)

    doc.add_heading("3.4 System overhead and comparative benchmarking", level=2)
    doc.add_paragraph(
        "To isolate the latency overhead imposed by MSEFv2's admission controllers, we deployed burst batches of N = 100 unprivileged pods "
        "on GKE nodes comparing an unhardened vanilla cluster against the MSEFv2-hardened environment:"
    )

    p_t5 = doc.add_paragraph()
    p_t5.add_run("Table 5: ").font.bold = True
    p_t5.add_run("Comparative admission webhook latency percentiles (Vanilla vs. MSEFv2).")

    t5_headers = ["Environment", "Mean (ms)", "Std Dev", "P50 (ms)", "P90 (ms)", "P95 (ms)", "P99 (ms)"]
    t5_rows = [
        ["Baseline (Vanilla GKE)", "4.20", "±1.15", "3.80", "5.10", "6.40", "8.90"],
        ["Hardened (MSEFv2 Cluster)", "15.80", "±6.42", "12.40", "16.20", "28.15", "42.60"],
        ["Operational Delta (Δ)", "+11.60", "+5.27", "+8.60", "+11.10", "+21.75", "+33.70"]
    ]
    add_styled_table(doc, t5_headers, t5_rows)

    doc.add_paragraph(
        "A two-sample Welch’s t-test confirms the latency difference between Vanilla GKE and MSEFv2 is statistically significant "
        "(t = 17.84, p < 0.0001, Cohen’s d = 2.52). However, the absolute P99 latency of 42.60 ms introduces only a +33.70 ms overhead, "
        "which is negligible for standard container orchestration lifecycles."
    )

    doc.add_heading("3.5 Component ablation study", level=2)
    doc.add_paragraph(
        "To quantify the isolated contribution and operational cost of each security layer, we evaluated six distinct cluster configurations (C0 to C5):"
    )

    p_t6 = doc.add_paragraph()
    p_t6.add_run("Table 6: ").font.bold = True
    p_t6.add_run("Multi-configuration component ablation matrix (C0 to C5).")

    t6_headers = ["Config", "Scope & Controls", "P50 (ms)", "P99 (ms)", "PES (%)", "IES (%)", "RDR (%)", "RRSR (%)", "MTTC (ms)", "Probe CPU / RAM"]
    t6_rows = [
        ["C0", "Vanilla GKE Baseline", "3.80", "8.90", "0.00%", "0.00%", "0.00%", "0.00%", "N/A", "0 m / 0 MiB"],
        ["C1", "Shift-Left Only (Snyk+Trivy)", "3.82", "8.95", "0.00%", "0.00%", "0.00%", "0.00%", "N/A", "0 m / 0 MiB"],
        ["C2", "Admission Only (GK+Kyverno)", "12.10", "41.20", "99.20%", "100.0%", "0.00%", "0.00%", "N/A", "0 m / 0 MiB"],
        ["C3", "Detection Only (Falco passive)", "3.85", "9.10", "0.00%", "0.00%", "100.0%", "0.00%", "N/A", "28.1 m / 63.8 MiB"],
        ["C4", "Synchronous KRE Pipeline", "12.35", "42.10", "99.20%", "100.0%", "100.0%", "77.80%", "840.50 ms", "38.1 m / 113.3 MiB"],
        ["C5", "Full MSEFv2 Asynchronous Pipeline", "12.40", "42.60", "99.20%", "100.0%", "100.0%", "100.0%", "142.60 ms", "32.6 m / 97.0 MiB"]
    ]
    add_styled_table(doc, t6_headers, t6_rows)

    # Section 4: Discussion
    doc.add_heading("4. Discussion and limitations", level=1)
    doc.add_heading("4.1 Comparative findings", level=2)
    doc.add_paragraph(
        "The empirical findings demonstrate that decoupled point tools leave critical exposure windows across modern delivery lifecycles. "
        "Shift-left scanning eliminated static CVEs but was blind to zero-day runtime escapes; admission policies blocked misconfigurations "
        "at ingestion; and kernel eBPF probes captured post-exploitation behavior. Transitioning KRE to an asynchronous architecture resolved "
        "the event-loss drops observed in earlier pilot studies [1]."
    )
    doc.add_heading("4.2 External validity and scalability limitations", level=2)
    doc.add_paragraph(
        "• Platform Portability: Experiments were executed on Google Kubernetes Engine (GKE) running Linux kernel 6.1 with cgroups v2. "
        "Evaluating the eBPF probe rules across local distributions (Kind/K3s) confirmed behavioral parity, though kernel attachment points vary on older Linux kernels utilizing cgroups v1.\n"
        "• Control-Plane Rate Limiting: Under high-burst autoscaling scenarios (>500 concurrent pod creations per minute), API server admission queue "
        "saturation can elevate P99 latencies beyond 100 ms. Production deployments should implement webhook rate-limiting or selective admission exemptions for system namespaces.\n"
        "• Kernel Ring-Buffer Drops: Under sustained denial-of-service (DoS) syscall bursts, eBPF perf buffer rings can experience packet drops, "
        "highlighting the necessity of tuning Falco buffer sizes on high-throughput nodes."
    )

    # Section 5: Conclusion
    doc.add_heading("5. Conclusion", level=1)
    doc.add_paragraph(
        "This paper designed, implemented, and empirically evaluated MSEFv2, an extended four-layer security evaluation framework for "
        "hardening Kubernetes across DevSecOps pipelines. Integrating shift-left scanning, parameterized manifest fuzzing (N = 100), "
        "cryptographic image signing, and asynchronous closed-loop runtime containment yielded PES = 99.20%, IES = 100%, and DES = 90.21% "
        "with an average containment speed of 142.60 ms and P99 webhook latency under 43 ms. Multi-configuration ablation testing confirmed that "
        "asynchronous closed-loop orchestration delivers a 5.89x containment speedup over synchronous architectures. The framework establishes a repeatable, "
        "statistically grounded reference model for cloud-native security research."
    )

    # Section 6: References
    doc.add_heading("References", level=1)
    refs = [
        "[1] O. Adegunwa and O. S. Solomon, 'A Multi-Layer Security Evaluation Framework for Hardening Kubernetes in DevSecOps Pipelines: A Quantitative Experimental Evaluation,' Asian Journal of Research in Computer Science, vol. 18, no. 2, pp. 1–18, 2026.",
        "[2] A. Rahman, M. S. I. Shamim, D. B. Bose, and R. Pandita, 'Security misconfigurations in open source Kubernetes manifests: An empirical study,' ACM Transactions on Software Engineering and Methodology, vol. 32, no. 4, art. 99, pp. 1–36, 2023.",
        "[3] M. S. I. Shamim, F. A. Bhuiyan, and A. Rahman, 'XI commandments of Kubernetes security: A systematization of knowledge related to Kubernetes security practices,' in 2020 IEEE Secure Development (SecDev), 2020, pp. 58–64.",
        "[4] H. Lu, X. Du, D. Hu, S. Su, and Z. Tian, 'BPFGuard: Multi-granularity container runtime mandatory access control,' IEEE Transactions on Cloud Computing, vol. 13, no. 2, pp. 629–640, 2025.",
        "[5] J. Bufalino, J. L. Martin-Navarro, M. Di Francesco, and T. Aura, 'Inside job: Defending Kubernetes clusters against network misconfigurations,' Proceedings of the ACM on Networking, vol. 3, no. CONEXT3, art. 20, pp. 1–25, 2025.",
        "[6] Q. Chen, Y. Liu, R. Tan, Z. Jin, J. Xiao, X. Wang, F. Zhang, and Q. Liu, 'Shadowkube: Enhancing Kubernetes security with behavioral monitoring and honeypot integration,' Cybersecurity, vol. 8, art. 63, 2025.",
        "[7] A. Gurajapu, S. Anumolu, A. Agarwal, and V. Yeka, 'Shift-left security validation of containers via Kubernetes admission webhook,' Frontiers in Computer Science and Artificial Intelligence, vol. 5, no. 2, pp. 63–68, 2026.",
        "[8] K. Kamieniarz and W. Mazurczyk, 'A comparative study on the security of Kubernetes deployments,' in 2024 International Wireless Communications and Mobile Computing (IWCMC), 2024, pp. 718–723.",
        "[9] C. Wang, H. Tang, Y. Zhao, W. You, J. Yang, and H. Qiu, 'Losing control: Exposing security weaknesses of Kubernetes control plane interfaces,' Computers & Security, vol. 160, art. 104704, 2026.",
        "[10] Z. Morić, V. Dakić, and T. Čavala, 'Security hardening and compliance assessment of Kubernetes control plane and workloads,' Journal of Cybersecurity and Privacy, vol. 5, no. 2, art. 30, 2025."
    ]
    for r in refs:
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Inches(0.25)
        p.paragraph_format.first_line_indent = Inches(-0.25)
        p.add_run(r)

    filename = "MSEFv2_Informatica_Manuscript.docx"
    doc.save(filename)
    print(f"[✓] Successfully compiled complete Word manuscript: {filename}")


if __name__ == "__main__":
    build_docx()