local kube = import "../templates/kubernetes.libsonnet";

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
        certificateIssuer:: {
            name:: error "kube.certificateIssuer.name is required",
            kind:: error "kube.certificateIssuer.kind is required",
        },
    },
    app:: {
        adminToken:: error "bitwarden.adminToken is required",
        signupsAllowed:: error "bitwarden.signupsAllowed is required",
        domain:: error "bitwarden.domain is required",
        smtp:: {
            use:: error "bitwarden.smtp.use is required",
            host:: error "bitwarden.smtp.host is required",
            from:: error "bitwarden.smtp.from is required",
            port:: error "bitwarden.smtp.port is required",
            ssl:: error "bitwarden.smtp.ssl is required",
            username:: error "bitwarden.smtp.username is required",
            password:: error "bitwarden.smtp.password is required",
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
    local componentName = "bitwarden",
    local dataDir = "data",

    local secret = kube.secret(
        namespace, 
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        stringData = {
            ADMIN_TOKEN: config.app.adminToken,
        } + (
            if config.app.smtp.use then {
                SMTP_HOST: config.app.smtp.host,
                SMTP_FROM: config.app.smtp.from,
                SMTP_PORT: config.app.smtp.port,
                SMTP_SSL: config.app.smtp.ssl,
                SMTP_USERNAME: config.app.smtp.username,
                SMTP_PASSWORD: config.app.smtp.password,
            } else {}
        ),
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
                "bitwardenrs/server",
                config.kube.imageTag,
                env = [
                    kube.containerEnvFromValue("DOMAIN", "https://%s" % config.app.domain),
                    kube.containerEnvFromValue("WEBSOCKET_ENABLED", "true"),
                    kube.containerEnvFromValue("SIGNUPS_ALLOWED", config.app.signupsAllowed),
                    kube.containerEnvFromSecret("ADMIN_TOKEN", secret.metadata.name, "ADMIN_TOKEN"),
                ] + (
                    if config.app.smtp.use then [
                        kube.containerEnvFromSecret("SMTP_HOST", secret.metadata.name, "SMTP_HOST"),
                        kube.containerEnvFromSecret("SMTP_FROM", secret.metadata.name, "SMTP_FROM"),
                        kube.containerEnvFromSecret("SMTP_PORT", secret.metadata.name, "SMTP_PORT"),
                        kube.containerEnvFromSecret("SMTP_SSL", secret.metadata.name, "SMTP_SSL"),
                        kube.containerEnvFromSecret("SMTP_USERNAME", secret.metadata.name, "SMTP_USERNAME"),
                        kube.containerEnvFromSecret("SMTP_PASSWORD", secret.metadata.name, "SMTP_PASSWORD"),
                    ] else []
                ),
                ports = [
                    kube.containerPort(80),
                    kube.containerPort(3012),
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
            kube.servicePort("http", "TCP", 80, 80),
            kube.servicePort("websocket", "TCP", 3012, 3012),
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
                    kube.ingressRulePath(service.metadata.name, 80, "/"),
                    kube.ingressRulePath(service.metadata.name, 80, "/notifications/hub/negotiate"),
                    kube.ingressRulePath(service.metadata.name, 3012, "/notifications/hub"),
                ],
            ),
        ],
    ),

    secret: secret,
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