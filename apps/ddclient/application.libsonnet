local kube = import "../../templates/kubernetes.libsonnet";
local ddclientComponent = import "../../components/ddclient.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // ddclient Component
    local ddclientConfig = ddclientComponent.configuration + {
        kube+:: {
            imageTag:: conf.app.ddclient.imageTag,
            resources:: conf.kube.ddclient.resources,
        },
        app+:: {
            cloudflare+:: {
                email:: conf.app.ddclient.cloudflare.email,
                apiToken:: conf.app.ddclient.cloudflare.apiToken,
                zone:: conf.app.ddclient.cloudflare.zone,
                domains:: conf.app.ddclient.cloudflare.domains,
            },
        },
    },
    local ddclient = ddclientComponent.new(namespace, name, labels, ddclientConfig),

    apiVersion: "v1",
    kind: "List",
    items: [
        ddclient.configMap,
        ddclient.deployment,
    ]
};

{
    new:: new,
}