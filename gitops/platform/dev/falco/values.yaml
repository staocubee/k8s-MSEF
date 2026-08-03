crds:
  enabled: true

driver:
  enabled: true
  kind: modern_ebpf

collectors:
  kubernetes:
    enabled: true

serviceAccount:
  create: true

falco:
  jsonOutput: true
  json_include_output_property: true
  json_include_output_fields_property: true
  json_include_tags_property: true

  logLevel: info
  priority: debug

  httpOutput:
    enabled: true
    url: http://dev-falcosidekick.falco.svc.cluster.local:2801

resources:
  requests:
    cpu: 100m
    memory: 256Mi

  limits:
    cpu: 500m
    memory: 512Mi