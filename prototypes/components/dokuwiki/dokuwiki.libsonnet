local kube = import "../../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
        resources:: {
            requests:: {
                cpu:: "10m",
                memory:: "15Mi",
            },
            limits:: {
                cpu:: "30m",
                memory:: "25Mi",
            },
        },
    },
    params:: {
        adminUsername:: error "params.adminUsername is required",
        adminPassword:: error "params.adminPassword is required",
        adminFullName:: error "params.adminFullName is required",
        adminEmail:: error "params.adminEmail is required",
        wikiName:: error "params.wikiName is required",
        ip:: error "params.ip is required",
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
    local componentName = "dokuwiki",
    local dataDir = "data",

    local secret = kube.secret(
        namespace, 
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        stringData = {
            DOKUWIKI_USERNAME: config.params.adminUsername,
            DOKUWIKI_PASSWORD: config.params.adminPassword,
            DOKUWIKI_FULL_NAME: config.params.adminFullName,
            DOKUWIKI_EMAIL: config.params.adminEmail,
        },
    ),
    
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
                "bitnami/dokuwiki",
                config.kube.imageTag,
                env = [
                    kube.containerEnvFromSecret("DOKUWIKI_USERNAME", secret.metadata.name, "DOKUWIKI_USERNAME"),
                    kube.containerEnvFromSecret("DOKUWIKI_PASSWORD", secret.metadata.name, "DOKUWIKI_PASSWORD"),
                    kube.containerEnvFromSecret("DOKUWIKI_FULL_NAME", secret.metadata.name, "DOKUWIKI_FULL_NAME"),
                    kube.containerEnvFromSecret("DOKUWIKI_EMAIL", secret.metadata.name, "DOKUWIKI_EMAIL"),
                    kube.containerEnvFromValue("DOKUWIKI_WIKI_NAME", config.params.wikiName),
                ],
                ports = [
                    kube.containerPort(80),
                ],
                volumeMounts = (
                    if config.data.persist then [
                        kube.containerVolumeMount(dataDir, "/bitnami/dokuwiki"),
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
            kube.servicePort("http", "TCP", 80, 80),
        ],
    ) + {
        spec+: {
            type: "LoadBalancer", 
            loadBalancerIP: config.params.ip,
            externalTrafficPolicy: "Local",
        },
    },

    secret: secret,
    persistentVolumes: persistentVolumes,
    persistentVolumeClaims: persistentVolumeClaims,
    service: service,
    deployment: deployment,
};

{
    configuration:: configuration,
    new:: new,
}