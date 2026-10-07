#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "yaml"
require "fileutils"
require "set"

options = {
  inputs: ["k8s", "gitops"],
  runtime: nil,
  output: "results/hase-aph/attack-surface.json"
}

OptionParser.new do |opts|
  opts.banner = "Usage: build_attack_surface_graph.rb [options]"

  opts.on("--input PATH", "Manifest file or directory to scan. Can be repeated.") do |path|
    options[:inputs] = [] if options[:inputs] == ["k8s", "gitops"]
    options[:inputs] << path
  end

  opts.on("--runtime PATH", "Optional JSONL runtime observation file.") do |path|
    options[:runtime] = path
  end

  opts.on("--output PATH", "Output JSON path.") do |path|
    options[:output] = path
  end
end.parse!

def yaml_files(paths)
  paths.flat_map do |path|
    if File.directory?(path)
      Dir.glob(File.join(path, "**", "*.{yaml,yml}"))
    elsif File.file?(path)
      [path]
    else
      []
    end
  end.uniq.sort
end

def load_yaml_documents(file)
  YAML.load_stream(File.read(file)).compact.select { |doc| doc.is_a?(Hash) }
rescue Psych::SyntaxError => e
  warn "Skipping invalid YAML #{file}: #{e.message}"
  []
end

def meta(resource)
  resource.fetch("metadata", {}) || {}
end

def spec(resource)
  resource.fetch("spec", {}) || {}
end

def namespace_of(resource)
  meta(resource).fetch("namespace", "default")
end

def name_of(resource)
  meta(resource).fetch("name", "unnamed")
end

def node_id(kind, namespace, name)
  ns = namespace.nil? || namespace.empty? ? "cluster" : namespace
  "#{kind}/#{ns}/#{name}"
end

def add_node(nodes, kind, namespace, name, attrs = {})
  id = node_id(kind, namespace, name)
  nodes[id] ||= {
    "id" => id,
    "kind" => kind,
    "namespace" => namespace,
    "name" => name,
    "attributes" => {}
  }
  nodes[id]["attributes"].merge!(attrs)
  id
end

def add_hyperedge(edges, type, nodes, attrs = {})
  edges << {
    "id" => "HE#{edges.length + 1}",
    "type" => type,
    "nodes" => nodes.compact.uniq,
    "attributes" => attrs
  }
end

def pod_template_spec(resource)
  case resource["kind"]
  when "Deployment", "DaemonSet", "StatefulSet", "ReplicaSet"
    spec(resource).dig("template", "spec") || {}
  when "Pod"
    spec(resource)
  else
    {}
  end
end

def workload_labels(resource)
  case resource["kind"]
  when "Deployment", "DaemonSet", "StatefulSet", "ReplicaSet"
    spec(resource).dig("template", "metadata", "labels") || meta(resource).fetch("labels", {}) || {}
  when "Pod"
    meta(resource).fetch("labels", {}) || {}
  else
    {}
  end
end

def workload_kind?(kind)
  %w[Pod Deployment DaemonSet StatefulSet ReplicaSet].include?(kind)
end

def containers_from(pod_spec)
  Array(pod_spec["containers"]) + Array(pod_spec["initContainers"])
end

def image_risks(image)
  risks = []
  risks << "latest-tag" if image.end_with?(":latest") || !image.include?(":")
  risks << "public-image" if image =~ /\A(nginx|busybox|alpine|ubuntu|curlimages\/)/
  risks
end

def security_risks(pod_spec, containers)
  risks = []
  pod_sc = pod_spec["securityContext"] || {}
  risks << "host-network" if pod_spec["hostNetwork"]
  risks << "host-pid" if pod_spec["hostPID"]
  risks << "host-ipc" if pod_spec["hostIPC"]
  risks << "run-as-root-or-unspecified" unless pod_sc["runAsNonRoot"] == true
  risks << "default-service-account" if [nil, "", "default"].include?(pod_spec["serviceAccountName"])

  containers.each do |container|
    sc = container["securityContext"] || {}
    risks << "privileged-container" if sc["privileged"] == true
    risks << "privilege-escalation-allowed" unless sc["allowPrivilegeEscalation"] == false
    risks << "writable-root-filesystem" unless sc["readOnlyRootFilesystem"] == true
    caps = sc.dig("capabilities", "drop") || []
    risks << "capabilities-not-dropped" unless caps.include?("ALL")
    risks << "missing-resource-limits" unless container.dig("resources", "limits")
    risks << "missing-resource-requests" unless container.dig("resources", "requests")
  end

  risks.uniq
end

def secret_refs(pod_spec)
  refs = []
  Array(pod_spec["volumes"]).each do |volume|
    refs << volume.dig("secret", "secretName")
  end

  containers_from(pod_spec).each do |container|
    Array(container["env"]).each do |env|
      refs << env.dig("valueFrom", "secretKeyRef", "name")
    end
    Array(container["envFrom"]).each do |env_from|
      refs << env_from.dig("secretRef", "name")
    end
  end

  refs.compact.uniq
end

def selector_matches?(selector, labels)
  return false if selector.nil? || selector.empty?

  selector.all? { |key, value| labels[key] == value }
end

def excessive_rbac?(role)
  Array(role.fetch("rules", [])).any? do |rule|
    verbs = Array(rule["verbs"])
    resources = Array(rule["resources"])
    verbs.include?("*") || resources.include?("*") || resources.include?("secrets")
  end
end

nodes = {}
hyperedges = []
policy_gaps = []
resources = []

yaml_files(options[:inputs]).each do |file|
  load_yaml_documents(file).each do |resource|
    kind = resource["kind"]
    next if kind.nil?

    resource["_source"] = file
    resources << resource
    namespace = %w[ClusterRole ClusterRoleBinding Namespace].include?(kind) ? "cluster" : namespace_of(resource)
    add_node(nodes, kind, namespace, name_of(resource), "source" => file)
  end
end

roles = {}
bindings = []
services = []
network_policies = []
ingresses = []
workloads = []

resources.each do |resource|
  kind = resource["kind"]
  namespace = namespace_of(resource)
  name = name_of(resource)

  case kind
  when "Role", "ClusterRole"
    roles[[kind, namespace, name]] = resource
  when "RoleBinding", "ClusterRoleBinding"
    bindings << resource
  when "Service"
    services << resource
  when "NetworkPolicy"
    network_policies << resource
  when "Ingress"
    ingresses << resource
  else
    workloads << resource if workload_kind?(kind)
  end
end

service_account_roles = Hash.new { |h, k| h[k] = [] }
bindings.each do |binding|
  binding_ns = namespace_of(binding)
  role_ref = binding.fetch("roleRef", {})
  role_kind = role_ref["kind"] || "Role"
  role_name = role_ref["name"]
  role_ns = role_kind == "ClusterRole" ? "cluster" : binding_ns
  role = roles[[role_kind, role_ns, role_name]]
  next unless role

  Array(binding["subjects"]).each do |subject|
    next unless subject["kind"] == "ServiceAccount"

    sa_ns = subject["namespace"] || binding_ns
    sa_name = subject["name"]
    service_account_roles[[sa_ns, sa_name]] << role
  end
end

workloads.each do |workload|
  kind = workload["kind"]
  namespace = namespace_of(workload)
  name = name_of(workload)
  workload_node = add_node(nodes, kind, namespace, name, "source" => workload["_source"])
  pod_spec = pod_template_spec(workload)
  containers = containers_from(pod_spec)
  labels = workload_labels(workload)
  sa_name = pod_spec["serviceAccountName"] || "default"
  sa_node = add_node(nodes, "ServiceAccount", namespace, sa_name)

  risks = security_risks(pod_spec, containers)
  unless risks.empty?
    add_hyperedge(
      hyperedges,
      "workload-security-context",
      [workload_node, sa_node],
      "risks" => risks,
      "severity" => risks.any? { |r| r =~ /privileged|host-|default-service-account/ } ? "high" : "medium"
    )
    policy_gaps << {
      "type" => "pod-security-gap",
      "workload" => workload_node,
      "evidence" => risks,
      "recommended_policy" => "Kyverno/Gatekeeper restricted pod-security policy",
      "healing_action" => "generate validation policy or patch workload securityContext",
      "requires_validation" => true
    }
  end

  containers.each do |container|
    image = container["image"]
    next unless image

    image_node = add_node(nodes, "ContainerImage", "registry", image, "image" => image)
    risks_for_image = image_risks(image)
    add_hyperedge(
      hyperedges,
      "workload-image",
      [workload_node, image_node],
      "container" => container["name"],
      "risks" => risks_for_image
    )
    next if risks_for_image.empty?

    policy_gaps << {
      "type" => "image-policy-gap",
      "workload" => workload_node,
      "image" => image,
      "evidence" => risks_for_image,
      "recommended_policy" => "Kyverno verifyImages/disallow-latest policy",
      "healing_action" => "generate image validation policy or pin trusted digest",
      "requires_validation" => true
    }
  end

  service_account_roles[[namespace, sa_name]].each do |role|
    role_node = add_node(nodes, role["kind"], role["kind"] == "ClusterRole" ? "cluster" : namespace_of(role), name_of(role))
    excessive = excessive_rbac?(role)
    add_hyperedge(
      hyperedges,
      "service-account-rbac",
      [workload_node, sa_node, role_node],
      "excessive_rbac" => excessive
    )
    next unless excessive

    policy_gaps << {
      "type" => "rbac-policy-gap",
      "workload" => workload_node,
      "service_account" => sa_node,
      "role" => role_node,
      "evidence" => ["wildcard-or-secret-rbac"],
      "recommended_policy" => "Gatekeeper constraint for wildcard/secret RBAC",
      "healing_action" => "generate least-privilege Role or reject wildcard binding",
      "requires_validation" => true
    }
  end

  secret_refs(pod_spec).each do |secret_name|
    secret_node = add_node(nodes, "Secret", namespace, secret_name)
    add_hyperedge(
      hyperedges,
      "secret-exposure",
      [workload_node, sa_node, secret_node],
      "exposure" => "workload-references-secret"
    )
    policy_gaps << {
      "type" => "secret-exposure-gap",
      "workload" => workload_node,
      "secret" => secret_node,
      "evidence" => ["direct-secret-reference"],
      "recommended_policy" => "External Secrets plus secret-reference admission guardrail",
      "healing_action" => "recommend ExternalSecret or restrict direct secret env/volume usage",
      "requires_validation" => true
    }
  end

  matching_services = services.select do |svc|
    namespace_of(svc) == namespace && selector_matches?(spec(svc)["selector"], labels)
  end
  matching_services.each do |svc|
    service_node = add_node(nodes, "Service", namespace, name_of(svc))
    matching_ingresses = ingresses.select do |ing|
      namespace_of(ing) == namespace && ing.to_json.include?(name_of(svc))
    end
    ingress_nodes = matching_ingresses.map { |ing| add_node(nodes, "Ingress", namespace, name_of(ing)) }
    add_hyperedge(
      hyperedges,
      "service-exposure",
      [workload_node, service_node, *ingress_nodes],
      "service_type" => spec(svc)["type"] || "ClusterIP",
      "ingress_count" => ingress_nodes.length
    )
  end

  namespace_network_policies = network_policies.select { |np| namespace_of(np) == namespace }
  np_nodes = namespace_network_policies.map { |np| add_node(nodes, "NetworkPolicy", namespace, name_of(np)) }
  add_hyperedge(
    hyperedges,
    "network-policy-coverage",
    [workload_node, *np_nodes],
    "network_policy_count" => np_nodes.length,
    "unrestricted" => np_nodes.empty?
  )
  next unless np_nodes.empty?

  policy_gaps << {
    "type" => "network-policy-gap",
    "workload" => workload_node,
    "evidence" => ["no-network-policy-in-namespace"],
    "recommended_policy" => "default-deny plus explicit allow-list NetworkPolicy",
    "healing_action" => "generate namespace/workload NetworkPolicy",
    "requires_validation" => true
  }
end

if options[:runtime] && File.file?(options[:runtime])
  File.readlines(options[:runtime], chomp: true).each_with_index do |line, index|
    next if line.strip.empty?

    event = JSON.parse(line)
    rule = event["rule"] || event["falco_rule"] || "runtime-event"
    namespace = event["namespace"] || event.dig("output_fields", "k8s.ns.name") || "unknown"
    pod = event["pod"] || event.dig("output_fields", "k8s.pod.name") || "unknown"
    event_node = add_node(nodes, "RuntimeEvent", namespace, "#{rule}-#{index + 1}", event)
    pod_node = add_node(nodes, "Pod", namespace, pod)
    add_hyperedge(
      hyperedges,
      "runtime-alert",
      [pod_node, event_node],
      "rule" => rule,
      "severity" => "high"
    )
    policy_gaps << {
      "type" => "runtime-policy-gap",
      "workload" => pod_node,
      "evidence" => [rule],
      "recommended_policy" => "context-specific Kyverno/Gatekeeper/NetworkPolicy control",
      "healing_action" => "map Falco rule to constrained policy template and validate",
      "requires_validation" => true
    }
  rescue JSON::ParserError => e
    warn "Skipping invalid runtime JSONL line #{index + 1}: #{e.message}"
  end
end

severity_weight = { "low" => 1, "medium" => 3, "high" => 5, "critical" => 8 }
score = hyperedges.sum do |edge|
  severity_weight.fetch(edge.dig("attributes", "severity"), edge.dig("attributes", "risks").to_a.length)
end

result = {
  "schema" => "hase-aph.attack-surface-hypergraph.v1",
  "generated_at" => Time.now.utc.iso8601,
  "inputs" => options[:inputs],
  "runtime" => options[:runtime],
  "summary" => {
    "node_count" => nodes.length,
    "hyperedge_count" => hyperedges.length,
    "policy_gap_count" => policy_gaps.length,
    "attack_surface_exposure_score" => score,
    "gap_types" => policy_gaps.group_by { |gap| gap["type"] }.transform_values(&:length)
  },
  "nodes" => nodes.values.sort_by { |node| node["id"] },
  "hyperedges" => hyperedges,
  "policy_gaps" => policy_gaps
}

FileUtils.mkdir_p(File.dirname(options[:output]))
File.write(options[:output], JSON.pretty_generate(result))
puts JSON.pretty_generate(result["summary"])
