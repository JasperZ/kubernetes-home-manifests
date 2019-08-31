local kube = import "../../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
        resources:: {
            requests:: {
                cpu:: "5m",
                memory:: "25Mi",
            },
            limits:: {
                cpu:: "10m",
                memory:: "35Mi",
            },
        },
    },
    params:: {
        cloudflare:: {
            email:: error "params.cloudflare.email is required",
            apiToken:: error "params.cloudflare.apiToken is required",
            zone:: error "params.cloudflare.zone is required",
            domains:: error "params.cloudflare.domains is required",
        },
    },
};

local new(namespace, namePrefix, labels, config) = {
    local componentName = "ddclient",

    local configMap = kube.configMap(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
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
                zone: config.params.cloudflare.zone,
                email: config.params.cloudflare.email,
                password: config.params.cloudflare.apiToken,
                domains: std.join(",", config.params.cloudflare.domains),
            },

        },
    ),

    local deployment = kube.deployment(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        [
            kube.deploymentContainer(
                componentName,
                "linuxserver/ddclient",
                config.kube.imageTag,
                volumeMounts = [
                    kube.containerVolumeMount("config", "/config"),
                ],
                resources = kube.resources(
                    config.kube.resources.requests.cpu,
                    config.kube.resources.requests.memory,
                    config.kube.resources.limits.cpu,
                    config.kube.resources.limits.memory,
                ),
            ),
        ],
        volumes = [
            kube.deploymentVolumeConfigMap("config", configMap.metadata.name),
        ],
    ),

    configMap: configMap,
    deployment: deployment,
};

{
    configuration:: configuration,
    new:: new,
}