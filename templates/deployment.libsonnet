{
  name:: error "name is required",
  namespace:: "default",
  labels:: error "labels are required",
  replicas:: 1,

  apiVersion: "apps/v1",
  kind: "Deployment",
  metadata: {
    name: $.name,
    namespace: $.namespace,
    labels: $.labels,
  },
  spec: {
    replicas: $.replicas,
    selector: {
      matchLabels: $.labels,
    },
    template: {
      metadata: {
        labels: $.labels,
      },
      spec: {
        containers: [

        ],
      },
    },
  },
}
