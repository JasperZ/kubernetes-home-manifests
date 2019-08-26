local kube = import "../templates/kubernetes.libsonnet";

local configuration = {
    kube:: {
        imageTag:: error "kube.imageTag is required",
        resources:: {
            requests:: {
                cpu:: "50m",
                memory:: "32Mi",
            },
            limits:: {
                cpu:: "100m",
                memory:: "64Mi",
            },
        },
    },
    app:: {
        tradingSymbols:: error "app.tradingSymbols is required",
    },
};

local new(namespace, namePrefix, labels, influxdbComponent, config) = {
    local componentName = "bitfinex-crawler",

    local deployment = kube.deployment(
        namespace,
        namePrefix + "-" + componentName,
        labels + {component: componentName},
        [
            kube.deploymentContainer(
                componentName,
                "zdock/bitfinex-crawler",
                config.kube.imageTag,
                env = [
                    kube.containerEnvFromValue("TICKER_SYMBOLS", config.app.tradingSymbols),
                    kube.containerEnvFromValue("INFLUXDB_HOST", influxdbComponent.service.metadata.name),
                    kube.containerEnvFromSecret("INFLUXDB_DATABASE", influxdbComponent.secret.metadata.name, "INFLUXDB_DB"),
                    kube.containerEnvFromSecret("INFLUXDB_USERNAME", influxdbComponent.secret.metadata.name, "INFLUXDB_WRITE_USER"),
                    kube.containerEnvFromSecret("INFLUXDB_PASSWORD", influxdbComponent.secret.metadata.name, "INFLUXDB_WRITE_USER_PASSWORD"),
                ],
                resources = kube.resources(
                    config.kube.resources.requests.cpu,
                    config.kube.resources.requests.memory,
                    config.kube.resources.limits.cpu,
                    config.kube.resources.limits.memory,
                ),
            ),
        ],
        initContainers = [
            influxdbComponent.initContainer,
        ],
    ),

    deployment: deployment,
};

{
    configuration:: configuration,
    new:: new,
}