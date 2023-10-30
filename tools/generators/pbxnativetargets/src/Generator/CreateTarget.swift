import OrderedCollections
import PBXProj

extension Generator {
    struct CreateTarget {
        private let calculatePlatformVariantBuildSettings:
            CalculatePlatformVariantBuildSettings
        private let calculateSharedBuildSettings: CalculateSharedBuildSettings
        private let calculateXcodeConfigurationBuildSettings:
            CalculateXcodeConfigurationBuildSettings
        private let createBazelIntegrationBuildPhaseObject:
            CreateBazelIntegrationBuildPhaseObject
        private let createBuildConfigurationListObject:
            CreateBuildConfigurationListObject
        private let createBuildConfigurationObject:
            CreateBuildConfigurationObject
        private let createBuildFileSubIdentifier: CreateBuildFileSubIdentifier
        private let createBuildSettingsAttribute: CreateBuildSettingsAttribute
        private let createCreateCompileDependenciesBuildPhaseObject:
            CreateCreateCompileDependenciesBuildPhaseObject
        private let createCreateLinkDependenciesBuildPhaseObject:
            CreateCreateLinkDependenciesBuildPhaseObject
        private let createEmbedAppExtensionsBuildPhaseObject:
            CreateEmbedAppExtensionsBuildPhaseObject
        private let createProductBuildFileObject: CreateProductBuildFileObject
        private let createProductObject: CreateProductObject
        private let createSourcesBuildPhaseObject: CreateSourcesBuildPhaseObject
        private let createTargetObject: CreateTargetObject

        private let callable: Callable

        /// - Parameters:
        ///   - callable: The function that will be called in
        ///     `callAsFunction()`.
        init(
            calculatePlatformVariantBuildSettings:
                CalculatePlatformVariantBuildSettings,
            calculateSharedBuildSettings: CalculateSharedBuildSettings,
            calculateXcodeConfigurationBuildSettings:
                CalculateXcodeConfigurationBuildSettings,
            createBazelIntegrationBuildPhaseObject:
                CreateBazelIntegrationBuildPhaseObject,
            createBuildConfigurationListObject:
                CreateBuildConfigurationListObject,
            createBuildConfigurationObject: CreateBuildConfigurationObject,
            createBuildFileSubIdentifier: CreateBuildFileSubIdentifier,
            createBuildSettingsAttribute: CreateBuildSettingsAttribute,
            createCreateCompileDependenciesBuildPhaseObject:
                CreateCreateCompileDependenciesBuildPhaseObject,
            createCreateLinkDependenciesBuildPhaseObject:
                CreateCreateLinkDependenciesBuildPhaseObject,
            createEmbedAppExtensionsBuildPhaseObject:
                CreateEmbedAppExtensionsBuildPhaseObject,
            createProductBuildFileObject: CreateProductBuildFileObject,
            createProductObject: CreateProductObject,
            createSourcesBuildPhaseObject: CreateSourcesBuildPhaseObject,
            createTargetObject: CreateTargetObject,
            callable: @escaping Callable = Self.defaultCallable
        ) {
            self.calculatePlatformVariantBuildSettings =
                calculatePlatformVariantBuildSettings
            self.calculateSharedBuildSettings = calculateSharedBuildSettings
            self.calculateXcodeConfigurationBuildSettings =
                calculateXcodeConfigurationBuildSettings
            self.createBazelIntegrationBuildPhaseObject =
                createBazelIntegrationBuildPhaseObject
            self.createBuildConfigurationListObject =
                createBuildConfigurationListObject
            self.createBuildConfigurationObject = createBuildConfigurationObject
            self.createBuildFileSubIdentifier = createBuildFileSubIdentifier
            self.createBuildSettingsAttribute = createBuildSettingsAttribute
            self.createCreateCompileDependenciesBuildPhaseObject =
                createCreateCompileDependenciesBuildPhaseObject
            self.createCreateLinkDependenciesBuildPhaseObject =
                createCreateLinkDependenciesBuildPhaseObject
            self.createEmbedAppExtensionsBuildPhaseObject =
                createEmbedAppExtensionsBuildPhaseObject
            self.createProductBuildFileObject = createProductBuildFileObject
            self.createProductObject = createProductObject
            self.createSourcesBuildPhaseObject = createSourcesBuildPhaseObject
            self.createTargetObject = createTargetObject

            self.callable = callable
        }

        /// Creates a target and all of its related elements.
        func callAsFunction(
            consolidationMapEntry entry: ConsolidationMapEntry,
            defaultXcodeConfiguration: String,
            shard: UInt8,
            targetArguments: [TargetID: TargetArguments],
            topLevelTargetAttributes: [TargetID: TopLevelTargetAttributes],
            unitTestHosts: [TargetID: Target.UnitTestHost],
            xcodeConfigurations: Set<String>
        ) async throws -> (
            buildFileSubIdentifiers: [Identifiers.BuildFiles.SubIdentifier],
            objects: [Object]
        ) {
            return try await callable(
                /*consolidationMapEntry:*/ entry,
                /*defaultXcodeConfiguration:*/ defaultXcodeConfiguration,
                /*shard:*/ shard,
                /*targetArguments:*/ targetArguments,
                /*topLevelTargetAttributes:*/ topLevelTargetAttributes,
                /*unitTestHosts:*/ unitTestHosts,
                /*xcodeConfigurations:*/ xcodeConfigurations,
                /*calculatePlatformVariantBuildSettings:*/
                    calculatePlatformVariantBuildSettings,
                /*calculateSharedBuildSettings:*/ calculateSharedBuildSettings,
                /*calculateXcodeConfigurationBuildSettings:*/
                    calculateXcodeConfigurationBuildSettings,
                /*createBazelIntegrationBuildPhaseObject:*/
                    createBazelIntegrationBuildPhaseObject,
                /*createBuildConfigurationListObject:*/
                    createBuildConfigurationListObject,
                /*createBuildConfigurationObject:*/
                    createBuildConfigurationObject,
                /*createBuildFileSubIdentifier:*/ createBuildFileSubIdentifier,
                /*createBuildSettingsAttribute:*/ createBuildSettingsAttribute,
                /*createCreateCompileDependenciesBuildPhaseObject:*/
                    createCreateCompileDependenciesBuildPhaseObject,
                /*createCreateLinkDependenciesBuildPhaseObject:*/
                    createCreateLinkDependenciesBuildPhaseObject,
                /*createEmbedAppExtensionsBuildPhaseObject:*/
                    createEmbedAppExtensionsBuildPhaseObject,
                /*createProductBuildFileObject:*/ createProductBuildFileObject,
                /*createProductObject:*/ createProductObject,
                /*createSourcesBuildPhaseObject:*/
                    createSourcesBuildPhaseObject,
                /*createTargetObject:*/ createTargetObject
            )
        }
    }
}

// MARK: - CreateTarget.Callable

extension Generator.CreateTarget {
    typealias Callable = (
        _ consolidationMapEntry: ConsolidationMapEntry,
        _ defaultXcodeConfiguration: String,
        _ shard: UInt8,
        _ targetArguments: [TargetID: TargetArguments],
        _ topLevelTargetAttributes: [TargetID: TopLevelTargetAttributes],
        _ unitTestHosts: [TargetID: Target.UnitTestHost],
        _ xcodeConfigurations: Set<String>,
        _ calculatePlatformVariantBuildSettings:
            Generator.CalculatePlatformVariantBuildSettings,
        _ calculateSharedBuildSettings: Generator.CalculateSharedBuildSettings,
        _ calculateXcodeConfigurationBuildSettings:
            Generator.CalculateXcodeConfigurationBuildSettings,
        _ createBazelIntegrationBuildPhaseObject:
            Generator.CreateBazelIntegrationBuildPhaseObject,
        _ createBuildConfigurationListObject:
            Generator.CreateBuildConfigurationListObject,
        _ createBuildConfigurationObject:
            Generator.CreateBuildConfigurationObject,
        _ createBuildFileSubIdentifier: Generator.CreateBuildFileSubIdentifier,
        _ createBuildSettingsAttribute: CreateBuildSettingsAttribute,
        _ createCreateCompileDependenciesBuildPhaseObject:
            Generator.CreateCreateCompileDependenciesBuildPhaseObject,
        _ createCreateLinkDependenciesBuildPhaseObject:
            Generator.CreateCreateLinkDependenciesBuildPhaseObject,
        _ createEmbedAppExtensionsBuildPhaseObject:
            Generator.CreateEmbedAppExtensionsBuildPhaseObject,
        _ createProductBuildFileObject: Generator.CreateProductBuildFileObject,
        _ createProductObject: Generator.CreateProductObject,
        _ createSourcesBuildPhaseObject:
            Generator.CreateSourcesBuildPhaseObject,
        _ createTargetObject: Generator.CreateTargetObject
    ) async throws -> (
        buildFileSubIdentifiers: [Identifiers.BuildFiles.SubIdentifier],
        objects: [Object]
    )

    static func defaultCallable(
        consolidationMapEntry entry: ConsolidationMapEntry,
        defaultXcodeConfiguration: String,
        shard: UInt8,
        targetArguments: [TargetID: TargetArguments],
        topLevelTargetAttributes: [TargetID: TopLevelTargetAttributes],
        unitTestHosts: [TargetID: Target.UnitTestHost],
        xcodeConfigurations: Set<String>,
        calculatePlatformVariantBuildSettings:
            Generator.CalculatePlatformVariantBuildSettings,
        calculateSharedBuildSettings: Generator.CalculateSharedBuildSettings,
        calculateXcodeConfigurationBuildSettings:
            Generator.CalculateXcodeConfigurationBuildSettings,
        createBazelIntegrationBuildPhaseObject:
            Generator.CreateBazelIntegrationBuildPhaseObject,
        createBuildConfigurationListObject:
            Generator.CreateBuildConfigurationListObject,
        createBuildConfigurationObject:
            Generator.CreateBuildConfigurationObject,
        createBuildFileSubIdentifier: Generator.CreateBuildFileSubIdentifier,
        createBuildSettingsAttribute: CreateBuildSettingsAttribute,
        createCreateCompileDependenciesBuildPhaseObject:
            Generator.CreateCreateCompileDependenciesBuildPhaseObject,
        createCreateLinkDependenciesBuildPhaseObject:
            Generator.CreateCreateLinkDependenciesBuildPhaseObject,
        createEmbedAppExtensionsBuildPhaseObject:
            Generator.CreateEmbedAppExtensionsBuildPhaseObject,
        createProductBuildFileObject: Generator.CreateProductBuildFileObject,
        createProductObject: Generator.CreateProductObject,
        createSourcesBuildPhaseObject: Generator.CreateSourcesBuildPhaseObject,
        createTargetObject: Generator.CreateTargetObject
    ) async throws -> (
        buildFileSubIdentifiers: [Identifiers.BuildFiles.SubIdentifier],
        objects: [Object]
    ) {
        var buildFileSubIdentifiers: [Identifiers.BuildFiles.SubIdentifier] = []
        var objects: [Object] = []

        let key = entry.key

        var srcs: [[BazelPath]] = []
        var nonArcSrcs: [[BazelPath]] = []
        var excludableFilesKeysWithValues: [(TargetID, Set<BazelPath>)] = []
        for id in key.sortedIds {
            let targetArguments = try targetArguments.value(
                for: id,
                context: "Target ID"
            )

            srcs.append(targetArguments.srcs)
            nonArcSrcs.append(targetArguments.nonArcSrcs)

            excludableFilesKeysWithValues.append(
                (
                    id,
                    Set(
                        targetArguments.srcs +
                        targetArguments.nonArcSrcs
                    )
                )
            )
        }

        // For each platform variant, collect all files that can be excluded
        // with `EXCLUDED_SOURCE_FILE_NAMES`
        let excludableFiles = Dictionary(
            uniqueKeysWithValues: excludableFilesKeysWithValues
        )

        // Calculate the set of files that are the same for every platform
        // variant in the consolidated target
        let baselineFiles = excludableFiles.values.reduce(
            into: excludableFiles.first!.value
        ) { baselineFiles, targetExcludableFiles in
            baselineFiles.formIntersection(targetExcludableFiles)
        }

        var allConditionalFiles: Set<BazelPath> = []
        let platformVariants = key.sortedIds.map { id in
            // We do a check above, so no need to do it again
            let targetArguments = targetArguments[id]!

            // For each platform variant calculate the set of files that are
            // "conditional", or not in the baseline files
            let conditionalFiles = excludableFiles[id]!
                .subtracting(baselineFiles)

            allConditionalFiles.formUnion(conditionalFiles)

            let topLevelTargetAttributes = topLevelTargetAttributes[id]

            return Target.PlatformVariant(
                xcodeConfigurations: targetArguments.xcodeConfigurations,
                id: id,
                bundleID: topLevelTargetAttributes?.bundleID,
                compileTargetIDs:
                    topLevelTargetAttributes?.compileTargetIDs,
                packageBinDir: targetArguments.packageBinDir,
                outputsProductPath:
                    topLevelTargetAttributes?.outputsProductPath,
                productName: targetArguments.productName,
                productBasename: targetArguments.productBasename,
                moduleName: targetArguments.moduleName,
                platform: targetArguments.platform,
                osVersion: targetArguments.osVersion,
                arch: targetArguments.arch,
                executableName: topLevelTargetAttributes?.executableName,
                conditionalFiles: conditionalFiles,
                buildSettingsFromFile: targetArguments.buildSettingsFromFile,
                linkParams: topLevelTargetAttributes?.linkParams,
                unitTestHost: topLevelTargetAttributes?.unitTestHost
                    .flatMap { unitTestHosts[$0] },
                dSYMPathsBuildSetting:
                    targetArguments.dSYMPathsBuildSetting.isEmpty ?
                nil : targetArguments.dSYMPathsBuildSetting
            )
        }

        let platforms = OrderedSet(
            platformVariants.map(\.platform).sorted()
        )

        let id = key.sortedIds.first!

        let aTopLevelTargetAttributes = topLevelTargetAttributes[id]
        let aTargetArguments = targetArguments[id]!

        let identifier = Identifiers.Targets.id(
            subIdentifier: entry.subIdentifier,
            name: entry.name
        )
        let productType = aTargetArguments.productType
        let productName = aTargetArguments.productName
        let productPath = entry.productPath
        let consolidatedInputs = Target.ConsolidatedInputs(
            srcs: consolidatePaths(srcs),
            nonArcSrcs: consolidatePaths(nonArcSrcs)
        )
        let hasLinkParams = aTopLevelTargetAttributes?.linkParams != nil

        let productBasename = String(
            productPath.split(separator: "/").last!
        )
        let productSubIdentifier = Identifiers.BuildFiles.productIdentifier(
            targetSubIdentifier: identifier.subIdentifier,
            productBasename: productBasename
        )
        buildFileSubIdentifiers.append(productSubIdentifier)

        var buildPhaseIdentifiers: [String] = []

        if let watchKitExtensionProductIdentifier = entry.watchKitExtensionProductIdentifier {
            // FIXME: Make a version that just takes `watchKitExtensionProductIdentifier`?
            let watchKitExtensionBuildFileSubIdentifier = createBuildFileSubIdentifier(
                watchKitExtensionProductIdentifier.path,
                type: .watchKitExtension,
                shard: shard
            )

            let watchKitExtensionBuildFileObject = createProductBuildFileObject(
                productSubIdentifier: watchKitExtensionProductIdentifier,
                subIdentifier: watchKitExtensionBuildFileSubIdentifier
            )
            objects.append(watchKitExtensionBuildFileObject)

            let appExtensionBuildPhase =
                createEmbedAppExtensionsBuildPhaseObject(
                    subIdentifier: identifier.subIdentifier,
                    buildFileIdentifiers: [
                        watchKitExtensionBuildFileObject.identifier,
                    ]
                )
            buildPhaseIdentifiers.append(appExtensionBuildPhase.identifier)
            objects.append(appExtensionBuildPhase)
        }

        let isResourceBundle = productType == .resourceBundle

        if !isResourceBundle {
            let bazelIntegrationBuildPhase =
                createBazelIntegrationBuildPhaseObject(
                    subIdentifier: identifier.subIdentifier,
                    productType: productType
                )
            buildPhaseIdentifiers
                .append(bazelIntegrationBuildPhase.identifier)
            objects.append(bazelIntegrationBuildPhase)
        }

        if let createCompileDependenciesBuildPhase =
            createCreateCompileDependenciesBuildPhaseObject(
                subIdentifier: identifier.subIdentifier,
                hasCParams: aTargetArguments.hasCParams,
                hasCxxParams: aTargetArguments.hasCxxParams
            )
        {
            buildPhaseIdentifiers
                .append(createCompileDependenciesBuildPhase.identifier)
            objects.append(createCompileDependenciesBuildPhase)
        }

        let hasCompilePhase = productType.hasCompilePhase

        let hasCompileStub = hasCompilePhase &&
        consolidatedInputs.srcs.isEmpty &&
        consolidatedInputs.nonArcSrcs.isEmpty

        if hasLinkParams {
            let createLinkDependenciesBuildPhase =
                createCreateLinkDependenciesBuildPhaseObject(
                    subIdentifier: identifier.subIdentifier,
                    hasCompileStub: hasCompileStub
                )
            buildPhaseIdentifiers
                .append(createLinkDependenciesBuildPhase.identifier)
            objects.append(createLinkDependenciesBuildPhase)
        }

        let srcsSubIdentifiers = consolidatedInputs.srcs.map { path in
            return createBuildFileSubIdentifier(
                path,
                type: .source,
                shard: shard
            )
        }
        buildFileSubIdentifiers.append(contentsOf: srcsSubIdentifiers)

        let nonArcSrcsSubIdentifiers =
        consolidatedInputs.nonArcSrcs.map { path in
            return createBuildFileSubIdentifier(
                path,
                type: .nonArcSource,
                shard: shard
            )
        }
        buildFileSubIdentifiers.append(contentsOf: nonArcSrcsSubIdentifiers)

        if hasCompilePhase {
            let sourcesIdentifiers: [String]
            if hasCompileStub {
                let compileStubSubIdentifier = Identifiers.BuildFiles
                    .compileStubSubIdentifier(
                        targetSubIdentifier: identifier.subIdentifier
                    )
                buildFileSubIdentifiers.append(compileStubSubIdentifier)

                sourcesIdentifiers = [
                    Identifiers.BuildFiles.id(
                        subIdentifier: compileStubSubIdentifier
                    ),
                ]
            } else {
                sourcesIdentifiers = (srcsSubIdentifiers +
                                      nonArcSrcsSubIdentifiers)
                .map { Identifiers.BuildFiles.id(subIdentifier: $0) }
            }

            let sourcesBuildPhase = createSourcesBuildPhaseObject(
                subIdentifier: identifier.subIdentifier,
                buildFileIdentifiers: sourcesIdentifiers
            )
            buildPhaseIdentifiers.append(sourcesBuildPhase.identifier)
            objects.append(sourcesBuildPhase)
        }

        let sharedBuildSettings = calculateSharedBuildSettings(
            name: entry.name,
            label: entry.label,
            productType: productType,
            productName: productName,
            platforms: platforms,
            uiTestHostName: entry.uiTestHostName
        )

        var xcodeConfigurationBuildSettings: [
            String: [PlatformBuildSettings]
        ] = [:]
        for platformVariant in platformVariants {
            let buildSettings =
                try await calculatePlatformVariantBuildSettings(
                    productType: productType,
                    productPath: productPath,
                    platformVariant: platformVariant
                )
            for xcodeConfiguration in platformVariant.xcodeConfigurations {
                xcodeConfigurationBuildSettings[
                    xcodeConfiguration, default: []
                ].append(
                    .init(
                        platform: platformVariant.platform,
                        conditionalFiles: platformVariant.conditionalFiles,
                        buildSettings: buildSettings
                    )
                )
            }
        }

        var xcodeConfigurationAttributes = xcodeConfigurationBuildSettings
            .mapValues { platformBuildSettings in
                let configurationBuildSettings =
                    calculateXcodeConfigurationBuildSettings(
                        platformBuildSettings: platformBuildSettings,
                        allConditionalFiles: allConditionalFiles
                    )

                return createBuildSettingsAttribute(
                    buildSettings:
                        sharedBuildSettings + configurationBuildSettings
                )
            }

        // For any missing configurations, have them equal to the default,
        // and if the default is one of the missing ones, choose the first
        // alphabetically
        let missingConfigurations = xcodeConfigurations.subtracting(
            Set(xcodeConfigurationAttributes.keys)
        )
        if !missingConfigurations.isEmpty {
            let attributes = xcodeConfigurationAttributes[
                missingConfigurations.contains(defaultXcodeConfiguration) ?
                xcodeConfigurationAttributes.keys.sorted().first! :
                    defaultXcodeConfiguration
            ]!
            for xcodeConfiguration in missingConfigurations {
                xcodeConfigurationAttributes[xcodeConfiguration] =
                attributes
            }
        }

        var configurationIndex: UInt8 = 0
        var configurationObjects: [Object] = []
        for (xcodeConfiguration, attribute) in
                xcodeConfigurationAttributes.sorted(by: { $0.key < $1.key })
        {
            configurationObjects.append(
                createBuildConfigurationObject(
                    name: xcodeConfiguration,
                    index: configurationIndex,
                    subIdentifier: identifier.subIdentifier,
                    buildSettings: attribute
                )
            )
            configurationIndex += 1
        }

        objects.append(contentsOf: configurationObjects)

        let configurationList = createBuildConfigurationListObject(
            name: entry.name,
            subIdentifier: identifier.subIdentifier,
            buildConfigurationIdentifiers:
                configurationObjects.map(\.identifier),
            defaultXcodeConfiguration: defaultXcodeConfiguration
        )
        objects.append(configurationList)

        objects.append(
            createProductObject(
                productType: productType,
                productPath: productPath,
                productBasename: productBasename,
                subIdentifier: productSubIdentifier,
                isAssociatedWithTarget:
                    productType.setsProductReference
            )
        )

        objects.append(
            createTargetObject(
                identifier: identifier,
                productType: productType,
                productName: productName,
                productSubIdentifier: productSubIdentifier,
                dependencySubIdentifiers: entry.dependencySubIdentifiers,
                buildConfigurationListIdentifier:
                    configurationList.identifier,
                buildPhaseIdentifiers: buildPhaseIdentifiers
            )
        )

        return (buildFileSubIdentifiers, objects)
    }
}

// FIXME: Extract and test?
private func consolidatePaths(_ paths: [[BazelPath]]) -> [BazelPath] {
    guard !paths.isEmpty else {
        return []
    }

    // First generate the baseline
    var baselinePaths = OrderedSet(paths[0])
    for paths in paths {
        baselinePaths.formIntersection(paths)
    }

    var consolidatedPaths = baselinePaths

    // For each array of `paths`, insert them into `consolidatedPaths`,
    // preserving relative order
    for paths in paths {
        var consolidatedIdx = 0
        var pathsIdx = 0
        while
            consolidatedIdx < consolidatedPaths.count, pathsIdx < paths.count
        {
            let path = paths[pathsIdx]
            pathsIdx += 1

            guard consolidatedPaths[consolidatedIdx] != path else {
                consolidatedIdx += 1
                continue
            }

            if baselinePaths.contains(path) {
                // We need to adjust our index based on where the file exists in
                // the baseline
                let foundIndex = consolidatedPaths.firstIndex(of: path)!
                if foundIndex > consolidatedIdx {
                    consolidatedIdx = foundIndex + 1
                }
                continue
            }

            let (inserted, _) = consolidatedPaths.insert(
                path,
                at: consolidatedIdx
            )
            if inserted {
                consolidatedIdx += 1
            }
        }

        if pathsIdx < paths.count {
            consolidatedPaths.append(contentsOf: paths[pathsIdx...])
        }
    }

    return consolidatedPaths.elements
}

private extension PBXProductType {
    var hasCompilePhase: Bool {
        switch self {
        case .messagesApplication,
             .watch2App,
             .watch2AppContainer,
             .resourceBundle:
            return false
        default:
            return true
        }
    }
}
