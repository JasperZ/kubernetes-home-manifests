local kube = import "../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
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
    app:: {
        rootPassword:: error "app.rootPassword is required",
        user:: error "app.user is required",
        userPassword:: error "app.userPassword is required",
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
    local componentName = "mariadb",
    local dataDir = "data",

    local secret = kube.secret(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        stringData = {
            MYSQL_ROOT_PASSWORD: config.app.rootPassword,
            MYSQL_USER: config.app.user,
            MYSQL_PASSWORD: config.app.userPassword,
            MYSQL_DATABASE: config.app.database,
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
                "mariadb",
                config.kube.imageTag,
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
                    if config.data.persist then [
                        kube.containerVolumeMount(dataDir, "/var/lib/mysql"),
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
            kube.servicePort("mysql", "TCP", 3306, 3306),
        ],
    ),

    local initContainer = kube.deploymentContainer(
        "init-mariadb",
        "mariadb",
        config.kube.imageTag,
        command = [
            "sh",
            "-c",
            "until mysql -h %(service)s -u $MYSQL_USER --password=$MYSQL_PASSWORD -e 'SELECT 1'; do echo waiting for %(service)s; sleep 2; done;" % {service: service.metadata.name},
        ],
        env = [
            kube.containerEnvFromSecret("MYSQL_USER", secret.metadata.name, "MYSQL_USER"),
            kube.containerEnvFromSecret("MYSQL_PASSWORD", secret.metadata.name, "MYSQL_PASSWORD"),
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