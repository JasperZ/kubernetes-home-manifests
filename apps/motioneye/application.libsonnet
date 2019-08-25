local kube = import "../../templates/kubernetes.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // MotionEye Component
    local motioneyeComponentName = "motioneye",
    local motioneyeConfigDir = "config",
    local motioneyeMediaDir = "media",

    // MotionEye PersistentVolumes
    local motioneyePersistentVolumes = {
        config: kube.persistentVolume(
            name + "-" + motioneyeComponentName + "-" + motioneyeConfigDir,
            labels + {component: motioneyeComponentName},
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + motioneyeComponentName + "/" + motioneyeConfigDir,
        ),
        media: kube.persistentVolume(
            name + "-" + motioneyeComponentName + "-" + motioneyeMediaDir,
            labels + {component: motioneyeComponentName},
            conf.app.persistentData.cheap.nfsServer,
            conf.app.persistentData.cheap.nfsRootPath + "/" + motioneyeComponentName + "/" + motioneyeMediaDir,
        ),
    },

    // MotionEye PersistentVolumeClaims
    local motioneyePersistentVolumeClaims = {
        config: kube.persistentVolumeClaim(
            namespace,
            motioneyePersistentVolumes.config.metadata.name,
            labels + {component: motioneyeComponentName},
            motioneyePersistentVolumes.config.metadata.name,
        ),
        media: kube.persistentVolumeClaim(
            namespace,
            motioneyePersistentVolumes.media.metadata.name,
            labels + {component: motioneyeComponentName},
            motioneyePersistentVolumes.media.metadata.name,
        ),
    },

    // MotionEye Deployment
    local motioneyeDeployment = kube.deployment(
        namespace,
        name + "-" + motioneyeComponentName,
        labels + {component: motioneyeComponentName},
        [
            kube.deploymentContainer(
                motioneyeComponentName,
                "ccrisan/motioneye",
                conf.app.motioneye.imageTag,
                ports = [
                    kube.containerPort(8765),
                ],
                volumeMounts = (
                    if conf.app.persistentData.use then [
                        kube.containerVolumeMount(motioneyeConfigDir, "/etc/motioneye"),
                        kube.containerVolumeMount(motioneyeMediaDir, "/var/lib/motioneye"),
                    ] else []
                ),
                resources = conf.kube.motioneye.resources,
            ),
        ],
        volumes = (
            if conf.app.persistentData.use then [
                kube.deploymentVolumePVC(motioneyeConfigDir, motioneyePersistentVolumeClaims.config.metadata.name),
                kube.deploymentVolumePVC(motioneyeMediaDir, motioneyePersistentVolumeClaims.media.metadata.name),
            ] else []
        ),
    ),

    // MotionEye Service
    local motioneyeService = kube.service(
        namespace,
        name + "-" + motioneyeComponentName,
        labels + {component: motioneyeComponentName},
        motioneyeDeployment.metadata.labels,
        [
            kube.servicePort("TCP", 80, 8765),
        ],
    ) + {
        spec+: {
            type: "LoadBalancer", 
            loadBalancerIP: conf.app.motioneye.ip,
            externalTrafficPolicy: "Local",
        },
    },

    apiVersion: "v1",
    kind: "List",
    items: [
        motioneyeService,
        motioneyeDeployment,
    ] + (
        if conf.app.persistentData.use then [
            motioneyePersistentVolumes[x] for x in std.objectFields(motioneyePersistentVolumes)
        ] + [
            motioneyePersistentVolumeClaims[x] for x in std.objectFields(motioneyePersistentVolumeClaims)  
        ] else []
    ),
};

{
    new:: new,
}