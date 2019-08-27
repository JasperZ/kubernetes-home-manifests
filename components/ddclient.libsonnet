local kube = import "../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
        resources:: {
            requests:: {
                cpu:: "250m",
                memory:: "128Mi",
            },
            limits:: {
                cpu:: "500m",
                memory:: "512Mi",
            },
        },
    },
    app:: {
        cloudflare:: {
            email:: error "app.cloudflare.email is required",
            apiToken:: error "app.cloudflare.apiToken is required",
            zone:: error "app.cloudflare.zone is required",
            domains:: error "app.cloudflare.domains is required",
        },
    },
};

local new(namespace, namePrefix, labels, servicePort, config) = {
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
                zone: config.app.cloudflare.zone,
                email: config.app.cloudflare.email,
                password: config.app.cloudflare.apiToken,
                domains: std.join(",", config.app.cloudflare.domains),
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