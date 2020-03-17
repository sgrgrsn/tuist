import Checksum
import Foundation
import TuistCore
import TuistSupport
import Basic

public protocol GraphContentHashing {
    func contentHash(for graph: Graphing) throws -> [TargetNode: String]
}

public final class GraphContentHasher: GraphContentHashing {
    private let contentHasher: ContentHasher
    private let coreDataModelsContentHasher: CoreDataModelsContentHasher

    public init(
        contentHasher: ContentHasher = ContentHasher(),
        coreDataModelsContentHasher: CoreDataModelsContentHasher = CoreDataModelsContentHasher()
    ) {
        self.contentHasher = contentHasher
        self.coreDataModelsContentHasher = coreDataModelsContentHasher
    }

    public func contentHash(for graph: Graphing) throws -> [TargetNode: String] {
        let hashableTargets = graph.targets.filter { $0.target.product == .framework }
        let hashes = try hashableTargets.map { try hash(targetNode: $0) }
        return Dictionary(uniqueKeysWithValues: zip(hashableTargets, hashes))
    }

    // MARK: - Private

    private func hash(targetNode: TargetNode) throws -> String {
        let target = targetNode.target
        let sourcesHash = try hash(sources: target.sources)
        let resourcesHash = try hash(resources: target.resources)
        let coreDataModelHash = try coreDataModelsContentHasher.hash(coreDataModels: target.coreDataModels)
        let targetActionsHash = try hash(targetActions: target.actions)
        let stringsToHash = [sourcesHash,
                             target.name,
                             target.platform.rawValue,
                             target.product.rawValue,
                             target.bundleId,
                             target.productName,
                             resourcesHash,
                             coreDataModelHash,
                             targetActionsHash]


        //TODO: hash headers, platforms, version, entitlements, info.plist, target.environment, target.filesGroup, targetNode.settings, targetNode.project, targetNode.dependencies ,targetNode.target.dependencies

        return try contentHasher.hash(stringsToHash)
    }

    private func hash(headers: Headers) throws -> String {
        let hashes = try (headers.private + headers.project + headers.project).map { path in
            try contentHasher.hash(path)
        }
        return try contentHasher.hash(hashes)
    }

    private func hash(sources: [Target.SourceFile]) throws -> String {
        let sortedSources = sources.sorted(by: { $0.path < $1.path })
        var stringsToHash: [String] = []
        for source in sortedSources {
            let contentHash = try contentHasher.hash(source.path)
            var sourceHash = contentHash
            if let compilerFlags = source.compilerFlags {
                sourceHash += String(compilerFlags.hashValue)
            }
            stringsToHash.append(sourceHash)
        }
        return try contentHasher.hash(stringsToHash)
    }

    private func hash(resources: [FileElement]) throws -> String {
        let paths = resources.map { $0.path }
        let hashes = try paths.map { try contentHasher.hash($0) }
        return try contentHasher.hash(hashes)
    }

    private func hash(targetActions: [TargetAction]) throws -> String {
        var stringsToHash: [String] = []
        for targetAction in targetActions {
            var contentHash = ""
            if let path = targetAction.path {
                contentHash = try contentHasher.hash(path)
            }
            let inputPaths = targetAction.inputPaths.map { $0.pathString }
            let outputPaths = targetAction.outputPaths.map { $0.pathString }
            let outputFileListPaths = targetAction.outputFileListPaths.map { $0.pathString }
            let targetStringsToHash = [
                contentHash,
                targetAction.name,
                targetAction.tool ?? "",
                String(targetAction.order.hashValue),
            ] + targetAction.arguments + inputPaths + outputPaths + outputFileListPaths
            stringsToHash.append(try contentHasher.hash(targetStringsToHash))
        }
        return try contentHasher.hash(stringsToHash)
    }
}
