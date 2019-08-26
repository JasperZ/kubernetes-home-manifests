local kube = import "../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        nextcloud:: {
            imageTag:: error "kube.nextcloud.imageTag is required",
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
        nginx:: {
            imageTag:: error "kube.nginx.imageTag is required",
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
        certificateIssuer:: {
            name:: error "kube.certificateIssuer.name is required",
            kind:: error "kube.certificateIssuer.kind is required",
        },
    },
    app:: {
        adminUser:: error "app.adminUser is required",
        adminPassword:: error "app.adminPassword is required",
        domain:: error "app.domain is required",
    },
    data:: {
        persist:: error "data.persist is required",
        nfsVolumes:: {
            html:: {
                nfsServer:: error "data.nfsVolumes.html.nfsServer is required",
                nfsPath:: error "data.nfsVolumes.html.nfsPath is required",
            },
            customApps:: {
                nfsServer:: error "data.nfsVolumes.customApps.nfsServer is required",
                nfsPath:: error "data.nfsVolumes.customApps.nfsPath is required",
            },
            config:: {
                nfsServer:: error "data.nfsVolumes.config.nfsServer is required",
                nfsPath:: error "data.nfsVolumes.config.nfsPath is required",
            },
            data:: {
                nfsServer:: error "data.nfsVolumes.data.nfsServer is required",
                nfsPath:: error "data.nfsVolumes.data.nfsPath is required",
            },
        },
    },
};

local new(namespace, namePrefix, labels, servicePort, config, mariadbComponent=null, redisComponent=null) = {
    local componentName = "nextcloud",
    local htmlDir = "html",
    local customAppsDir = "custom-apps",
    local configDir = "config",
    local dataDir = "data",

    local secret = kube.secret(
        namespace, 
        namePrefix + "-" + componentName,
        labels,
        stringData = {
            NEXTCLOUD_ADMIN_USER: config.app.adminUser,
            NEXTCLOUD_ADMIN_PASSWORD: config.app.adminPassword,
        }
    ),
    
    local persistentVolumes = {
        html: kube.persistentVolume(
            namePrefix + "-" + componentName + "-" + htmlDir,
            labels + {component: componentName},
            config.data.nfsVolumes.html.nfsServer,
            config.data.nfsVolumes.html.nfsPath + "/" + componentName + "/" + htmlDir,
        ),
        customApps: kube.persistentVolume(
            namePrefix + "-" + componentName + "-" + customAppsDir,
            labels + {component: componentName},
            config.data.nfsVolumes.customApps.nfsServer,
            config.data.nfsVolumes.customApps.nfsPath + "/" + componentName + "/" + customAppsDir,
        ),
        config: kube.persistentVolume(
            namePrefix + "-" + componentName + "-" + configDir,
            labels + {component: componentName},
            config.data.nfsVolumes.config.nfsServer,
            config.data.nfsVolumes.config.nfsPath + "/" + componentName + "/" + configDir,
        ),
        data: kube.persistentVolume(
            namePrefix + "-" + componentName + "-" + dataDir,
            labels + {component: componentName},
            config.data.nfsVolumes.data.nfsServer,
            config.data.nfsVolumes.data.nfsPath + "/" + componentName + "/" + dataDir,
        ),
    },
    
    local persistentVolumeClaims = {
        html: kube.persistentVolumeClaim(
            namespace,
            persistentVolumes.html.metadata.name,
            labels + {component: componentName},
            persistentVolumes.html.metadata.name,
        ),
        customApps: kube.persistentVolumeClaim(
            namespace,
            persistentVolumes.customApps.metadata.name,
            labels + {component: componentName},
            persistentVolumes.customApps.metadata.name,
        ),
        config: kube.persistentVolumeClaim(
            namespace,
            persistentVolumes.config.metadata.name,
            labels + {component: componentName},
            persistentVolumes.config.metadata.name,
        ),
        data: kube.persistentVolumeClaim(
            namespace,
            persistentVolumes.data.metadata.name,
            labels + {component: componentName},
            persistentVolumes.data.metadata.name,
        ),
    },
    
    local nginxConfigMap = kube.configMap(
        namespace,
        namePrefix + "-" + componentName + "-nginx",
        labels + {component: componentName},
        {
            "fpm_nextcloud.conf": importstr "resources/fpm_nextcloud.conf",
        },
    ),
    
    local deployment = kube.deployment(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        [
            kube.deploymentContainer(
                componentName,
                "nextcloud",
                config.kube.nextcloud.imageTag,
                env = [
                    kube.containerEnvFromSecret("NEXTCLOUD_ADMIN_USER", secret.metadata.name, "NEXTCLOUD_ADMIN_USER"),
                    kube.containerEnvFromSecret("NEXTCLOUD_ADMIN_PASSWORD", secret.metadata.name, "NEXTCLOUD_ADMIN_PASSWORD"),
                    kube.containerEnvFromValue("NEXTCLOUD_TRUSTED_DOMAINS", config.app.domain),
                ] + (
                    if mariadbComponent != null then [
                        kube.containerEnvFromSecret("MYSQL_USER", mariadbComponent.secret.metadata.name, "MYSQL_USER"),
                        kube.containerEnvFromSecret("MYSQL_PASSWORD", mariadbComponent.secret.metadata.name, "MYSQL_PASSWORD"),
                        kube.containerEnvFromSecret("MYSQL_DATABASE", mariadbComponent.secret.metadata.name, "MYSQL_DATABASE"),
                        kube.containerEnvFromValue("MYSQL_HOST", mariadbComponent.service.metadata.name),
                    ] else [
                        kube.containerEnvFromValue("SQLITE_DATABASE", "nextcloud"),
                    ]
                ) + (
                    if redisComponent != null then [
                        kube.containerEnvFromValue("REDIS_HOST", redisComponent.service.metadata.name),
                        kube.containerEnvFromValue("REDIS_HOST_PORT", "6379"),
                    ] else []
                ),
                volumeMounts = [
                    kube.containerVolumeMount(htmlDir, "/var/www/html"),
                    kube.containerVolumeMount(customAppsDir, "/var/www/html/custom_apps"),
                    kube.containerVolumeMount(configDir, "/var/www/html/config"),
                    kube.containerVolumeMount(dataDir, "/var/www/html/data"),
                ],
                resources = kube.resources(
                    config.kube.nextcloud.resources.requests.cpu,
                    config.kube.nextcloud.resources.requests.memory,
                    config.kube.nextcloud.resources.limits.cpu,
                    config.kube.nextcloud.resources.limits.memory,
                ),
            ),
            kube.deploymentContainer(
                componentName + "-nginx",
                "nginx",
                config.kube.nginx.imageTag,
                ports = [
                    kube.containerPort(80),
                ],
                volumeMounts = [
                    kube.containerVolumeMount("nginx", "/etc/nginx/conf.d"),
                    kube.containerVolumeMount(htmlDir, "/var/www/html"),
                    kube.containerVolumeMount(customAppsDir, "/var/www/html/custom_apps"),
                    kube.containerVolumeMount(configDir, "/var/www/html/config"),
                    kube.containerVolumeMount(dataDir, "/var/www/html/data"),
                ],
                resources = kube.resources(
                    config.kube.nginx.resources.requests.cpu,
                    config.kube.nginx.resources.requests.memory,
                    config.kube.nginx.resources.limits.cpu,
                    config.kube.nginx.resources.limits.memory,
                ),
            ),
        ],
        initContainers = (
            if mariadbComponent != null then [
                mariadbComponent.initContainer,
            ] else []
        ) + (
            if redisComponent != null then [
                mariadbComponent.initContainer,
            ] else []
        ),
        volumes = [
            kube.deploymentVolumeConfigMap("nginx", nginxConfigMap.metadata.name),
        ] + (
            if config.data.persist then [
                kube.deploymentVolumePVC(htmlDir, persistentVolumeClaims.html.metadata.name),
                kube.deploymentVolumePVC(customAppsDir, persistentVolumeClaims.customApps.metadata.name),
                kube.deploymentVolumePVC(configDir, persistentVolumeClaims.config.metadata.name),
                kube.deploymentVolumePVC(dataDir, persistentVolumeClaims.data.metadata.name),
            ] else [
                kube.deploymentVolumeEmptyDir(htmlDir),
                kube.deploymentVolumeEmptyDir(customAppsDir),
                kube.deploymentVolumeEmptyDir(configDir),
                kube.deploymentVolumeEmptyDir(dataDir),
            ]
        ),
    ),
    
    local cronJob = kube.cronJob(
        namespace,
        namePrefix + "-" + componentName + "-cron",
        labels + {component: componentName},
        "*/15 * * * *",
        [
            kube.deploymentContainer(
                componentName,
                "nextcloud",
                config.kube.nextcloud.imageTag,
                command = [
                    "su",
                    "-p",
                    "www-data",
                    "-s",
                    "/bin/sh",
                    "-c", 
                    "php -f /var/www/html/cron.php",
                ],
                volumeMounts = [
                    kube.containerVolumeMount(htmlDir, "/var/www/html"),
                    kube.containerVolumeMount(customAppsDir, "/var/www/html/custom_apps"),
                    kube.containerVolumeMount(configDir, "/var/www/html/config"),
                    kube.containerVolumeMount(dataDir, "/var/www/html/data"),
                ],
                resources = kube.resources(
                    config.kube.nextcloud.resources.requests.cpu,
                    config.kube.nextcloud.resources.requests.memory,
                    config.kube.nextcloud.resources.limits.cpu,
                    config.kube.nextcloud.resources.limits.memory,
                ),
            ),
        ],
        initContainers = (
            if mariadbComponent != null then [
                mariadbComponent.initContainer,
            ] else []
        ) + (
            if redisComponent != null then [
                mariadbComponent.initContainer,
            ] else []
        ),
        volumes = (
            if config.data.persist then [
                kube.deploymentVolumePVC(htmlDir, persistentVolumeClaims.html.metadata.name),
                kube.deploymentVolumePVC(customAppsDir, persistentVolumeClaims.customApps.metadata.name),
                kube.deploymentVolumePVC(configDir, persistentVolumeClaims.config.metadata.name),
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
            kube.servicePort("http", "TCP", servicePort, 80),
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

    secret: secret,
    nginxConfigMap: nginxConfigMap,
    service: service,
    deployment: deployment,
    cronJob: cronJob,
    certificate: certificate,
    ingress: ingress,
};

{
    configuration:: configuration,
    new:: new,
}