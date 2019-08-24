local kube = import "../../../templates/kubernetes.libsonnet";

local newInstance(namespace, name, labels, configuration) = {
    // Secret used by all components
    local secret = kube.secret(
        namespace, 
        name,
        labels,
        stringData = {
            NEXTCLOUD_ADMIN_USER: configuration.nextcloud.adminUser,
            NEXTCLOUD_ADMIN_PASSWORD: configuration.nextcloud.adminPassword,
        } + (
            if configuration.useMariadb then {
                MYSQL_ROOT_PASSWORD: configuration.mariadb.rootPassword,
                MYSQL_DATABASE: configuration.mariadb.databaseName,
                MYSQL_USER: configuration.mariadb.user,
                MYSQL_PASSWORD: configuration.mariadb.userPassword,
            } else {}
        ) + (
            if configuration.useOnlyoffice then {
                JWT_SECRET: configuration.onlyoffice.jwtSecret,
            } else {}
        ),
    ),

    // MariaDB Component
    local mariadbComponentName = "mariadb",
    local mariadbDataDir = "data",

    // MariaDB PersistentVolumes
    local mariadbPersistentVolumes = {
        data: kube.persistentVolume(
            name + "-" + mariadbComponentName + "-" + mariadbDataDir,
            labels + {component: mariadbComponentName},
            configuration.data.fast.nfsServer,
            configuration.data.fast.nfsRootPath + "/" + mariadbComponentName + "/" + mariadbDataDir,
        ),
    },

    // MariaDB PersistentVolumeClaims
    local mariadbPersistentVolumeClaims = {
        data: kube.persistentVolumeClaim(
            namespace,
            mariadbPersistentVolumes.data.metadata.name,
            labels + {component: mariadbComponentName},
            mariadbPersistentVolumes.data.metadata.name,
        ),
    },

    // MariaDB Deployment
    local mariadbDeployment = kube.deployment(
        namespace,
        name + "-" + mariadbComponentName,
        labels + {component: mariadbComponentName},
        [
            kube.deploymentContainer(
                mariadbComponentName,
                "mariadb",
                configuration.mariadb.imageTag,
                env = [
                    kube.containerEnvFromSecret("MYSQL_ROOT_PASSWORD", secret.metadata.name, "MYSQL_ROOT_PASSWORD"),
                    kube.containerEnvFromSecret("MYSQL_USER", secret.metadata.name, "MYSQL_USER"),
                    kube.containerEnvFromSecret("MYSQL_PASSWORD", secret.metadata.name, "MYSQL_PASSWORD"),
                    kube.containerEnvFromSecret("MYSQL_DATABASE", secret.metadata.name, "MYSQL_DATABASE"),
                ],
                ports = [
                    kube.containerPort(3306),
                ],
                volumeMounts = (
                    if configuration.persistentData then [
                        kube.containerVolumeMount(mariadbDataDir, "/var/lib/mysql"),
                    ] else []
                ),
                resources = kube.resources("125m", "128Mi", "500m", "512Mi"),
            ),
        ],
        volumes = (
            if configuration.persistentData then [
                kube.deploymentVolumePVC(mariadbDataDir, mariadbPersistentVolumeClaims.data.metadata.name),
            ] else []
        ),
    ),

    // MariaDB Service
    local mariadbService = kube.service(
        namespace,
        name + "-" + mariadbComponentName,
        labels + {component: mariadbComponentName},
        mariadbDeployment.metadata.labels,
        [
            kube.servicePort("TCP", 3306, 3306),
        ],
    ),

    // Redis Component
    local redisComponentName = "redis",
    local redisDataDir = "data",

    // Redis PersistentVolumes
    local redisPersistentVolumes = {
        data: kube.persistentVolume(
            name + "-" + redisComponentName + "-" + redisDataDir,
            labels + {component: redisComponentName},
            configuration.data.fast.nfsServer,
            configuration.data.fast.nfsRootPath + "/" + redisComponentName + "/" + redisDataDir,
        ),
    },

    // Redis PersistentVolumeClaims
    local redisPersistentVolumeClaims = {
        data: kube.persistentVolumeClaim(
            namespace,
            redisPersistentVolumes.data.metadata.name,
            labels + {component: redisComponentName},
            redisPersistentVolumes.data.metadata.name,
        ),
    },
    
    // Redis Deployment
    local redisDeployment = kube.deployment(
        namespace,
        name + "-" + redisComponentName,
        labels + {component: redisComponentName},
        [
            kube.deploymentContainer(
                redisComponentName,
                "redis",
                configuration.redis.imageTag,
                ports = [
                    kube.containerPort(6379),
                ],
                volumeMounts = (
                    if configuration.persistentData then [
                        kube.containerVolumeMount(redisDataDir, "/data"),
                    ] else []
                ),
                resources = kube.resources("125m", "128Mi", "250m", "256Mi"),
            ),
        ],
        volumes = (
            if configuration.persistentData then [
                kube.deploymentVolumePVC(redisDataDir, redisPersistentVolumeClaims.data.metadata.name),
            ] else []
        ),
    ),

    // Redis Service
    local redisService = kube.service(
        namespace,
        name + "-" + redisComponentName,
        labels + {component: redisComponentName},
        redisDeployment.metadata.labels,
        [
            kube.servicePort("TCP", 6379, 6379),
        ],
    ),

    // Onlyoffice Component
    local onlyofficeComponentName = "onlyoffice",

    // Onlyoffice Deployment
    local onlyofficeDeployment = kube.deployment(
        namespace,
        name + "-" + onlyofficeComponentName,
        labels + {component: onlyofficeComponentName},
        [
            kube.deploymentContainer(
                onlyofficeComponentName,
                "onlyoffice/documentserver",
                configuration.onlyoffice.imageTag,
                env = [
                    kube.containerEnvFromValue("JWT_ENABLED", "true"),
                    kube.containerEnvFromSecret("JWT_SECRET", secret.metadata.name, "JWT_SECRET"),
                ],
                ports = [
                    kube.containerPort(80),
                ],
                resources = kube.resources("250m", "256Mi", "1000m", "1024Mi"),
            ),
        ],
        volumes = (
            if configuration.persistentData then [
                kube.deploymentVolumePVC(mariadbDataDir, mariadbPersistentVolumeClaims.data.metadata.name),
            ] else []
        ),
    ),

    // Onlyoffice Service
    local onlyofficeService = kube.service(
        namespace,
        name + "-" + onlyofficeComponentName,
        labels + {component: onlyofficeComponentName},
        onlyofficeDeployment.metadata.labels,
        [
            kube.servicePort("TCP", 80, 80),
        ],
    ),

    // Onlyoffice Certificate
    local onlyofficeCertificate = kube.certificate(
        namespace,
        name + "-" + onlyofficeComponentName,
        labels + {component: onlyofficeComponentName},
        "%(domain)s-tls" % {domain: std.strReplace(configuration.onlyoffice.domain, ".", "-")},
        configuration.onlyoffice.domain,
        {metadata: configuration.certificateIssuer},
    ),

    // Onlyoffice Ingress
    local onlyofficeIngress = kube.ingress(
        namespace,
        name + "-" + onlyofficeComponentName,
        labels + {component: onlyofficeComponentName},
        "%(domain)s-tls" % {domain: std.strReplace(configuration.onlyoffice.domain, ".", "-")},
        configuration.onlyoffice.domain,
        onlyofficeService.metadata.name,
        80,
    ),

    // Nextcloud Component
    local nextcloudComponentName = "nextcloud",
    local nextcloudHtmlDir = "html",
    local nextcloudCustomAppsDir = "custom-apps",
    local nextcloudConfigDir = "config",
    local nextcloudDataDir = "data",

    // Nextcloud PersistentVolumes
    local nextcloudPersistentVolumes = {
        html: kube.persistentVolume(
            name + "-" + nextcloudComponentName + "-" + nextcloudHtmlDir,
            labels + {component: nextcloudComponentName},
            configuration.data.fast.nfsServer,
            configuration.data.fast.nfsRootPath + "/" + nextcloudComponentName + "/" + nextcloudHtmlDir,
        ),
        customApps: kube.persistentVolume(
            name + "-" + nextcloudComponentName + "-" + nextcloudCustomAppsDir,
            labels + {component: nextcloudComponentName},
            configuration.data.fast.nfsServer,
            configuration.data.fast.nfsRootPath + "/" + nextcloudComponentName + "/" + nextcloudCustomAppsDir,
        ),
        config: kube.persistentVolume(
            name + "-" + nextcloudComponentName + "-" + nextcloudConfigDir,
            labels + {component: nextcloudComponentName},
            configuration.data.fast.nfsServer,
            configuration.data.fast.nfsRootPath + "/" + nextcloudComponentName + "/" + nextcloudConfigDir,
        ),
        data: kube.persistentVolume(
            name + "-" + nextcloudComponentName + "-" + nextcloudDataDir,
            labels + {component: nextcloudComponentName},
            configuration.data.slow.nfsServer,
            configuration.data.slow.nfsRootPath + "/" + nextcloudComponentName + "/" + nextcloudDataDir,
        ),
    },

    // Nextcloud PersistentVolumeClaims
    local nextcloudPersistentVolumeClaims = {
        html: kube.persistentVolumeClaim(
            namespace,
            nextcloudPersistentVolumes.html.metadata.name,
            labels + {component: nextcloudComponentName},
            nextcloudPersistentVolumes.html.metadata.name,
        ),
        customApps: kube.persistentVolumeClaim(
            namespace,
            nextcloudPersistentVolumes.customApps.metadata.name,
            labels + {component: nextcloudComponentName},
            nextcloudPersistentVolumes.customApps.metadata.name,
        ),
        config: kube.persistentVolumeClaim(
            namespace,
            nextcloudPersistentVolumes.config.metadata.name,
            labels + {component: nextcloudComponentName},
            nextcloudPersistentVolumes.config.metadata.name,
        ),
        data: kube.persistentVolumeClaim(
            namespace,
            nextcloudPersistentVolumes.data.metadata.name,
            labels + {component: nextcloudComponentName},
            nextcloudPersistentVolumes.data.metadata.name,
        ),
    },

    // Nextcloud nginx ConfigMap
    local nextcloudNginxConfigMap = kube.configMap(
        namespace,
        name + "-" + nextcloudComponentName + "-nginx",
        labels + {component: nextcloudComponentName},
        {
            "fpm_nextcloud.conf": importstr "../resources/fpm_nextcloud.conf",
        },
    ),

    // Nextcloud Deployment
    local nextcloudDeployment = kube.deployment(
        namespace,
        name + "-" + nextcloudComponentName,
        labels + {component: nextcloudComponentName},
        [
            kube.deploymentContainer(
                nextcloudComponentName,
                "nextcloud",
                configuration.nextcloud.imageTag,
                env = [
                    kube.containerEnvFromSecret("NEXTCLOUD_ADMIN_USER", secret.metadata.name, "NEXTCLOUD_ADMIN_USER"),
                    kube.containerEnvFromSecret("NEXTCLOUD_ADMIN_PASSWORD", secret.metadata.name, "NEXTCLOUD_ADMIN_PASSWORD"),
                    kube.containerEnvFromValue("NEXTCLOUD_TRUSTED_DOMAINS", configuration.nextcloud.domain),
                ] + (
                    if configuration.useMariadb then [
                        kube.containerEnvFromSecret("MYSQL_USER", secret.metadata.name, "MYSQL_USER"),
                        kube.containerEnvFromSecret("MYSQL_PASSWORD", secret.metadata.name, "MYSQL_PASSWORD"),
                        kube.containerEnvFromSecret("MYSQL_DATABASE", secret.metadata.name, "MYSQL_DATABASE"),
                        kube.containerEnvFromValue("MYSQL_HOST", mariadbService.metadata.name),
                    ] else [
                        kube.containerEnvFromValue("SQLITE_DATABASE", "nextcloud"),
                    ]
                ) + (
                    if configuration.useRedis then [
                        kube.containerEnvFromValue("REDIS_HOST", redisService.metadata.name),
                        kube.containerEnvFromValue("REDIS_HOST_PORT", "6379"),
                    ] else []
                ),
                volumeMounts = [
                    kube.containerVolumeMount(nextcloudHtmlDir, "/var/www/html"),
                    kube.containerVolumeMount(nextcloudCustomAppsDir, "/var/www/html/custom_apps"),
                    kube.containerVolumeMount(nextcloudConfigDir, "/var/www/html/config"),
                    kube.containerVolumeMount(nextcloudDataDir, "/var/www/html/data"),
                ],
                resources = kube.resources("250m", "256Mi", "500m", "512Mi"),
            ),
            kube.deploymentContainer(
                nextcloudComponentName + "-nginx",
                "nginx",
                configuration.nextcloud.nginxImageTag,
                ports = [
                    kube.containerPort(80),
                ],
                volumeMounts = [
                    kube.containerVolumeMount("nginx", "/etc/nginx/conf.d"),
                    kube.containerVolumeMount(nextcloudHtmlDir, "/var/www/html"),
                    kube.containerVolumeMount(nextcloudCustomAppsDir, "/var/www/html/custom_apps"),
                    kube.containerVolumeMount(nextcloudConfigDir, "/var/www/html/config"),
                    kube.containerVolumeMount(nextcloudDataDir, "/var/www/html/data"),
                ],
                resources = kube.resources("125m", "128Mi", "250m", "256Mi"),
            ),
        ],
        initContainers = (
            if configuration.useMariadb then [
                kube.deploymentContainer(
                    "init-mariadb",
                    "mariadb",
                    configuration.mariadb.imageTag,
                    command = [
                        "sh",
                        "-c",
                        "until mysql -h %(service)s -u $MYSQL_USER --password=$MYSQL_PASSWORD -e 'SELECT 1'; do echo waiting for %(service)s; sleep 2; done;" % {service: mariadbService.metadata.name},
                    ],
                    env = [
                        kube.containerEnvFromSecret("MYSQL_USER", secret.metadata.name, "MYSQL_USER"),
                        kube.containerEnvFromSecret("MYSQL_PASSWORD", secret.metadata.name, "MYSQL_PASSWORD"),
                    ],
                    ports = [
                        kube.containerPort(3306),
                    ],
                    volumeMounts = (
                        if configuration.persistentData then [
                            kube.containerVolumeMount(mariadbDataDir, "/var/lib/mysql"),
                        ] else []
                    ),
                ),
            ] else []
        ) + (
            if configuration.useRedis then [
                kube.deploymentContainer(
                    "init-redis",
                    "redis",
                    configuration.redis.imageTag,
                    command = [
                        "sh",
                        "-c",
                        "until redis-cli -h %(service)s -p 6379 ping; do echo waiting for %(service)s; sleep 2; done;" % {service: redisService.metadata.name},
                    ],
                ),
            ] else []
        ),
        volumes = [
            kube.deploymentVolumeConfigMap("nginx", nextcloudNginxConfigMap.metadata.name),
        ] + (
            if configuration.persistentData then [
                kube.deploymentVolumePVC(nextcloudHtmlDir, nextcloudPersistentVolumeClaims.html.metadata.name),
                kube.deploymentVolumePVC(nextcloudCustomAppsDir, nextcloudPersistentVolumeClaims.customApps.metadata.name),
                kube.deploymentVolumePVC(nextcloudConfigDir, nextcloudPersistentVolumeClaims.config.metadata.name),
                kube.deploymentVolumePVC(nextcloudDataDir, nextcloudPersistentVolumeClaims.data.metadata.name),
            ] else [
                kube.deploymentVolumeEmptyDir(nextcloudHtmlDir),
                kube.deploymentVolumeEmptyDir(nextcloudCustomAppsDir),
                kube.deploymentVolumeEmptyDir(nextcloudConfigDir),
                kube.deploymentVolumeEmptyDir(nextcloudDataDir),
            ]
        ),
    ),

    // Nextcloud CronJob
    local nextcloudCronJob = kube.cronJob(
        namespace,
        name + "-" + nextcloudComponentName,
        labels + {component: nextcloudComponentName},
        "*/15 * * * *",
        kube.deploymentContainer(
            nextcloudComponentName,
            "nextcloud",
            configuration.nextcloud.imageTag,
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
                kube.containerVolumeMount(nextcloudHtmlDir, "/var/www/html"),
                kube.containerVolumeMount(nextcloudCustomAppsDir, "/var/www/html/custom_apps"),
                kube.containerVolumeMount(nextcloudConfigDir, "/var/www/html/config"),
                kube.containerVolumeMount(nextcloudDataDir, "/var/www/html/data"),
            ],
            resources = kube.resources("125m", "128Mi", "250m", "256Mi"),
        ),
        initContainers = (
            if configuration.useMariadb then [
                kube.deploymentContainer(
                    "init-mariadb",
                    "mariadb",
                    configuration.mariadb.imageTag,
                    command = [
                        "sh",
                        "-c",
                        "until mysql -h %(service)s -u $MYSQL_USER --password=$MYSQL_PASSWORD -e 'SELECT 1'; do echo waiting for %(service)s; sleep 2; done;" % {service: mariadbService.metadata.name},
                    ],
                    env = [
                        kube.containerEnvFromSecret("MYSQL_USER", secret.metadata.name, "MYSQL_USER"),
                        kube.containerEnvFromSecret("MYSQL_PASSWORD", secret.metadata.name, "MYSQL_PASSWORD"),
                    ],
                    ports = [
                        kube.containerPort(3306),
                    ],
                    volumeMounts = (
                        if configuration.persistentData then [
                            kube.containerVolumeMount(mariadbDataDir, "/var/lib/mysql"),
                        ] else []
                    ),
                ),
            ] else []
        ) + (
            if configuration.useRedis then [
                kube.deploymentContainer(
                    "init-redis",
                    "redis",
                    configuration.redis.imageTag,
                    command = [
                        "sh",
                        "-c",
                        "until redis-cli -h %(service)s -p 6379 ping; do echo waiting for %(service)s; sleep 2; done;" % {service: redisService.metadata.name},
                    ],
                ),
            ] else []
        ),
    ),

    // Nextcloud Service
    local nextcloudService = kube.service(
        namespace,
        name + "-" + nextcloudComponentName,
        labels + {component: nextcloudComponentName},
        nextcloudDeployment.metadata.labels,
        [
            kube.servicePort("TCP", 80, 80),
        ],
    ),

    // Nextcloud Certificate
    local nextcloudCertificate = kube.certificate(
        namespace,
        name + "-" + nextcloudComponentName,
        labels + {component: nextcloudComponentName},
        "%(domain)s-tls" % {domain: std.strReplace(configuration.nextcloud.domain, ".", "-")},
        configuration.nextcloud.domain,
        {metadata: configuration.certificateIssuer},
    ),

    // Nextcloud Ingress
    local nextcloudIngress = kube.ingress(
        namespace,
        name + "-" + nextcloudComponentName,
        labels + {component: nextcloudComponentName},
        "%(domain)s-tls" % {domain: std.strReplace(configuration.nextcloud.domain, ".", "-")},
        configuration.nextcloud.domain,
        nextcloudService.metadata.name,
        80,
    ),

    apiVersion: "v1",
    kind: "List",
    items: [
        secret,
        nextcloudNginxConfigMap,
        nextcloudDeployment,
        nextcloudService,
        nextcloudCertificate,
        nextcloudIngress,
    ] + (
        if configuration.persistentData then [
            nextcloudPersistentVolumes[x] for x in std.objectFields(nextcloudPersistentVolumes)
        ] + [
            nextcloudPersistentVolumeClaims[x] for x in std.objectFields(nextcloudPersistentVolumeClaims)  
        ] + [
            nextcloudCronJob,
        ] else []
    ) + (
        if configuration.useMariadb then [
            mariadbDeployment,
            mariadbService,
        ] + (
          if configuration.persistentData then [
              mariadbPersistentVolumes[x] for x in std.objectFields(mariadbPersistentVolumes)
          ] + [
              mariadbPersistentVolumeClaims[x] for x in std.objectFields(mariadbPersistentVolumeClaims)  
          ] else []
        ) else []
    ) + (
        if configuration.useRedis then [
            redisDeployment,
            redisService,
        ] + (
          if configuration.persistentData then [
              redisPersistentVolumes[x] for x in std.objectFields(redisPersistentVolumes)
          ] + [
              redisPersistentVolumeClaims[x] for x in std.objectFields(redisPersistentVolumeClaims)  
          ] else []
        ) else []
    ) + (
        if configuration.useOnlyoffice then [
            onlyofficeDeployment,
            onlyofficeService,
            onlyofficeCertificate,
            onlyofficeIngress,
        ] else []
    ),
};

{
    newInstance:: newInstance,
}