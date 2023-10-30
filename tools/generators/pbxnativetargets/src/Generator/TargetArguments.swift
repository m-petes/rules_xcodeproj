import ArgumentParser
import Foundation
import PBXProj
import ToolCommon

struct TargetArguments: Equatable {
    let xcodeConfigurations: [String]
    let productType: PBXProductType
    let packageBinDir: String

    /// e.g. "generator" or "App"
    let productName: String

    /// e.g. "generator_codesigned" or "App.app"
    let productBasename: String

    let moduleName: String

    let platform: Platform
    let osVersion: SemanticVersion
    let arch: String

    let buildSettingsFromFile: [PlatformVariantBuildSetting]
    let hasCParams: Bool
    let hasCxxParams: Bool

    // FIXME: Extract to `Inputs` type
    let srcs: [BazelPath]
    let nonArcSrcs: [BazelPath]
    let resources: [BazelPath]
    let folderResources: [BazelPath]

    let dSYMPathsBuildSetting: String
}

extension Dictionary<TargetID, TargetArguments> {
    static func parse(from url: URL) async throws -> Self {
        var rawArgs = ArraySlice(try await url.allLines.collect())

        let targetCount = try rawArgs.consumeArg(Int.self, in: url)

        var keysWithValues: [(TargetID, TargetArguments)] = []
        for _ in (0..<targetCount) {
            let id = try rawArgs.consumeArg(TargetID.self, in: url)
            let productType =
                try rawArgs.consumeArg(PBXProductType.self, in: url)
            let packageBinDir = try rawArgs.consumeArg(String.self, in: url)
            let productName = try rawArgs.consumeArg(String.self, in: url)
            let productBasename = try rawArgs.consumeArg(String.self, in: url)
            let moduleName = try rawArgs.consumeArg(String.self, in: url)
            let platform = try rawArgs.consumeArg(Platform.self, in: url)
            let osVersion =
                try rawArgs.consumeArg(SemanticVersion.self, in: url)
            let arch = try rawArgs.consumeArg(String.self, in: url)
            let dSYMPathsBuildSetting =
                try rawArgs.consumeArg(String.self, in: url)
            let buildSettingsFile = try rawArgs.consumeArg(
                URL?.self,
                in: url,
                transform: { path in
                    guard !path.isEmpty else {
                        return nil
                    }
                    return URL(fileURLWithPath: path, isDirectory: false)
                }
            )
            let hasCParams = try rawArgs.consumeArg(Bool.self, in: url)
            let hasCxxParams = try rawArgs.consumeArg(Bool.self, in: url)
            let srcs = try rawArgs.consumeArgs(BazelPath.self, in: url)
            let nonArcSrcs = try rawArgs.consumeArgs(BazelPath.self, in: url)
            let resources = try rawArgs.consumeArgs(BazelPath.self, in: url)
            let folderResources =
                try rawArgs.consumeArgs(BazelPath.self, in: url)
            let xcodeConfigurations =
                try rawArgs.consumeArgs(String.self, in: url)

            var buildSettings: [PlatformVariantBuildSetting] = []
            if let buildSettingsFile {
                // FIXME: Wrap in better precondition error that mentions url
                for try await line in buildSettingsFile.lines {
                    let components = line.split(separator: "\t", maxSplits: 1)
                    guard components.count == 2 else {
                        throw PreconditionError(message: """
"\(buildSettingsFile.path)": Invalid format, missing tab separator.
""")
                    }
                    buildSettings.append(
                        .init(
                            key: String(components[0]),
                            value: components[1].nullsToNewlines
                        )
                    )
                }
            }

            keysWithValues.append(
                (
                    id,
                    .init(
                        xcodeConfigurations: xcodeConfigurations,
                        productType: productType,
                        packageBinDir: packageBinDir,
                        productName: productName,
                        productBasename: productBasename,
                        moduleName: moduleName,
                        platform: platform,
                        osVersion: osVersion,
                        arch: arch,
                        buildSettingsFromFile: buildSettings,
                        hasCParams: hasCParams,
                        hasCxxParams: hasCxxParams,
                        srcs: srcs,
                        nonArcSrcs: nonArcSrcs,
                        resources: resources,
                        folderResources: folderResources,
                        dSYMPathsBuildSetting: dSYMPathsBuildSetting
                    )
                )
            )
        }

        return Dictionary(uniqueKeysWithValues: keysWithValues)
    }
}

private extension Substring {
    var nullsToNewlines: String {
        replacingOccurrences(of: "\0", with: "\n")
    }
}
