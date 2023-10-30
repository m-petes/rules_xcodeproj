import ArgumentParser
import Foundation
import PBXProj
import ToolCommon

@main
struct SwiftDebugSettings {
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
            let (outputPath, keyedSwiftDebugSettings) = try await parseArgs()

            let writeSwiftDebugSettingsTask = Task {
                let content = #"""
#!/usr/bin/python3

"""An lldb module that registers a stop hook to set swift settings."""

import lldb
import re

# Order matters, it needs to be from the most nested to the least
_BUNDLE_EXTENSIONS = [
    ".framework",
    ".xctest",
    ".appex",
    ".bundle",
    ".app",
]

_TRIPLE_MATCH = re.compile(r"([^-]+-[^-]+)(-\D+)[^-]*(-.*)?")

_SETTINGS = {
\#(keyedSwiftDebugSettings.map(settingsString).joined())\#
}

def __lldb_init_module(debugger, _internal_dict):
    # Register the stop hook when this module is loaded in lldb
    ci = debugger.GetCommandInterpreter()
    res = lldb.SBCommandReturnObject()
    ci.HandleCommand(
        "target stop-hook add -P swift_debug_settings.StopHook",
        res,
    )
    if not res.Succeeded():
        print(f"""\
Failed to register Swift debug options stop hook:

{res.GetError()}
Please file a bug report here: \
https://github.com/MobileNativeFoundation/rules_xcodeproj/issues/new?template=bug.md
""")
        return

def _get_relative_executable_path(module):
    for extension in _BUNDLE_EXTENSIONS:
        prefix, _, suffix = module.rpartition(extension)
        if prefix:
            return prefix.split("/")[-1] + extension + suffix
    return module.split("/")[-1]

class StopHook:
    "An lldb stop hook class, that sets swift settings for the current module."

    def __init__(self, _target, _extra_args, _internal_dict):
        pass

    def handle_stop(self, exe_ctx, _stream):
        "Method that is called when the user stops in lldb."
        module = exe_ctx.frame.module
        if not module:
            return

        module_name = module.file.__get_fullpath__()
        versionless_triple = _TRIPLE_MATCH.sub(r"\1\2\3", module.GetTriple())
        executable_path = _get_relative_executable_path(module_name)
        key = f"{versionless_triple} {executable_path}"

        settings = _SETTINGS.get(key)

        if settings:
            frameworks = " ".join([
                f'"{path}"'
                for path in settings.get("f", [])
            ])
            if frameworks:
                lldb.debugger.HandleCommand(
                    f"settings set -- target.swift-framework-search-paths {frameworks}",
                )
            else:
                lldb.debugger.HandleCommand(
                    "settings clear target.swift-framework-search-paths",
                )

            includes = " ".join([
                f'"{path}"'
                for path in settings.get("s", [])
            ])
            if includes:
                lldb.debugger.HandleCommand(
                    f"settings set -- target.swift-module-search-paths {includes}",
                )
            else:
                lldb.debugger.HandleCommand(
                    "settings clear target.swift-module-search-paths",
                )

            clang = settings.get("c")
            if clang:
                lldb.debugger.HandleCommand(
                    f"settings set -- target.swift-extra-clang-flags '{clang}'",
                )
            else:
                lldb.debugger.HandleCommand(
                    "settings clear target.swift-extra-clang-flags",
                )

        return True

"""#

                try content
                    .write(to: outputPath, atomically: true, encoding: .utf8)
            }

            try await writeSwiftDebugSettingsTask.value
        } catch {
            logger.logError(error.localizedDescription)
            Darwin.exit(1)
        }
    }

    private static func parseArgs() async throws -> (
        outputPath: URL,
        keyedSwiftDebugSettings:
            [(key: String, settings: TargetSwiftDebugSettings)]
    ) {
        // First 2 arguments are program name and `<colorize>`
        var rawArguments = CommandLine.arguments.dropFirst(2)

        let outputPath =
            URL(fileURLWithPath: try rawArguments.popArgument("output-path"))

        guard rawArguments.count.isMultiple(of: 2) else {
            throw PreconditionError(message: """
<keys-and-files> must be <key> and <file> pairs
""")
        }

        var keysAndFiles: [(key: String, url: URL)] = []
        for _ in (0..<(rawArguments.count/2)) {
            let key = try rawArguments.popArgument("key")
            let url =
                URL(fileURLWithPath: try rawArguments.popArgument("file"))
            keysAndFiles.append((key, url))
        }

        let keyedSwiftDebugSettings = try await withThrowingTaskGroup(
            of: (key: String, settings: TargetSwiftDebugSettings).self
        ) { group in
            for (key, url) in keysAndFiles {
                group.addTask {
                    return (key, try await .decode(from: url))
                }
            }

            var keyedSwiftDebugSettings:
                [(key: String, settings: TargetSwiftDebugSettings)] = []
            for try await result in group {
                keyedSwiftDebugSettings.append(result)
            }

            return keyedSwiftDebugSettings.sorted(by: { $0.key < $1.key })
        }

        return (
            outputPath,
            keyedSwiftDebugSettings
        )
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

private func settingsString(
    key: String,
    settings: TargetSwiftDebugSettings
) -> String {
    let frameworkIncludes: String
    if settings.frameworkIncludes.isEmpty {
        frameworkIncludes = ""
    } else {
        frameworkIncludes = #"""
        "f": [
\#(settings.frameworkIncludes.map { #"            "\#($0)",\#n"# }.joined())\#
        ],

"""#
    }

    let swiftIncludes: String
    if settings.swiftIncludes.isEmpty {
        swiftIncludes = ""
    } else {
        swiftIncludes = #"""
        "s": [
\#(settings.swiftIncludes.map { #"            "\#($0)",\#n"# }.joined())\#
        ],

"""#
    }

    return #"""
    "\#(key)": {
        "c": "\#(settings.clangArgs.joined(separator: " "))",
\#(frameworkIncludes)\#
\#(swiftIncludes)\#
    },

"""#
}

struct TargetSwiftDebugSettings {
    let clangArgs: [String]
    let frameworkIncludes: [String]
    let swiftIncludes: [String]
}

extension TargetSwiftDebugSettings {
    static func decode(from url: URL) async throws -> Self {
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

        var clangArgs: [String] = []
        for index in (0..<clangArgsCount) {
            guard let arg = try await iterator.next()?.nullsToNewlines else {
                throw PreconditionError(message: """
"\(url.path)": Too clang args. Found \(index), expected \
\(clangArgsCount)
""")
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

        var frameworkIncludes: [String] = []
        for index in (0..<frameworkIncludesCount) {
            guard let include
                = try await iterator.next()?.nullsToNewlines
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

        var swiftIncludes: [String] = []
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

        return Self(
            clangArgs: clangArgs,
            frameworkIncludes: frameworkIncludes,
            swiftIncludes: swiftIncludes
        )
    }
}

extension String {
    var nullsToNewlines: String {
        replacingOccurrences(of: "\0", with: "\n")
    }
}
