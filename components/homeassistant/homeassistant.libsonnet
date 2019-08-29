local kube = import "../../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
        resources:: {
            requests:: {
                cpu:: "50m",
                memory:: "100Mi",
            },
            limits:: {
                cpu:: "150m",
                memory:: "150Mi",
            },
        },
        certificateIssuer:: {
            name:: error "kube.certificateIssuer.name is required",
            kind:: error "kube.certificateIssuer.kind is required",
        },
    },
    app:: {
        domain:: error "app.domain is required",
    },
    data:: {
        persist:: error "data.persist is required",
        nfsVolumes:: {
            config:: {
                nfsServer:: error "data.nfsVolumes.config.nfsServer is required",
                nfsPath:: error "data.nfsVolumes.config.nfsPath is required",
            },
        },
    },
};

local new(namespace, namePrefix, labels, config, influxdbComponent=null, mariadbComponent=null) = {
    local componentName = "homeassistant",
    local configDir = "config",

    local persistentVolumes = {
        config: kube.persistentVolume(
            namePrefix + "-" + componentName + "-" + configDir,
            labels + {component: componentName},
            config.data.nfsVolumes.config.nfsServer,
            config.data.nfsVolumes.config.nfsPath,
        ),
    },

    local persistentVolumeClaims = {
        config: kube.persistentVolumeClaim(
            namespace,
            persistentVolumes.config.metadata.name,
            labels + {component: componentName},
            persistentVolumes.config.metadata.name,
        ),
    },
    
    local deployment = kube.deployment(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        [
            kube.deploymentContainer(
                componentName,
                "homeassistant/home-assistant",
                config.kube.imageTag,
                ports = [
                    kube.containerPort(8123),
                ],
                volumeMounts = (
                    if config.data.persist then [
                        kube.containerVolumeMount(configDir, "/config"),
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
        initContainers = (
            if influxdbComponent != null then [
                influxdbComponent.initContainer,
            ] else []
        ) + (
            if mariadbComponent != null then [
                mariadbComponent.initContainer,
            ] else []
        ),
        volumes = (
            if config.data.persist then [
                kube.deploymentVolumePVC(configDir, persistentVolumeClaims.config.metadata.name),
            ] else []
        ),
    ),

    local service = kube.service(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        deployment.metadata.labels,
        [
            kube.servicePort("http", "TCP", 80, 8123),
        ],
    ),

    local certificate = kube.certificate(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        "%(domain)s-tls" % {domain: std.strReplace(config.app.domain, ".", "-")},
        config.app.domain,
        {metadata: config.kube.certificateIssuer},
    ),

    local ingress = kube.ingress(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        tls = [
            kube.ingressTls(
                [config.app.domain],
                "%(domain)s-tls" % {domain: std.strReplace(config.app.domain, ".", "-")}
            ),
        ],
        rules = [
            kube.ingressRule(
                config.app.domain,
                [
                    kube.ingressRulePath(service.metadata.name, 80),
                ],
            ),
        ],
    ),

    persistentVolumes: persistentVolumes,
    persistentVolumeClaims: persistentVolumeClaims,
    service: service,
    deployment: deployment,
    certificate: certificate,
    ingress: ingress,
};

{
    configuration:: configuration,
    new:: new,
}