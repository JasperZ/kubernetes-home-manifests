local kube = import "../../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
        resources:: {
            requests:: {
                cpu:: "80m",
                memory:: "100Mi",
            },
            limits:: {
                cpu:: "150m",
                memory:: "200Mi",
            },
        },
    },
    params:: {
        ip:: error "params.ip is required",
    },
    data:: {
        persist:: error "data.persist is required",
        nfsVolumes:: {
            database:: {
                nfsServer:: error "config.nfsVolumes.data.nfsServer is required",
                nfsPath:: error "config.nfsVolumes.data.nfsPath is required",
            },
            backups:: {
                nfsServer:: error "data.nfsVolumes.data.nfsServer is required",
                nfsPath:: error "data.nfsVolumes.data.nfsPath is required",
            },
        },
    },
};

local new(namespace, namePrefix, labels, config) = {
    local componentName = "urbackup",
    local databaseDir = "database",
    local backupDir = "backups",
    
    local persistentVolumes = {
        database: kube.persistentVolume(
            namePrefix + "-" + componentName + "-" + databaseDir,
            labels + {component: componentName},
            config.data.nfsVolumes.database.nfsServer,
            config.data.nfsVolumes.database.nfsPath,
        ),
        backups: kube.persistentVolume(
            namePrefix + "-" + componentName + "-" + backupDir,
            labels + {component: componentName},
            config.data.nfsVolumes.backups.nfsServer,
            config.data.nfsVolumes.backups.nfsPath,
        ),
    },
    
    local persistentVolumeClaims = {
        database: kube.persistentVolumeClaim(
            namespace,
            persistentVolumes.database.metadata.name,
            labels + {component: componentName},
            persistentVolumes.database.metadata.name,
        ),
        backups: kube.persistentVolumeClaim(
            namespace,
            persistentVolumes.backups.metadata.name,
            labels + {component: componentName},
            persistentVolumes.backups.metadata.name,
        ),
    },
    
    local deployment = kube.deployment(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        [
            kube.deploymentContainer(
                componentName,
                "uroni/urbackup-server",
                config.kube.imageTag,
                ports = [
                    kube.containerPort(55413),
                    kube.containerPort(55414),
                    kube.containerPort(55415),
                ],
                volumeMounts = (
                    if config.data.persist then [
                        kube.containerVolumeMount(databaseDir, "/var/urbackup"),
                        kube.containerVolumeMount(backupDir, "/backups"),
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
                kube.deploymentVolumePVC(databaseDir, persistentVolumeClaims.database.metadata.name),
                kube.deploymentVolumePVC(backupDir, persistentVolumeClaims.backups.metadata.name),
            ] else []
        ),
    ),
    
    local service = kube.service(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        deployment.metadata.labels,
        [
            kube.servicePort("fast-cgi", "TCP", 55413, 55413),
            kube.servicePort("http", "TCP", 80, 55414),
            kube.servicePort("internet-clients", "TCP", 55415, 55415),
        ],
    ) + {
        spec+: {
            type: "LoadBalancer", 
            loadBalancerIP: config.params.ip,
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