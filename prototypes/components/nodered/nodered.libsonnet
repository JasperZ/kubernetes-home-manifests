local kube = import "../../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
        resources:: {
            requests:: {
                cpu:: "50m",
                memory:: "80Mi",
            },
            limits:: {
                cpu:: "80m",
                memory:: "150Mi",
            },
        },
        certificateIssuer:: {
            name:: error "kube.certificateIssuer.name is required",
            kind:: error "kube.certificateIssuer.kind is required",
        },
    },
    app:: {
        timezone:: error "app.timezone is required",
        ip:: error "app.ip is required",
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
    local componentName = "nodered",
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
                "nodered/node-red-docker",
                config.kube.imageTag,
                env = [
                    kube.containerEnvFromValue("TZ", config.app.timezone),
                ],
                ports = [
                    kube.containerPort(1880),
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
            kube.servicePort("http", "TCP", 80, 1880),
        ],
    ) + {
        spec+: {
            type: "LoadBalancer", 
            loadBalancerIP: config.app.ip,
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