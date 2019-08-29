local service = import "../../templates/service.libsonnet";
local deployment = import "../../templates/deployment.libsonnet";

{
    deploy: deployment {
        name: "replication-testing",
        labels: {
            app: "replication-testing",
            component: "webserver",
            env: "testing",
        },
    },
    svc: service {
        name: $.deploy.name,
        labels: $.deploy.labels,
        selector: $.deploy.labels,
        spec+: {
            ports+: [
                {
                    name: "http",
                    protocol: "TCP",
                    port: 80,
                    targetPort: 8080,
                },
            ],
            type: "LoadBalancer",
            externalTrafficPolicy: "Local",
            loadBalancerIP: "192.168.70.100",
        },
    }
}