import Basic
import Foundation
import ProjectDescription
import TuistCore
import TuistSupport

extension TuistCore.FileElement {
    /// Maps a ProjectDescription.FileElement instance into a [TuistCore.FileElement] instance.
    /// Glob patterns in file elements are unfolded as part of the mapping.
    /// - Parameters:
    ///   - manifest: Manifest representation of  the file element.
    ///   - generatorPaths: Generator paths.
    static func from(manifest: ProjectDescription.FileElement,
                     generatorPaths: GeneratorPaths,
                     includeFiles: @escaping (AbsolutePath) -> Bool = { _ in true }) throws -> [TuistCore.FileElement] {
        func globFiles(_ path: AbsolutePath) -> [AbsolutePath] {
            let files = FileHandler.shared.glob(AbsolutePath.root, glob: String(path.pathString.dropFirst()))
                .filter(includeFiles)

            if files.isEmpty {
                if FileHandler.shared.isFolder(path) {
                    Printer.shared.print(warning: "'\(path.pathString)' is a directory, try using: '\(path.pathString)/**' to list its files")
                } else {
                    // FIXME: This should be done in a linter.
                    Printer.shared.print(warning: "No files found at: \(path.pathString)")
                }
            }

            return files
        }

        func folderReferences(_ path: AbsolutePath) -> [AbsolutePath] {
            guard FileHandler.shared.exists(path) else {
                // FIXME: This should be done in a linter.
                Printer.shared.print(warning: "\(path.pathString) does not exist")
                return []
            }

            guard FileHandler.shared.isFolder(path) else {
                // FIXME: This should be done in a linter.
                Printer.shared.print(warning: "\(path.pathString) is not a directory - folder reference paths need to point to directories")
                return []
            }

            return [path]
        }

        switch manifest {
        case let .glob(pattern: pattern):
            let resolvedPath = try generatorPaths.resolve(path: pattern)
            return globFiles(resolvedPath).map(FileElement.file)
        case let .folderReference(path: folderReferencePath):
            let resolvedPath = try generatorPaths.resolve(path: folderReferencePath)
            return folderReferences(resolvedPath).map(FileElement.folderReference)
        }
    }
}