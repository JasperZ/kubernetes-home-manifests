local kube = import "../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
        resources:: {
            requests:: {
                cpu:: "125m",
                memory:: "128Mi",
            },
            limits:: {
                cpu:: "500m",
                memory:: "512Mi",
            },
        },
    },
    app:: {
        ip:: error "app.ip is required",
    },
    data:: {
        persist:: error "data.persist is required",
        nfsVolumes:: {
            config:: {
                nfsServer:: error "config.nfsVolumes.config.nfsServer is required",
                nfsPath:: error "config.nfsVolumes.config.nfsPath is required",
            },
            media:: {
                nfsServer:: error "data.nfsVolumes.media.nfsServer is required",
                nfsPath:: error "data.nfsVolumes.media.nfsPath is required",
            },
        },
    },
};

local new(namespace, namePrefix, labels, config) = {
    local componentName = "motioneye",
    local motioneyeConfigDir = "config",
    local motioneyeMediaDir = "media",
    
    local persistentVolumes = {
        config: kube.persistentVolume(
            namePrefix + "-" + componentName + "-" + motioneyeConfigDir,
            labels + {component: componentName},
            config.data.config.nfsServer,
            config.data.config.nfsPath,
        ),
        media: kube.persistentVolume(
            namePrefix + "-" + componentName + "-" + motioneyeMediaDir,
            labels + {component: componentName},
            config.data.media.nfsServer,
            config.data.media.nfsPath,
        ),
    },
    
    local persistentVolumeClaims = {
        config: kube.persistentVolumeClaim(
            namespace,
            persistentVolumes.config.metadata.name,
            labels + {component: componentName},
            persistentVolumes.config.metadata.name,
        ),
        media: kube.persistentVolumeClaim(
            namespace,
            persistentVolumes.media.metadata.name,
            labels + {component: componentName},
            persistentVolumes.media.metadata.name,
        ),
    },

    local deployment = kube.deployment(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        [
            kube.deploymentContainer(
                componentName,
                "ccrisan/motioneye",
                config.kube.imageTag,
                ports = [
                    kube.containerPort(8765),
                ],
                volumeMounts = (
                    if config.data.persist then [
                        kube.containerVolumeMount(motioneyeConfigDir, "/etc/motioneye"),
                        kube.containerVolumeMount(motioneyeMediaDir, "/var/lib/motioneye"),
                    ] else []
                ),
                resources = kube.resources(
                    config.kube.nextcloud.resources.requests.cpu,
                    config.kube.nextcloud.resources.requests.memory,
                    config.kube.nextcloud.resources.limits.cpu,
                    config.kube.nextcloud.resources.limits.memory,
                ),
            ),
        ],
        volumes = (
            if config.data.persist then [
                kube.deploymentVolumePVC(motioneyeConfigDir, persistentVolumeClaims.config.metadata.name),
                kube.deploymentVolumePVC(motioneyeMediaDir, persistentVolumeClaims.media.metadata.name),
            ] else []
        ),
    ),
    
    local service = kube.service(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        deployment.metadata.labels,
        [
            kube.servicePort("http", "TCP", 80, 8765),
        ],
    ) + {
        spec+: {
            type: "LoadBalancer", 
            loadBalancerIP: conf.app.motioneye.ip,
            externalTrafficPolicy: "Local",
        },
    },

    persistentVolumes: persistentVolumes,
    persistentVolumeClaims: persistentVolumeClaims,
    service: service,
    deployment: deployment,
};

{
    configuration:: configuration,
    new:: new,
}