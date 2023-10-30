import PBXProj

extension Generator {
    /// Provides the callable dependencies for `Generator`.
    ///
    /// The main purpose of `Environment` is to enable dependency injection,
    /// allowing for different implementations to be used in tests.
    struct Environment {
        let calculatePartial: CalculatePartial

        let createTarget: CreateTarget

        let write: Write

        let writeBuildFileSubIdentifiers: WriteBuildFileSubIdentifiers
    }
}

extension Generator.Environment {
    static let `default` = Self(
        calculatePartial: Generator.CalculatePartial(),
        createTarget: Generator.CreateTarget(
            calculatePlatformVariantBuildSettings:
                Generator.CalculatePlatformVariantBuildSettings(),
            calculateSharedBuildSettings:
                Generator.CalculateSharedBuildSettings(),
            calculateXcodeConfigurationBuildSettings:
                Generator.CalculateXcodeConfigurationBuildSettings(),
            createBazelIntegrationBuildPhaseObject:
                Generator.CreateBazelIntegrationBuildPhaseObject(),
            createBuildConfigurationListObject:
                Generator.CreateBuildConfigurationListObject(),
            createBuildConfigurationObject:
                Generator.CreateBuildConfigurationObject(),
            createBuildFileSubIdentifier:
                Generator.CreateBuildFileSubIdentifier(),
            createBuildSettingsAttribute: CreateBuildSettingsAttribute(),
            createCreateCompileDependenciesBuildPhaseObject:
                Generator.CreateCreateCompileDependenciesBuildPhaseObject(),
            createCreateLinkDependenciesBuildPhaseObject:
                Generator.CreateCreateLinkDependenciesBuildPhaseObject(),
            createEmbedAppExtensionsBuildPhaseObject:
                Generator.CreateEmbedAppExtensionsBuildPhaseObject(),
            createProductBuildFileObject:
                Generator.CreateProductBuildFileObject(),
            createProductObject: Generator.CreateProductObject(),
            createSourcesBuildPhaseObject:
                Generator.CreateSourcesBuildPhaseObject(),
            createTargetObject: Generator.CreateTargetObject()
        ),
        write: Write(),
        writeBuildFileSubIdentifiers: Generator.WriteBuildFileSubIdentifiers()
    )
}
