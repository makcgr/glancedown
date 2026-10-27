import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdownText = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

/// The viewer reads the file itself (to watch it and resolve relative links), so the document holds no content.
struct MarkdownFile: FileDocument {
    static let readableContentTypes: [UTType] = [.markdownText]

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.featureUnsupported)
    }
}
