local kube = import "../../../templates/kubernetes.libsonnet";

local new(conf) = {
    local namespace = conf.kube.namespace,
    local name = conf.kube.name,
    local labels = conf.kube.labels,

    // Secret used by all components
    local secret = kube.secret(
        namespace, 
        name,
        labels,
        stringData = {
            NEXTCLOUD_ADMIN_USER: conf.app.nextcloud.adminUser,
            NEXTCLOUD_ADMIN_PASSWORD: conf.app.nextcloud.adminPassword,
        } + (
            if conf.app.mariadb.use then {
                MYSQL_ROOT_PASSWORD: conf.app.mariadb.rootPassword,
                MYSQL_DATABASE: conf.app.mariadb.nextcloudDatabase,
                MYSQL_USER: conf.app.mariadb.nextcloudUser,
                MYSQL_PASSWORD: conf.app.mariadb.nextcloudUserPassword,
            } else {}
        ) + (
            if conf.app.onlyoffice.use then {
                JWT_SECRET: conf.app.onlyoffice.jwtSecret,
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
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + mariadbComponentName + "/" + mariadbDataDir,
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
                conf.app.mariadb.imageTag,
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
                    if conf.app.persistentData.use then [
                        kube.containerVolumeMount(mariadbDataDir, "/var/lib/mysql"),
                    ] else []
                ),
                resources = kube.resources("125m", "128Mi", "500m", "512Mi"),
            ),
        ],
        volumes = (
            if conf.app.persistentData.use then [
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
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + redisComponentName + "/" + redisDataDir,
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
                conf.app.redis.imageTag,
                ports = [
                    kube.containerPort(6379),
                ],
                volumeMounts = (
                    if conf.app.persistentData.use then [
                        kube.containerVolumeMount(redisDataDir, "/data"),
                    ] else []
                ),
                resources = kube.resources("125m", "128Mi", "250m", "256Mi"),
            ),
        ],
        volumes = (
            if conf.app.persistentData.use then [
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
                conf.app.onlyoffice.imageTag,
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
            if conf.app.persistentData.use then [
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
        "%(domain)s-tls" % {domain: std.strReplace(conf.app.onlyoffice.domain, ".", "-")},
        conf.app.onlyoffice.domain,
        {metadata: conf.kube.certificateIssuer},
    ),

    // Onlyoffice Ingress
    local onlyofficeIngress = kube.ingress(
        namespace,
        name + "-" + onlyofficeComponentName,
        labels + {component: onlyofficeComponentName},
        "%(domain)s-tls" % {domain: std.strReplace(conf.app.onlyoffice.domain, ".", "-")},
        conf.app.onlyoffice.domain,
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
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + nextcloudComponentName + "/" + nextcloudHtmlDir,
        ),
        customApps: kube.persistentVolume(
            name + "-" + nextcloudComponentName + "-" + nextcloudCustomAppsDir,
            labels + {component: nextcloudComponentName},
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + nextcloudComponentName + "/" + nextcloudCustomAppsDir,
        ),
        config: kube.persistentVolume(
            name + "-" + nextcloudComponentName + "-" + nextcloudConfigDir,
            labels + {component: nextcloudComponentName},
            conf.app.persistentData.expensive.nfsServer,
            conf.app.persistentData.expensive.nfsRootPath + "/" + nextcloudComponentName + "/" + nextcloudConfigDir,
        ),
        data: kube.persistentVolume(
            name + "-" + nextcloudComponentName + "-" + nextcloudDataDir,
            labels + {component: nextcloudComponentName},
            conf.app.persistentData.cheap.nfsServer,
            conf.app.persistentData.cheap.nfsRootPath + "/" + nextcloudComponentName + "/" + nextcloudDataDir,
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
                conf.app.nextcloud.imageTag,
                env = [
                    kube.containerEnvFromSecret("NEXTCLOUD_ADMIN_USER", secret.metadata.name, "NEXTCLOUD_ADMIN_USER"),
                    kube.containerEnvFromSecret("NEXTCLOUD_ADMIN_PASSWORD", secret.metadata.name, "NEXTCLOUD_ADMIN_PASSWORD"),
                    kube.containerEnvFromValue("NEXTCLOUD_TRUSTED_DOMAINS", conf.app.nextcloud.domain),
                ] + (
                    if conf.app.mariadb.use then [
                        kube.containerEnvFromSecret("MYSQL_USER", secret.metadata.name, "MYSQL_USER"),
                        kube.containerEnvFromSecret("MYSQL_PASSWORD", secret.metadata.name, "MYSQL_PASSWORD"),
                        kube.containerEnvFromSecret("MYSQL_DATABASE", secret.metadata.name, "MYSQL_DATABASE"),
                        kube.containerEnvFromValue("MYSQL_HOST", mariadbService.metadata.name),
                    ] else [
                        kube.containerEnvFromValue("SQLITE_DATABASE", "nextcloud"),
                    ]
                ) + (
                    if conf.app.redis.use then [
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
                conf.app.nextcloud.nginx.imageTag,
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
            if conf.app.mariadb.use then [
                kube.deploymentContainer(
                    "init-mariadb",
                    "mariadb",
                    conf.app.mariadb.imageTag,
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
                        if conf.app.persistentData.use then [
                            kube.containerVolumeMount(mariadbDataDir, "/var/lib/mysql"),
                        ] else []
                    ),
                ),
            ] else []
        ) + (
            if conf.app.redis.use then [
                kube.deploymentContainer(
                    "init-redis",
                    "redis",
                    conf.app.redis.imageTag,
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
            if conf.app.persistentData.use then [
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
            conf.app.nextcloud.imageTag,
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
            if conf.app.mariadb.use then [
                kube.deploymentContainer(
                    "init-mariadb",
                    "mariadb",
                    conf.app.mariadb.imageTag,
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
                        if conf.app.persistentData.use then [
                            kube.containerVolumeMount(mariadbDataDir, "/var/lib/mysql"),
                        ] else []
                    ),
                ),
            ] else []
        ) + (
            if conf.app.redis.use then [
                kube.deploymentContainer(
                    "init-redis",
                    "redis",
                    conf.app.redis.imageTag,
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
        "%(domain)s-tls" % {domain: std.strReplace(conf.app.nextcloud.domain, ".", "-")},
        conf.app.nextcloud.domain,
        {metadata: conf.kube.certificateIssuer},
    ),

    // Nextcloud Ingress
    local nextcloudIngress = kube.ingress(
        namespace,
        name + "-" + nextcloudComponentName,
        labels + {component: nextcloudComponentName},
        "%(domain)s-tls" % {domain: std.strReplace(conf.app.nextcloud.domain, ".", "-")},
        conf.app.nextcloud.domain,
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
        if conf.app.persistentData.use then [
            nextcloudPersistentVolumes[x] for x in std.objectFields(nextcloudPersistentVolumes)
        ] + [
            nextcloudPersistentVolumeClaims[x] for x in std.objectFields(nextcloudPersistentVolumeClaims)  
        ] + [
            nextcloudCronJob,
        ] else []
    ) + (
        if conf.app.mariadb.use then [
            mariadbDeployment,
            mariadbService,
        ] + (
            if conf.app.persistentData.use then [
                mariadbPersistentVolumes[x] for x in std.objectFields(mariadbPersistentVolumes)
            ] + [
                mariadbPersistentVolumeClaims[x] for x in std.objectFields(mariadbPersistentVolumeClaims)  
            ] else []
        ) else []
    ) + (
        if conf.app.redis.use then [
            redisDeployment,
            redisService,
        ] + (
            if conf.app.persistentData.use then [
                redisPersistentVolumes[x] for x in std.objectFields(redisPersistentVolumes)
            ] + [
                redisPersistentVolumeClaims[x] for x in std.objectFields(redisPersistentVolumeClaims)  
            ] else []
        ) else []
    ) + (
        if conf.app.onlyoffice.use then [
            onlyofficeDeployment,
            onlyofficeService,
            onlyofficeCertificate,
            onlyofficeIngress,
        ] else []
    ),
};

{
    new:: new,
}