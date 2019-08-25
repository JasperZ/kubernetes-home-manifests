local kube = import "../../templates/kubernetes.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // Urbackup Component
    local urbackupComponentName = "urbackup",
    local urbackupDatabaseDir = "database",
    local urbackupBackupDir = "backups",

    // Urbackup PersistentVolumes
    local urbackupPersistentVolumes = {
        config: kube.persistentVolume(
            name + "-" + urbackupComponentName + "-" + urbackupDatabaseDir,
            labels + {component: urbackupComponentName},
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + urbackupComponentName + "/" + urbackupDatabaseDir,
        ),
        media: kube.persistentVolume(
            name + "-" + urbackupComponentName + "-" + urbackupBackupDir,
            labels + {component: urbackupComponentName},
            conf.app.persistentData.cheap.nfsServer,
            conf.app.persistentData.cheap.nfsRootPath + "/" + urbackupComponentName + "/" + urbackupBackupDir,
        ),
    },

    // Urbackup PersistentVolumeClaims
    local urbackupPersistentVolumeClaims = {
        config: kube.persistentVolumeClaim(
            namespace,
            urbackupPersistentVolumes.config.metadata.name,
            labels + {component: urbackupComponentName},
            urbackupPersistentVolumes.config.metadata.name,
        ),
        media: kube.persistentVolumeClaim(
            namespace,
            urbackupPersistentVolumes.media.metadata.name,
            labels + {component: urbackupComponentName},
            urbackupPersistentVolumes.media.metadata.name,
        ),
    },

    // Urbackup Deployment
    local urbackupDeployment = kube.deployment(
        namespace,
        name + "-" + urbackupComponentName,
        labels + {component: urbackupComponentName},
        [
            kube.deploymentContainer(
                urbackupComponentName,
                "uroni/urbackup-server",
                conf.app.urbackup.imageTag,
                ports = [
                    kube.containerPort(55413),
                    kube.containerPort(55414),
                    kube.containerPort(55415),
                ],
                volumeMounts = (
                    if conf.app.persistentData.use then [
                        kube.containerVolumeMount(urbackupDatabaseDir, "/var/urbackup"),
                        kube.containerVolumeMount(urbackupBackupDir, "/backups"),
                    ] else []
                ),
                resources = conf.kube.urbackup.resources,
            ),
        ],
        volumes = (
            if conf.app.persistentData.use then [
                kube.deploymentVolumePVC(urbackupDatabaseDir, urbackupPersistentVolumeClaims.config.metadata.name),
                kube.deploymentVolumePVC(urbackupBackupDir, urbackupPersistentVolumeClaims.media.metadata.name),
            ] else []
        ),
    ),

    // Urbackup Service
    local urbackupService = kube.service(
        namespace,
        name + "-" + urbackupComponentName,
        labels + {component: urbackupComponentName},
        urbackupDeployment.metadata.labels,
        [
            kube.servicePort("fast-cgi", "TCP", 55413, 55413),
            kube.servicePort("http", "TCP", 80, 55414),
            kube.servicePort("internet-clients", "TCP", 55415, 55415),
        ],
    ) + {
        spec+: {
            type: "LoadBalancer", 
            loadBalancerIP: conf.app.urbackup.ip,
            externalTrafficPolicy: "Local",
        },
    },

    apiVersion: "v1",
    kind: "List",
    items: [
        urbackupService,
        urbackupDeployment,
    ] + (
        if conf.app.persistentData.use then [
            urbackupPersistentVolumes[x] for x in std.objectFields(urbackupPersistentVolumes)
        ] + [
            urbackupPersistentVolumeClaims[x] for x in std.objectFields(urbackupPersistentVolumeClaims)  
        ] else []
    ),
};

{
    new:: new,
}