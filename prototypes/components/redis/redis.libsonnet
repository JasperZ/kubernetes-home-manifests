local kube = import "../../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
        resources:: {
            requests:: {
                cpu:: "50m",
                memory:: "50Mi",
            },
            limits:: {
                cpu:: "100m",
                memory:: "100Mi",
            },
        },
    },
    data:: {
        persist:: error "data.persist is required",
        nfsVolumes:: {
            data:: {
                nfsServer:: error "data.nfsVolumes.data.nfsServer is required",
                nfsPath:: error "data.nfsVolumes.data.nfsPath is required",
            },
        },
    },
};

local new(namespace, namePrefix, labels, config) = {
    local componentName = "redis",
    local dataDir = "data",

    local persistentVolumes = {
        data: kube.persistentVolume(
            namePrefix + "-" + componentName + "-" + dataDir,
            labels + {component: componentName},
            config.data.nfsVolumes.data.nfsServer,
            config.data.nfsVolumes.data.nfsPath,
        ),
    },

    local persistentVolumeClaims = {
        data: kube.persistentVolumeClaim(
            namespace,
            persistentVolumes.data.metadata.name,
            labels + {component: componentName},
            persistentVolumes.data.metadata.name,
        ),
    },
    
    local deployment = kube.deployment(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        [
            kube.deploymentContainer(
                componentName,
                "redis",
                config.kube.imageTag,
                ports = [
                    kube.containerPort(6379),
                ],
                volumeMounts = (
                    if config.data.persist then [
                        kube.containerVolumeMount(dataDir, "/data"),
                    ] else []
                ),
                resources = kube.resources(
                    config.kube.resources.requests.cpu,
                    config.kube.resources.requests.memory,
                    config.kube.resources.limits.cpu,
                    config.kube.resources.limits.memory,
                ),
            ),
        ],
        volumes = (
            if config.data.persist then [
                kube.deploymentVolumePVC(dataDir, persistentVolumeClaims.data.metadata.name),
            ] else []
        ),
    ),

    local service = kube.service(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        deployment.metadata.labels,
        [
            kube.servicePort("redis", "TCP", 6379, 6379),
        ],
    ),

    local initContainer = kube.deploymentContainer(
        "init-redis",
        "redis",
        config.kube.imageTag,
        command = [
            "sh",
            "-c",
            "until redis-cli -h %(service)s -p 6379 ping; do echo waiting for %(service)s; sleep 2; done;" % {service: service.metadata.name},
        ],
    ),

    persistentVolumes: persistentVolumes,
    persistentVolumeClaims: persistentVolumeClaims,
    service: service,
    deployment: deployment,
    initContainer: initContainer,
};

{
    configuration:: configuration,
    new:: new,
}