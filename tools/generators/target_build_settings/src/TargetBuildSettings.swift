import ArgumentParser
import Foundation
import OrderedCollections
import PBXProj
import ToolCommon

@main
struct TargetBuildSettings {
    private static let separator = Data([0x0a]) // Newline
    private static let subSeparator = Data([0x09]) // Tab

    static func main() async {
        guard CommandLine.arguments.count > 1 else {
            let logger = DefaultLogger(
                standardError: StderrOutputStream(),
                standardOutput: StdoutOutputStream(),
                colorize: false
            )
            logger.logError(
                PreconditionError(message: "Missing <colorize>")
                    .localizedDescription
            )
            Darwin.exit(1)
        }
        let colorize = CommandLine.arguments[1] == "1"

        let logger = DefaultLogger(
            standardError: StderrOutputStream(),
            standardOutput: StdoutOutputStream(),
            colorize: colorize
        )

        do {
            let (
                buildSettingsOutputPath,
                buildSettings,
                swiftDebugSettingsOutputPath,
                clangArgs,
                frameworkIncludes,
                swiftIncludes
            ) = try await parseArgs()

            let writeBuildSettingsTask = Task {
                guard let buildSettingsOutputPath else { return }

                var data = Data()

                for (key, value) in buildSettings
                    .sorted(by: { $0.key < $1.key })
                {
                    data.append(Data(key.utf8))
                    data.append(Self.subSeparator)
                    data.append(Data(value.utf8))
                    data.append(Self.separator)
                }

                try data.write(to: buildSettingsOutputPath)
            }

            let writeSwiftDebugSettingsTask = Task {
                guard let swiftDebugSettingsOutputPath else { return }

                var data = Data()

                data.append(Data(String(clangArgs.count).utf8))
                data.append(Self.separator)
                for arg in clangArgs {
                    data.append(Data(arg.utf8))
                    data.append(Self.separator)
                }

                data.append(Data(String(frameworkIncludes.count).utf8))
                data.append(Self.separator)
                for include in frameworkIncludes {
                    data.append(Data(include.utf8))
                    data.append(Self.separator)
                }

                data.append(Data(String(swiftIncludes.count).utf8))
                data.append(Self.separator)
                for include in swiftIncludes {
                    data.append(Data(include.utf8))
                    data.append(Self.separator)
                }

                try data.write(to: swiftDebugSettingsOutputPath)
            }

            try await writeBuildSettingsTask.value
            try await writeSwiftDebugSettingsTask.value
        } catch {
            logger.logError(error.localizedDescription)
            Darwin.exit(1)
        }
    }

    private static func parseArgs() async throws -> (
        buildSettingsOutputPath: URL?,
        buildSettings: [(key: String, value: String)],
        swiftDebugSettingsOutputPath: URL?,
        clangArgs: [String],
        frameworkIncludes: OrderedSet<String>,
        swiftIncludes: OrderedSet<String>
    ) {
        // First 2 arguments are program name and `<colorize>`
        var rawArguments = CommandLine.arguments.dropFirst(2)

        let rawBuildSettingsOutputPath = try rawArguments
            .popArgument("build-settings-output-path")

        let buildSettingsOutputPath: URL?
        if rawBuildSettingsOutputPath.isEmpty {
            buildSettingsOutputPath = nil
        } else {
            buildSettingsOutputPath =
                URL(fileURLWithPath: rawBuildSettingsOutputPath)
        }

        let rawSwiftDebugSettingsOutputPath = try rawArguments
            .popArgument("swift-debug-settings-output-path")

        let includeSelfSwiftDebugSettings: Bool
        let swiftDebugSettingsOutputPath: URL?
        let transitiveSwiftDebugSettingPaths: [URL]
        if rawSwiftDebugSettingsOutputPath.isEmpty {
            swiftDebugSettingsOutputPath = nil
            includeSelfSwiftDebugSettings = false
            transitiveSwiftDebugSettingPaths = []
        } else {
            swiftDebugSettingsOutputPath =
                URL(fileURLWithPath: rawSwiftDebugSettingsOutputPath)

            includeSelfSwiftDebugSettings = try rawArguments
                .popArgument("include-self-swift-debug-settings") == "1"

            var _transitiveSwiftDebugSettingPaths: [URL] = []
            var maybePath = try rawArguments
                .popArgument("transitive-swift-debug-setting-paths")
            while maybePath != argsSeparator {
                _transitiveSwiftDebugSettingPaths.append(
                    URL(fileURLWithPath: maybePath)
                )
                maybePath = try rawArguments
                    .popArgument("transitive-swift-debug-setting-paths")
            }
            transitiveSwiftDebugSettingPaths = _transitiveSwiftDebugSettingPaths
        }

        let (buildSettings, clangArgs, frameworkIncludes, swiftIncludes) =
            try await processArgs(
                rawArguments: rawArguments,
                generateBuildSettings: buildSettingsOutputPath != nil,
                includeSelfSwiftDebugSettings: includeSelfSwiftDebugSettings,
                transitiveSwiftDebugSettingPaths:
                    transitiveSwiftDebugSettingPaths
            )

        return (
            buildSettingsOutputPath,
            buildSettings,
            swiftDebugSettingsOutputPath,
            clangArgs,
            frameworkIncludes,
            swiftIncludes
        )
    }

    private static func processArgs(
        rawArguments: Array<String>.SubSequence,
        generateBuildSettings: Bool,
        includeSelfSwiftDebugSettings: Bool,
        transitiveSwiftDebugSettingPaths: [URL]
    ) async throws -> (
        buildSettings: [(key: String, value: String)],
        clangArgs: [String],
        frameworkIncludes: OrderedSet<String>,
        swiftIncludes: OrderedSet<String>
    ) {
        var rawArguments = rawArguments

        let deviceFamily = try rawArguments.popArgument("device-family")
        let extensionSafe =
            try rawArguments.popArgument("extension-safe") == "1"
        let generatesDsyms =
            try rawArguments.popArgument("generates-dsyms") == "1"
        let infoPlist = try rawArguments.popArgument("info-plist")
        let entitlements = try rawArguments.popArgument("entitlements")
        let skipCodesigning =
            try rawArguments.popArgument("skip-codesigning") == "1"
        let certificateName = try rawArguments.popArgument("certificate-name")
        let provisioningProfileName =
            try rawArguments.popArgument("provisioning-profile-name")
        let teamID = try rawArguments.popArgument("team-id")
        let provisioningProfileIsXcodeManaged = try rawArguments
            .popArgument("provisioning-profile-is-xcode-managed") == "1"
        let previewsFrameworkPaths =
            try rawArguments.popArgument("previews-framework-paths")
        let previewsIncludePath =
            try rawArguments.popArgument("previews-include-path")

        let args = parseArgs(rawArguments: rawArguments)

        var buildSettings: [(key: String, value: String)] = []

        let (
            swiftHasDebugInfo,
            clangArgs,
            frameworkIncludes,
            swiftIncludes
        ) = try await processSwiftArgs(
            rawArguments: args,
            buildSettings: &buildSettings,
            includeSelfSwiftDebugSettings: includeSelfSwiftDebugSettings,
            previewsFrameworkPaths: previewsFrameworkPaths,
            previewsIncludePath: previewsIncludePath,
            transitiveSwiftDebugSettingPaths: transitiveSwiftDebugSettingPaths
        )

        guard generateBuildSettings else {
            return ([], clangArgs, frameworkIncludes, swiftIncludes)
        }

        let cHasDebugInfo = try await processCArgs(
            rawArguments: args,
            buildSettings: &buildSettings
        )

        let cxxHasDebugInfo = try await processCxxArgs(
            rawArguments: args,
            buildSettings: &buildSettings
        )

        if generatesDsyms || swiftHasDebugInfo || cHasDebugInfo ||
            cxxHasDebugInfo
        {
            // Set to dwarf, because Bazel will generate the dSYMs. We don't set
            // "DEBUG_INFORMATION_FORMAT" to "dwarf", as we set that at the
            // project level
        } else {
            buildSettings.append(
                ("DEBUG_INFORMATION_FORMAT", #""""#)
            )
        }

        if !deviceFamily.isEmpty {
            buildSettings.append(
                ("TARGETED_DEVICE_FAMILY", deviceFamily.pbxProjEscaped)
            )
        }

        if extensionSafe {
            buildSettings.append(("APPLICATION_EXTENSION_API_ONLY", "YES"))
        }

        if !infoPlist.isEmpty {
            buildSettings.append(
                (
                    "INFOPLIST_FILE",
                    infoPlist.buildSettingPath().quoteIfNeeded().pbxProjEscaped
                )
            )
        }

        if !entitlements.isEmpty {
            buildSettings.append(
                (
                    "CODE_SIGN_ENTITLEMENTS",
                    entitlements.buildSettingPath().quoteIfNeeded()
                        .pbxProjEscaped
                )
            )

            // This is required because otherwise Xcode can fails the build
            // due to a generated entitlements file being modified by the
            // Bazel build script. We only set this for BwB mode though,
            // because when this is set, Xcode uses the entitlements as
            // provided instead of modifying them, which is needed in BwX
            // mode.
            buildSettings.append(
                ("CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION", "YES")
            )
        }

        if skipCodesigning {
            buildSettings.append(("CODE_SIGNING_ALLOWED", "NO"))
        }

        if !certificateName.isEmpty {
            buildSettings.append(
                ("CODE_SIGN_IDENTITY", certificateName.pbxProjEscaped)
            )
        }

        if !teamID.isEmpty {
            buildSettings.append(("DEVELOPMENT_TEAM", teamID.pbxProjEscaped))
        }

        if !provisioningProfileName.isEmpty {
            buildSettings.append(
                (
                    "PROVISIONING_PROFILE_SPECIFIER",
                    provisioningProfileName.pbxProjEscaped
                )
            )
        }

        if provisioningProfileIsXcodeManaged {
            buildSettings.append(("CODE_SIGN_STYLE", "Automatic"))
        }

        return (buildSettings, clangArgs, frameworkIncludes, swiftIncludes)
    }

    private static func processSwiftArgs(
        rawArguments: AsyncThrowingStream<Substring, Error>,
        buildSettings: inout [(key: String, value: String)],
        includeSelfSwiftDebugSettings: Bool,
        previewsFrameworkPaths: String,
        previewsIncludePath: String,
        transitiveSwiftDebugSettingPaths: [URL]
    ) async throws -> (
        hasDebugInfo: Bool,
        clangArgs: [String],
        frameworkIncludes: OrderedSet<String>,
        swiftIncludes: OrderedSet<String>
    ) {
        var previousArg: Substring? = nil
        var previousClangArg: Substring? = nil
        var previousFrontendArg: Substring? = nil
        var skipNext = 0

        // First two arguments are `swift_worker` and `clang`
        var iterator = rawArguments.makeAsyncIterator()
        guard let tool = try await iterator.next(), tool != argsSeparator else {
            return (false, [], [], [])
        }
        _ = try await iterator.next()

        var args: [Substring] = [
            // Work around stubbed swiftc messing with Indexing setting of
            // `-working-directory` incorrectly
            "-Xcc",
            "-working-directory",
            "-Xcc",
            "$(PROJECT_DIR)",
            "-working-directory",
            "$(PROJECT_DIR)",

            "-Xcc",
            "-ivfsoverlay$(OBJROOT)/bazel-out-overlay.yaml",
            "-vfsoverlay",
            "$(OBJROOT)/bazel-out-overlay.yaml",
        ]
        var clangArgs: [String] = []
        var frameworkIncludes: OrderedSet<String> = []
        var onceClangArgs: Set<String> = []
        var swiftIncludes: OrderedSet<String> = []

        if !previewsFrameworkPaths.isEmpty {
            buildSettings.append(
                (
                    "PREVIEW_FRAMEWORK_PATHS",
                    previewsFrameworkPaths.pbxProjEscaped
                )
            )
        }

        if !previewsIncludePath.isEmpty {
            buildSettings.append(("PREVIEWS_SWIFT_INCLUDE__", #""""#))
            buildSettings.append(("PREVIEWS_SWIFT_INCLUDE__NO", #""""#))
            buildSettings.append(
                (
                    "PREVIEWS_SWIFT_INCLUDE__YES",
                    "-I\(Substring(previewsIncludePath).buildSettingPath())"
                        .pbxProjEscaped
                )
            )

            args.append("$(PREVIEWS_SWIFT_INCLUDE__$(ENABLE_PREVIEWS))")
        }

        var hasDebugInfo = false
        for try await arg in rawArguments {
            guard arg != argsSeparator else {
                break
            }

            if skipNext != 0 {
                skipNext -= 1
                continue
            }

            let isClangArg = previousArg == "-Xcc"
            let isFrontendArg = previousArg == "-Xfrontend"
            let isFrontend = arg == "-Xfrontend"
            let isXcc = arg == "-Xcc"

            // Track previous argument
            defer {
                if isClangArg {
                    previousClangArg = arg
                } else if !isXcc {
                    previousClangArg = nil
                }

                if isFrontendArg {
                    previousFrontendArg = arg
                } else if !isFrontend {
                    previousFrontendArg = nil
                }

                previousArg = arg
            }

            // Handle Clang (-Xcc) args
            if isXcc {
                args.append(arg)
                continue
            }

            if isClangArg {
                try processClangArg(
                    arg,
                    previousClangArg: previousClangArg,
                    args: &args,
                    clangArgs: &clangArgs,
                    includeSelfSwiftDebugSettings:
                        includeSelfSwiftDebugSettings,
                    onceClangArgs: &onceClangArgs
                )
                continue
            }

            // Skip based on flag
            let rootArg = arg.split(separator: "=", maxSplits: 1).first!

            if let thisSkipNext = skipSwiftArgs[rootArg] {
                skipNext = thisSkipNext - 1
                continue
            }

            if isFrontendArg {
                if let thisSkipNext = skipFrontendArgs[rootArg] {
                    skipNext = thisSkipNext - 1
                    continue
                }

                // We filter out `-Xfrontend`, so we need to add it back if the
                // current arg wasn't filtered out
                args.append("-Xfrontend")

                try processFrontendArg(
                    arg,
                    previousFrontendArg: previousFrontendArg,
                    args: &args
                )
                continue
            }

            if arg == "-g" {
                hasDebugInfo = true
                continue
            }

            if !arg.hasPrefix("-") && arg.hasSuffix(".swift") {
                // These are the files to compile, not options. They are seen
                // here because of the way we collect Swift compiler options.
                // Ideally in the future we could collect Swift compiler options
                // similar to how we collect C and C++ compiler options.
                continue
            }

            try processSwiftArg(
                arg,
                previousArg: previousArg,
                previousFrontendArg: previousFrontendArg,
                args: &args,
                buildSettings: &buildSettings,
                frameworkIncludes: &frameworkIncludes,
                includeSelfSwiftDebugSettings: includeSelfSwiftDebugSettings,
                swiftIncludes: &swiftIncludes
            )
        }

        try await parseTransitiveSwiftDebugSettings(
            transitiveSwiftDebugSettingPaths,
            clangArgs: &clangArgs,
            frameworkIncludes: &frameworkIncludes,
            onceClangArgs: &onceClangArgs,
            swiftIncludes: &swiftIncludes
        )

        buildSettings.append(
            ("OTHER_SWIFT_FLAGS", args.joined(separator: " ").pbxProjEscaped)
        )

        return (hasDebugInfo, clangArgs, frameworkIncludes, swiftIncludes)
    }

    private static func parseTransitiveSwiftDebugSettings(
        _ transitiveSwiftDebugSettingPaths: [URL],
        clangArgs: inout [String],
        frameworkIncludes: inout OrderedSet<String>,
        onceClangArgs: inout Set<String>,
        swiftIncludes: inout OrderedSet<String>
    ) async throws {
        for url in transitiveSwiftDebugSettingPaths {
            var iterator = url.lines.makeAsyncIterator()

            guard let rawClangArgsCount = try await iterator.next() else {
                throw PreconditionError(message: """
"\(url.path)": Missing clang args count
""")
            }
            guard let clangArgsCount = Int(rawClangArgsCount) else {
                throw PreconditionError(message: """
"\(url.path)": Clang args count "\(rawClangArgsCount)" was not an integer
""")
            }
            argsLoop: for index in (0..<clangArgsCount) {
                guard let arg =
                    try await iterator.next()?.nullsToNewlines
                else {
                    throw PreconditionError(message: """
"\(url.path)": Too clang args. Found \(index), expected \
\(clangArgsCount)
""")
                }

                for onceArgPrefixes in clangOnceArgPrefixes {
                    if arg.hasPrefix(onceArgPrefixes) {
                        guard !onceClangArgs.contains(arg) else {
                            continue argsLoop
                        }
                        onceClangArgs.insert(arg)
                        break
                    }
                }
                clangArgs.append(arg)
            }

            guard let rawFrameworkIncludesCount = try await iterator.next()
            else {
                throw PreconditionError(message: """
"\(url.path)": Missing framework includes count
""")
            }
            guard let frameworkIncludesCount = Int(rawFrameworkIncludesCount)
            else {
                throw PreconditionError(message: """
"\(url.path)": Framework includes count "\(rawFrameworkIncludesCount)" was not \
an integer
""")
            }
            for index in (0..<frameworkIncludesCount) {
                guard let include =
                    try await iterator.next()?.nullsToNewlines
                else {
                    throw PreconditionError(message: """
"\(url.path)": Too few framework includes. Found \(index), expected \
\(frameworkIncludesCount)
""")
                }
                frameworkIncludes.append(include)
            }

            guard let rawSwiftIncludesCount = try await iterator.next()
            else {
                throw PreconditionError(message: """
"\(url.path)": Missing swift includes count
""")
            }
            guard let swiftIncludesCount = Int(rawSwiftIncludesCount)
            else {
                throw PreconditionError(message: """
"\(url.path)": Swift includes count "\(rawSwiftIncludesCount)" was not an \
integer
""")
            }
            for index in (0..<swiftIncludesCount) {
                guard let include =
                    try await iterator.next()?.nullsToNewlines
                else {
                    throw PreconditionError(message: """
"\(url.path)": Too few swift includes. Found \(index), expected \
\(swiftIncludesCount)
""")
                }
                swiftIncludes.append(include)
            }
        }
    }

    private static func processSwiftArg(
        _ arg: Substring,
        previousArg: Substring?,
        previousFrontendArg: Substring?,
        args: inout [Substring],
        buildSettings: inout [(key: String, value: String)],
        frameworkIncludes: inout OrderedSet<String>,
        includeSelfSwiftDebugSettings: Bool,
        swiftIncludes: inout OrderedSet<String>
    ) throws {
        let appendIncludes:
            (_ set: inout OrderedSet<String>, _ path: Substring) -> Void
        if includeSelfSwiftDebugSettings {
            appendIncludes = { set, path in
                set.append(path.escapingForDebugSettings())
            }
        } else {
            appendIncludes = { _, _ in }
        }

        if let compilationMode = compilationModeArgs[arg] {
            buildSettings.append(("SWIFT_COMPILATION_MODE", compilationMode))
            return
        }

        if previousArg == "-swift-version" {
            if arg != "5.0" {
                buildSettings.append(("SWIFT_VERSION", String(arg)))
            }
            return
        }

        if arg.hasPrefix("-I") {
            let path = arg.dropFirst(2)
            guard !path.isEmpty else {
                args.append(arg)
                return
            }

            let absolutePath: Substring = path.buildSettingPath()
            let absoluteArg: Substring = "-I" + absolutePath
            args.append(absoluteArg.quoteIfNeeded())
            appendIncludes(&swiftIncludes, absolutePath)
            return
        }

        if previousArg == "-I" {
            let absolutePath = arg.buildSettingPath()
            args.append(absolutePath.quoteIfNeeded())
            appendIncludes(&swiftIncludes, absolutePath)
            return
        }

        if previousArg == "-F" {
            let absolutePath = arg.buildSettingPath()
            args.append(absolutePath.quoteIfNeeded())
            appendIncludes(&frameworkIncludes, absolutePath)
            return
        }

        if arg.hasPrefix("-F") {
            let path = arg.dropFirst(2)

            guard !path.isEmpty else {
                args.append(arg)
                return
            }

            let absolutePath: Substring = path.buildSettingPath()
            let absoluteArg: Substring = "-F" + absolutePath
            args.append(absoluteArg.quoteIfNeeded())
            appendIncludes(&frameworkIncludes, absolutePath)
            return
        }

        if arg.hasPrefix("-vfsoverlay") {
            var path = arg.dropFirst(11)

            guard !path.isEmpty else {
                args.append(arg)
                return
            }

            if path.hasPrefix("=") {
                path = path.dropFirst()
            }

            let absoluteArg: Substring = "-vfsoverlay" + path.buildSettingPath()
            args.append(absoluteArg.quoteIfNeeded())
            return
        }

        if previousArg == "-vfsoverlay" {
            args.append(arg.buildSettingPath().quoteIfNeeded())
            return
        }

        args.append(arg.substituteBazelPlaceholders().quoteIfNeeded())
    }

    private static func processClangArg(
        _ arg: Substring,
        previousClangArg: Substring?,
        args: inout [Substring],
        clangArgs: inout [String],
        includeSelfSwiftDebugSettings: Bool,
        onceClangArgs: inout Set<String>
    ) throws {
        func appendClangArg(
            _ clangArg: String,
            disallowMultiples: Bool = true
        ) {
            guard includeSelfSwiftDebugSettings else {
                return
            }
            if disallowMultiples {
                guard !onceClangArgs.contains(clangArg) else {
                    return
                }
                onceClangArgs.insert(clangArg)
            }
            clangArgs.append(clangArg)
        }

        if arg.hasPrefix("-fmodule-map-file=") {
            let path = arg.dropFirst(18)
            let absoluteArg: Substring =
                "-fmodule-map-file=" + path.buildSettingPath()
            args.append(absoluteArg.quoteIfNeeded())
            appendClangArg(absoluteArg.escapingForDebugSettings())
            return
        }

        if arg.hasPrefix("-D") {
            let absoluteArg = arg.substituteBazelPlaceholders()
            args.append(absoluteArg.quoteIfNeeded())
            appendClangArg(absoluteArg.escapingForDebugSettings())
            return
        }

        for (searchArg, disallowMultiples) in clangSearchPathArgs {
            if arg.hasPrefix(searchArg) {
                let path = arg.dropFirst(searchArg.count)

                guard !path.isEmpty else {
                    args.append(arg)
                    return
                }

                args.append(searchArg)
                args.append("-Xcc")

                let absoluteArg = path.buildSettingPath()
                args.append(absoluteArg.quoteIfNeeded())
                appendClangArg(
                    (searchArg + absoluteArg).escapingForDebugSettings(),
                    disallowMultiples: disallowMultiples
                )
                return
            }
        }

        if let previousClangArg,
           let disallowMultiples = clangSearchPathArgs[previousClangArg]
        {
            let absoluteArg = arg.buildSettingPath()
            args.append(absoluteArg.quoteIfNeeded())
            appendClangArg(
                (previousClangArg + absoluteArg).escapingForDebugSettings(),
                disallowMultiples: disallowMultiples
            )
        }

        // `-ivfsoverlay` doesn't apply `-working_directory=`, so we need to
        // prefix it ourselves
        if previousClangArg == "-ivfsoverlay" {
            let absolutePath = arg.buildSettingPath()
            args.append(absolutePath.quoteIfNeeded())
            appendClangArg(("-ivfsoverlay" + absolutePath).escapingForDebugSettings())
            return
        }

        if arg.hasPrefix("-ivfsoverlay") {
            var path = arg.dropFirst(12)

            guard !path.isEmpty else {
                args.append(arg)
                return
            }

            if path.hasPrefix("=") {
                path = path.dropFirst()
            }

            let absoluteArg: Substring =
                "-ivfsoverlay" + path.buildSettingPath()
            args.append(absoluteArg.quoteIfNeeded())
            appendClangArg(absoluteArg.escapingForDebugSettings())
            return
        }

        let absoluteArg = arg.substituteBazelPlaceholders()
        args.append(absoluteArg.quoteIfNeeded())
        appendClangArg(
            absoluteArg.escapingForDebugSettings(),
            disallowMultiples: false
        )
    }

    private static func processFrontendArg(
        _ arg: Substring,
        previousFrontendArg: Substring?,
        args: inout [Substring]
    ) throws {
        if let previousFrontendArg {
            if overlayArgs.contains(previousFrontendArg) {
                args.append(arg.buildSettingPath().quoteIfNeeded())
                return
            }

            if loadPluginsArgs.contains(previousFrontendArg) {
                args.append(arg.buildSettingPath().quoteIfNeeded())
                return
            }
        }

        if arg.hasPrefix("-vfsoverlay") {
            var path = arg.dropFirst(11)

            guard !path.isEmpty else {
                args.append(arg)
                return
            }

            if path.hasPrefix("=") {
                path = path.dropFirst()
            }

            let absoluteArg: Substring =
                "-vfsoverlay" + path.buildSettingPath()
            args.append(absoluteArg.quoteIfNeeded())
            return
        }

        args.append(arg.substituteBazelPlaceholders().quoteIfNeeded())
    }

    private static func processCArgs(
        rawArguments: AsyncThrowingStream<Substring, Error>,
        buildSettings: inout [(key: String, value: String)]
    ) async throws -> Bool {
        var iterator = rawArguments.makeAsyncIterator()

        guard let outputPath = try await iterator.next() else {
            return false
        }

        guard outputPath != argsSeparator else {
            return false
        }

        // First argument is `wrapped_clang_pp`
        _ = try await iterator.next()

        let (args, hasDebugInfo, fortifySourceLevel) = try await processCCArgs(
            rawArguments: rawArguments
        )

        let content = args.map { $0 + "\n" }.joined()
        try Write()(content, to: URL(fileURLWithPath: String(outputPath)))

        buildSettings.append(
            (
                "C_PARAMS_FILE",
                #"""
"$(BAZEL_OUT)\#(outputPath.dropFirst(9))"
"""#
            )
        )

        if fortifySourceLevel > 0 {
            // ASAN doesn't work with `-D_FORTIFY_SOURCE=1`, so we need to only
            // include that when not building with ASAN
            buildSettings.append(
                ("ASAN_OTHER_CFLAGS__", #""$(ASAN_OTHER_CFLAGS__NO)""#)
            )
            buildSettings.append(
                (
                    "ASAN_OTHER_CFLAGS__NO",
                    #"""
"@$(DERIVED_FILE_DIR)/c.compile.params \#
-D_FORTIFY_SOURCE=\#(fortifySourceLevel)"
"""#
                )
            )
            buildSettings.append(
                (
                    "ASAN_OTHER_CFLAGS__YES",
                    #""@$(DERIVED_FILE_DIR)/c.compile.params""#
                )
            )
            buildSettings.append(
                (
                    "OTHER_CFLAGS",
                    #"""
"$(ASAN_OTHER_CFLAGS__$(CLANG_ADDRESS_SANITIZER))"
"""#
                )
            )
        } else {
            buildSettings.append(
                (
                    "OTHER_CFLAGS",
                    #""@$(DERIVED_FILE_DIR)/c.compile.params""#
                )
            )
        }

        return hasDebugInfo
    }

    private static func processCxxArgs(
        rawArguments: AsyncThrowingStream<Substring, Error>,
        buildSettings: inout [(key: String, value: String)]
    ) async throws -> Bool {
        var iterator = rawArguments.makeAsyncIterator()

        guard let outputPath = try await iterator.next() else {
            return false
        }

        guard outputPath != argsSeparator else {
            return false
        }

        // First argument is `wrapped_clang_pp`
        _ = try await iterator.next()

        let (args, hasDebugInfo, fortifySourceLevel) = try await processCCArgs(
            rawArguments: rawArguments
        )

        let content = args.map { $0 + "\n" }.joined()
        try Write()(content, to: URL(fileURLWithPath: String(outputPath)))

        buildSettings.append(
            (
                "CXX_PARAMS_FILE",
                #""$(BAZEL_OUT)\#(outputPath.dropFirst(9))""#
            )
        )

        if fortifySourceLevel > 0 {
            // ASAN doesn't work with `-D_FORTIFY_SOURCE=1`, so we need to only
            // include that when not building with ASAN
            buildSettings.append(
                (
                    "ASAN_OTHER_CPLUSPLUSFLAGS__",
                    #""$(ASAN_OTHER_CPLUSPLUSFLAGS__NO)""#
                )
            )
            buildSettings.append(
                (
                    "ASAN_OTHER_CPLUSPLUSFLAGS__NO",
                    #"""
"@$(DERIVED_FILE_DIR)/cxx.compile.params \#
-D_FORTIFY_SOURCE=\#(fortifySourceLevel)"
"""#
                )
            )
            buildSettings.append(
                (
                    "ASAN_OTHER_CPLUSPLUSFLAGS__YES",
                    #""@$(DERIVED_FILE_DIR)/cxx.compile.params""#
                )
            )
            buildSettings.append(
                (
                    "OTHER_CPLUSPLUSFLAGS",
                    #"""
"$(ASAN_OTHER_CPLUSPLUSFLAGS__$(CLANG_ADDRESS_SANITIZER))"
"""#
                )
            )
        } else {
            buildSettings.append(
                (
                    "OTHER_CPLUSPLUSFLAGS",
                    #""@$(DERIVED_FILE_DIR)/cxx.compile.params""#
                )
            )
        }

        return hasDebugInfo
    }

    private static func processCCArgs(
        rawArguments: AsyncThrowingStream<Substring, Error>
    ) async throws -> (
        args: [Substring],
        hasDebugInfo: Bool,
        fortifySourceLevel: Int
    ) {
        var previousArg: Substring? = nil
        var skipNext = 0

        var args: [Substring] = [
            "-working-directory",
            "$(PROJECT_DIR)",
            "-ivfsoverlay",
            "$(OBJROOT)/bazel-out-overlay.yaml",
        ]

        var hasDebugInfo = false
        var fortifySourceLevel = 0
        for try await arg in rawArguments {
            guard arg != argsSeparator else {
                break
            }

            if skipNext != 0 {
                skipNext -= 1
                continue
            }

            // Track previous argument
            defer {
                previousArg = arg
            }

            // Skip based on flag
            let rootArg = arg.split(separator: "=", maxSplits: 1).first!

            if let thisSkipNext = skipCCArgs[rootArg] {
                skipNext = thisSkipNext - 1
                continue
            }

            if arg == "-g" {
                hasDebugInfo = true
                continue
            }

            if arg.hasPrefix("-D_FORTIFY_SOURCE=") {
                if let level = Int(arg.dropFirst(18)) {
                    fortifySourceLevel = level
                } else {
                    fortifySourceLevel = 1
                }
                continue
            }

            try processCCArg(
                arg,
                previousArg: previousArg,
                args: &args
            )
        }

        return (args, hasDebugInfo, fortifySourceLevel)
    }

    private static func processCCArg(
        _ arg: Substring,
        previousArg: Substring?,
        args: inout [Substring]
    ) throws {
        // `-ivfsoverlay` and `--config` don't apply `-working_directory=`, so
        // we need to prefix it ourselves
        for prefix in cNeedsAbsolutePathArgs {
            if arg.hasPrefix(prefix) {
                var path = arg.dropFirst(12)

                guard !path.isEmpty else {
                    args.append(arg)
                    return
                }

                if path.hasPrefix("=") {
                    path = path.dropFirst()
                }

                let absoluteArg: Substring = prefix + path.buildSettingPath()
                args.append(absoluteArg.quoteIfNeeded())
                return
            }
        }

        if let previousArg, cNeedsAbsolutePathArgs.contains(previousArg) {
            args.append(arg.buildSettingPath().quoteIfNeeded())
            return
        }

        args.append(arg.substituteBazelPlaceholders().quoteIfNeeded())
    }

    private static func parseArgs(
        rawArguments: Array<String>.SubSequence
    ) -> AsyncThrowingStream<Substring, Error> {
        return AsyncThrowingStream { continuation in
            let argsTask = Task {
                for arg in rawArguments {
                    guard !arg.starts(with: "@") else {
                        let path = String(arg.dropFirst())
                        for try await line in URL(fileURLWithPath: path).lines {
                            // Change params files from `shell` to `multiline`
                            // format
                            // https://bazel.build/versions/6.1.0/rules/lib/Args#set_param_file_format.format
                            if line.hasPrefix("'") && line.hasSuffix("'") {
                                let startIndex = line
                                    .index(line.startIndex, offsetBy: 1)
                                let endIndex = line.index(before: line.endIndex)
                                continuation
                                    .yield(line[startIndex ..< endIndex])
                            } else {
                                continuation.yield(Substring(line))
                            }
                        }
                        continue
                    }
                    continuation.yield(Substring(arg))
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                argsTask.cancel()
            }
        }
    }
}

private let argsSeparator: Substring = "---"

private let skipSwiftArgs: [Substring: Int] = [
    // Xcode sets output paths
    "-emit-module-path": 2,
    "-emit-object": 1,
    "-output-file-map": 2,

    // Xcode sets these, and no way to unset them
    "-enable-bare-slash-regex": 1,
    "-module-name": 2,
    "-num-threads": 2,
    "-parse-as-library": 1,
    "-sdk": 2,
    "-target": 2,

    // We want to use Xcode's normal PCM handling
    "-module-cache-path": 2,

    // We want Xcode's normal debug handling
    "-debug-prefix-map": 2,
    "-file-prefix-map": 2,
    "-gline-tables-only": 1,

    // We want to use Xcode's normal indexing handling
    "-index-ignore-system-modules": 1,
    "-index-store-path": 2,

    // We set Xcode build settings to control these
    "-enable-batch-mode": 1,

    // We don't want to translate this for BwX
    "-emit-symbol-graph-dir": 2,

    // These are fully handled in a `previousArg` check
    "-swift-version": 1,

    // We filter out `-Xfrontend`, then add it back only if the current arg
    // wasn't filtered out
    "-Xfrontend": 1,

    // This is rules_swift specific, and we don't want to translate it for BwX
    "-Xwrapped-swift": 1,
]

private let skipFrontendArgs: [Substring: Int] = [
    // We want Xcode to control coloring
    "-color-diagnostics": 1,

    // We want Xcode's normal debug handling
    "-no-clang-module-breadcrumbs": 1,
    "-no-serialize-debugging-options": 1,
    "-serialize-debugging-options": 1,

    // We don't want to translate this for BwX
    "-emit-symbol-graph": 1,
]

private let skipCCArgs: [Substring: Int] = [
    // Xcode sets these, and no way to unset them
    "-isysroot": 2,
    "-mios-simulator-version-min": 1,
    "-miphoneos-version-min": 1,
    "-mmacosx-version-min": 1,
    "-mtvos-simulator-version-min": 1,
    "-mtvos-version-min": 1,
    "-mwatchos-simulator-version-min": 1,
    "-mwatchos-version-min": 1,
    "-target": 2,

    // Xcode sets input and output paths
    "-c": 2,
    "-o": 2,

    // We set this in the generator
    "-fobjc-arc": 1,
    "-fno-objc-arc": 1,

    // We want to use Xcode's dependency file handling
    "-MD": 1,
    "-MF": 2,

    // We want to use Xcode's normal indexing handling
    "-index-ignore-system-symbols": 1,
    "-index-store-path": 2,

    // We want Xcode's normal debug handling
    "-fdebug-prefix-map": 2,

    // We want Xcode to control coloring
    "-fcolor-diagnostics": 1,

    // This is wrapped_clang specific, and we don't want to translate it for BwX
    "DEBUG_PREFIX_MAP_PWD": 1,
]

private let compilationModeArgs: [Substring: String] = [
    "-incremental": "singlefile",
    "-no-whole-module-optimization": "singlefile",
    "-whole-module-optimization": "wholemodule",
    "-wmo": "wholemodule",
]

// Maps arg -> multiples not allowed in clangArgs
private let clangSearchPathArgs: [Substring: Bool] = [
    "-F": true,
    "-I": true,
    "-iquote": false,
    "-isystem": false,
]

private let clangOnceArgPrefixes = [
    "-F",
    "-D",
    "-I",
    "-fmodule-map-file=",
    "-ivfsoverlay",
]

private let loadPluginsArgs: Set<Substring> = [
    "-load-plugin-executable",
    "-load-plugin-library",
]

private let cNeedsAbsolutePathArgs: Set<Substring> = [
    "--config",
    "-ivfsoverlay",
]

private let overlayArgs: Set<Substring> = [
    "-explicit-swift-module-map-file",
    "-vfsoverlay",
]

extension Substring {
    func buildSettingPath() -> Self {
        if self == "bazel-out" || starts(with: "bazel-out/") {
            // Dropping "bazel-out" prefix
            return "$(BAZEL_OUT)\(dropFirst(9))"
        }

        if self == "external" || starts(with: "external/") {
            // Dropping "external" prefix
            return "$(BAZEL_EXTERNAL)\(dropFirst(8))"
        }

        if self == ".." || starts(with: "../") {
            // Dropping ".." prefix
            return "$(BAZEL_EXTERNAL)\(dropFirst(2))"
        }

        if self == "." {
            // We need to use Bazel's execution root for ".", since includes can
            // reference things like "external/" and "bazel-out"
            return "$(PROJECT_DIR)"
        }

        let substituted = substituteBazelPlaceholders()

        if substituted.hasPrefix("/") || substituted.hasPrefix("$(") {
            return substituted
        }

        return "$(SRCROOT)/\(substituted)"
    }

    func substituteBazelPlaceholders() -> Self {
        return
            // Use Xcode set `DEVELOPER_DIR`
            replacing(
                "__BAZEL_XCODE_DEVELOPER_DIR__",
                with: "$(DEVELOPER_DIR)"
            )
            // Use Xcode set `SDKROOT`
            .replacing("__BAZEL_XCODE_SDKROOT__", with: "$(SDKROOT)")
    }

    // FIXME: Use `escapingForDebugSettings` instead?
    func quoteIfNeeded() -> Self {
        // Quote the arg if it contains spaces
        guard !contains(" ") else {
            return "'\(self)'"
        }
        return self
    }

    func escapingForDebugSettings() -> String {
        return replacingOccurrences(of: " ", with: #"\ "#)
            .replacingOccurrences(of: #"""#, with: #"\""#)
            // These nulls will become newlines with `.nullsToNewlines` in
            // `pbxnativetargets`. We need to escape them in order to be
            // able to split on newlines.
            .replacingOccurrences(of: "\n", with: "\0")
    }
}

extension String {
    func buildSettingPath(
        useXcodeBuildDir: Bool = false
    ) -> Self {
        if self == "bazel-out" || starts(with: "bazel-out/") {
            // Dropping "bazel-out" prefix
            if useXcodeBuildDir {
                return "$(BUILD_DIR)\(dropFirst(9))"
            } else {
                return "$(BAZEL_OUT)\(dropFirst(9))"
            }
        }

        if self == "external" || starts(with: "external/") {
            // Dropping "external" prefix
            return "$(BAZEL_EXTERNAL)\(dropFirst(8))"
        }

        if self == ".." || starts(with: "../") {
            // Dropping ".." prefix
            return "$(BAZEL_EXTERNAL)\(dropFirst(2))"
        }

        if self == "." {
            // We need to use Bazel's execution root for ".", since includes can
            // reference things like "external/" and "bazel-out"
            return "$(PROJECT_DIR)"
        }

        let substituted = substituteBazelPlaceholders()

        if substituted.hasPrefix("/") {
            return substituted
        }

        return "$(SRCROOT)/\(substituted)"
    }

    func substituteBazelPlaceholders() -> Self {
        return
            // Use Xcode set `DEVELOPER_DIR`
            replacing(
                "__BAZEL_XCODE_DEVELOPER_DIR__",
                with: "$(DEVELOPER_DIR)"
            )
            // Use Xcode set `SDKROOT`
            .replacing("__BAZEL_XCODE_SDKROOT__", with: "$(SDKROOT)")
    }

    // FIXME: Use `escapingForDebugSettings` instead?
    func quoteIfNeeded() -> Self {
        // Quote the arg if it contains spaces
        guard !contains(" ") else {
            return "'\(self)'"
        }
        return self
    }

    var nullsToNewlines: String {
        replacingOccurrences(of: "\0", with: "\n")
    }
}

extension Array<String>.SubSequence {
    mutating func popArgument(_ name: String) throws -> String {
        guard let arg = popFirst() else {
            throw PreconditionError(message: "Missing <\(name)>")
        }
        return arg
    }
}
