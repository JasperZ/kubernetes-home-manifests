local kube = import "../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
        resources:: {
            requests:: {
                cpu:: "250m",
                memory:: "128Mi",
            },
            limits:: {
                cpu:: "500m",
                memory:: "512Mi",
            },
        },
    },
    app:: {
        adminUser:: error "app.adminUser is required",
        adminUserPassword:: error "app.adminUserPassword is required",
        writeUser:: error "app.writeUser is required",
        writeUserPassword:: error "app.writeUserPassword is required",
        readUser:: error "app.readUser is required",
        readUserPassword:: error "app.readUserPassword is required",
        database:: error "app.database is required",
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
    local componentName = "influxdb",
    local dataDir = "data",

    local secret = kube.secret(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        stringData = {
            INFLUXDB_DB: config.app.database,
            INFLUXDB_ADMIN_USER: config.app.adminUser,
            INFLUXDB_ADMIN_PASSWORD: config.app.adminUserPassword,
            INFLUXDB_WRITE_USER: config.app.writeUser,
            INFLUXDB_WRITE_USER_PASSWORD: config.app.writeUserPassword,
            INFLUXDB_READ_USER: config.app.readUser,
            INFLUXDB_READ_USER_PASSWORD: config.app.readUserPassword,
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
                "influxdb",
                config.kube.imageTag,
                env = [
                    kube.containerEnvFromValue("INFLUXDB_HTTP_AUTH_ENABLED", "true"),
                    kube.containerEnvFromSecret("INFLUXDB_DB", secret.metadata.name, "INFLUXDB_DB"),
                    kube.containerEnvFromSecret("INFLUXDB_ADMIN_USER", secret.metadata.name, "INFLUXDB_ADMIN_USER"),
                    kube.containerEnvFromSecret("INFLUXDB_ADMIN_PASSWORD", secret.metadata.name, "INFLUXDB_ADMIN_PASSWORD"),
                    kube.containerEnvFromSecret("INFLUXDB_WRITE_USER", secret.metadata.name, "INFLUXDB_WRITE_USER"),
                    kube.containerEnvFromSecret("INFLUXDB_WRITE_USER_PASSWORD", secret.metadata.name, "INFLUXDB_WRITE_USER_PASSWORD"),
                    kube.containerEnvFromSecret("INFLUXDB_READ_USER", secret.metadata.name, "INFLUXDB_READ_USER"),
                    kube.containerEnvFromSecret("INFLUXDB_READ_USER_PASSWORD", secret.metadata.name, "INFLUXDB_READ_USER_PASSWORD"),
                ],
                ports = [
                    kube.containerPort(8086),
                ],
                volumeMounts = (
                    if config.data.persist then [
                        kube.containerVolumeMount(dataDir, "/var/lib/influxdb"),
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
            kube.servicePort("http", "TCP", 8086, 8086),
        ],
    ),

    local initContainer = kube.deploymentContainer(
        "init-influxdb",
        "appropriate/curl",
        "latest",
        command = [
            "sh",
            "-c",
            "until curl -sL -I %(service)s:%(port)s/ping; do echo waiting for %(service)s; sleep 2; done;" % {
                service: service.metadata.name,
                port: 8086,
            },
        ],
    ),

    secret: secret,
    persistentVolumes: persistentVolumes,
    persistentVolumeClaims: persistentVolumeClaims,
    service: service,
    deployment: deployment,
    initContainer: initContainer,
};

{
    configuration:: configuration,
    new:: new,
}