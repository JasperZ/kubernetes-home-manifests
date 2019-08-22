{
  name:: error "name is required",
  namespace:: "default",
  labels:: error "labels are required",
  selector:: error "selector is required",

  apiVersion: "v1",
  kind: "Service",
  metadata: {
    name: $.name,
    namespace: $.namespace,
    labels: $.labels,
  },
  spec: {
    selector: $.selector,
    ports: [],
  },
}
