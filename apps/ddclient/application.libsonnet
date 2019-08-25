local kube = import "../../templates/kubernetes.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // ddclient Component
    local ddclientComponentName = "ddclient",

    local ddclientConfigMap = kube.configMap(
        namespace,
        name + "-" + ddclientComponentName,
        labels + {component: ddclientComponentName},
        {
            "ddclient.conf": |||
                daemon=300                              # check every 300 seconds
                syslog=yes                              # log update msgs to syslog
                pid=/var/run/ddclient/ddclient.pid              # record PID in file.

                ##
                ## CloudFlare (www.cloudflare.com)
                ##
                use=web
                protocol=cloudflare, \
                zone=%(zone)s, \
                ttl=10, \
                login=%(email)s, \
                password=%(password)s \
                %(domains)s
            ||| % {
                zone: conf.app.ddclient.cloudflare.zone,
                email: conf.app.ddclient.cloudflare.email,
                password: conf.app.ddclient.cloudflare.apiToken,
                domains: std.join(",", conf.app.ddclient.cloudflare.domains),
            },

        },
    ),

    // ddclient Deployment
    local ddclientDeployment = kube.deployment(
        namespace,
        name + "-" + ddclientComponentName,
        labels + {component: ddclientComponentName},
        [
            kube.deploymentContainer(
                ddclientComponentName,
                "linuxserver/ddclient",
                conf.app.ddclient.imageTag,
                volumeMounts = [
                    kube.containerVolumeMount("config", "/config"),
                ],
                resources = conf.kube.ddclient.resources,
            ),
        ],
        volumes = [
            kube.deploymentVolumeConfigMap("config", ddclientConfigMap.metadata.name),
        ],
    ),

    apiVersion: "v1",
    kind: "List",
    items: [
        ddclientConfigMap,
        ddclientDeployment,
    ]
};

{
    new:: new,
}