import ArgumentParser
import Foundation
import PBXProj
import ToolCommon

struct TopLevelTargetAttributes {
    let bundleID: String?

    /// e.g. "bazel-out/App.zip" or "bazel-out/App.app"
    let outputsProductPath: String?

    let linkParams: String?
    let executableName: String?
    let compileTargetIDs: String?
    let unitTestHost: TargetID?
}

extension Dictionary<TargetID, TopLevelTargetAttributes> {
    static func parse(from url: URL) async throws -> Self {
        var rawArgs = ArraySlice(try await url.allLines.collect())

        guard rawArgs.count.isMultiple(of: 7) else {
            throw PreconditionError(message: """
"\(url.path)": Number of lines must be a multiple of 7.
""")
        }

        let targetCount = rawArgs.count / 7

        var keysWithValues: [(TargetID, TopLevelTargetAttributes)] = []
        for _ in (0..<targetCount) {
            let id = try rawArgs.consumeArg(TargetID.self, in: url)
            let bundleID =
                try rawArgs.consumeArg(String?.self, in: url)
            let outputsProductPath =
                try rawArgs.consumeArg(String?.self, in: url)
            let linkParams =
                try rawArgs.consumeArg(String?.self, in: url)
            let executableName =
                try rawArgs.consumeArg(String?.self, in: url)
            let compileTargetIDs =
                try rawArgs.consumeArg(String?.self, in: url)
            let unitTestHost =
                try rawArgs.consumeArg(TargetID?.self, in: url)

            keysWithValues.append(
                (
                    id,
                    .init(
                        bundleID: bundleID,
                        outputsProductPath: outputsProductPath,
                        linkParams: linkParams,
                        executableName: executableName,
                        compileTargetIDs: compileTargetIDs,
                        unitTestHost: unitTestHost
                    )
                )
            )
        }

        return Dictionary(uniqueKeysWithValues: keysWithValues)
    }
}

private extension Array {
    func slicedBy<CountsCollection>(
        targetIndex: Int,
        counts: CountsCollection,
        startIndex: inout Index
    ) -> Self where
        CountsCollection: RandomAccessCollection,
        CountsCollection.Element == Int,
        CountsCollection.Index == Index
    {
        guard !isEmpty else {
            return self
        }

        let endIndex = startIndex.advanced(by: counts[targetIndex])
        let range = startIndex ..< endIndex
        startIndex = endIndex

        return Array(self[range])
    }
}
