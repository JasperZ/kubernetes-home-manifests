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
        webPassword:: error "params.webPassword is required",
    },
    // data:: {
    //     persist:: error "data.persist is required",
    //     nfsVolumes:: {
    //         database:: {
    //             nfsServer:: error "config.nfsVolumes.data.nfsServer is required",
    //             nfsPath:: error "config.nfsVolumes.data.nfsPath is required",
    //         },
    //         backups:: {
    //             nfsServer:: error "data.nfsVolumes.data.nfsServer is required",
    //             nfsPath:: error "data.nfsVolumes.data.nfsPath is required",
    //         },
    //     },
    // },
};

local new(namespace, namePrefix, labels, config) = {
    local componentName = "pihole",
    // local databaseDir = "database",
    // local backupDir = "backups",
    
    // local persistentVolumes = {
    //     database: kube.persistentVolume(
    //         namePrefix + "-" + componentName + "-" + databaseDir,
    //         labels + {component: componentName},
    //         config.data.nfsVolumes.database.nfsServer,
    //         config.data.nfsVolumes.database.nfsPath,
    //     ),
    //     backups: kube.persistentVolume(
    //         namePrefix + "-" + componentName + "-" + backupDir,
    //         labels + {component: componentName},
    //         config.data.nfsVolumes.backups.nfsServer,
    //         config.data.nfsVolumes.backups.nfsPath,
    //     ),
    // },
    
    // local persistentVolumeClaims = {
    //     database: kube.persistentVolumeClaim(
    //         namespace,
    //         persistentVolumes.database.metadata.name,
    //         labels + {component: componentName},
    //         persistentVolumes.database.metadata.name,
    //     ),
    //     backups: kube.persistentVolumeClaim(
    //         namespace,
    //         persistentVolumes.backups.metadata.name,
    //         labels + {component: componentName},
    //         persistentVolumes.backups.metadata.name,
    //     ),
    // },
    
    local deployment = kube.deployment(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        [
            kube.deploymentContainer(
                componentName,
                "pihole/pihole",
                config.kube.imageTag,
                env = [
                    kube.containerEnvFromValue("WEBPASSWORD", config.params.webPassword),
                ],
                ports = [
                    kube.containerPort(53),
                    kube.containerPort(53, "UDP"),
                    kube.containerPort(67, "UDP"),
                    kube.containerPort(80),
                    kube.containerPort(443),
                ],
                // volumeMounts = (
                //     if config.data.persist then [
                //         kube.containerVolumeMount(databaseDir, "/var/urbackup"),
                //         kube.containerVolumeMount(backupDir, "/backups"),
                //     ] else []
                // ),
                resources = kube.resources(
                    config.kube.resources.requests.cpu,
                    config.kube.resources.requests.memory,
                    config.kube.resources.limits.cpu,
                    config.kube.resources.limits.memory,
                ),
            ),
        ],
        // volumes = (
        //     if config.data.persist then [
        //         kube.deploymentVolumePVC(databaseDir, persistentVolumeClaims.database.metadata.name),
        //         kube.deploymentVolumePVC(backupDir, persistentVolumeClaims.backups.metadata.name),
        //     ] else []
        // ),
    ),
    
    local tcpService = kube.service(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        deployment.metadata.labels,
        [
            kube.servicePort("dns", "TCP", 53, 53),
            kube.servicePort("web", "TCP", 80, 80),
            kube.servicePort("web-ssl", "TCP", 443, 443),
        ],
    ) + {
        metadata+: {
            name+: "-tcp",
            annotations: {
                "metallb.universe.tf/allow-shared-ip": config.params.ip,
            },
        },
        spec+: {
            type: "LoadBalancer", 
            loadBalancerIP: config.params.ip,
            externalTrafficPolicy: "Local",
        },
    },

    local udpService = kube.service(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        deployment.metadata.labels,
        [
            kube.servicePort("dns", "UDP", 53, 53),
            kube.servicePort("dhcp", "UDP", 67, 67),
        ],
    ) + {
        metadata+: {
            name+: "-udp",
            annotations: {
                "metallb.universe.tf/allow-shared-ip": config.params.ip,
            },
        },
        spec+: {
            type: "LoadBalancer", 
            loadBalancerIP: config.params.ip,
            externalTrafficPolicy: "Local",
        },
    },

    // persistentVolumes: persistentVolumes,
    // persistentVolumeClaims: persistentVolumeClaims,
    tcpService: tcpService,
    udpService: udpService,
    deployment: deployment,
};

{
    configuration:: configuration,
    new:: new,
}