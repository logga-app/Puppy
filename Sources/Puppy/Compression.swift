//
//  compression.swift
//  Puppy
//
//  Created by Nagy Peter on 05/06/2024.
//

import Foundation
import AppleArchive
import System

class Compressor {
    enum CompressionError: Error, Equatable, LocalizedError {
        case createFileStream(stream: String)
        case archive(filename: String, err: String)

        public var errorDescription: String? {
            switch self {
            case.createFileStream(stream: let stream):
                return "unable to create \(stream) stream"
            case .archive(filename: let file, err: let error):
                return "unable to archieve \(file): \(error)"
            }
        }
    }

    static func uniqueName(file: String, hostname: String) -> String {
        return "\(file)_\(hostname)_\(Int(Date().timeIntervalSince1970)).archive"
    }

    static func lzfse(src: String, dst: String) throws {
        if #available(macOS 11.0, *) {
            let destinationPath = FilePath(dst)
            let sourceURL = URL(fileURLWithPath: src)

            let header = ArchiveHeader()
            header.append(.string(key: ArchiveHeader.FieldKey("PAT"), value: src))
            header.append(.uint(key: ArchiveHeader.FieldKey("TYP"),
                    value: UInt64(ArchiveHeader.EntryType.regularFile.rawValue)))

            guard let writeFileStream = ArchiveByteStream.fileStream(
                    path: destinationPath,
                    mode: .writeOnly,
                    options: [ .create ],
                    permissions: FilePermissions(rawValue: 0o644)) else {
                throw CompressionError.createFileStream(stream: "write")
            }
            defer {
                try? writeFileStream.close()
            }

            guard let compressStream = ArchiveByteStream.compressionStream(
                using: .lzfse,
                writingTo: writeFileStream,
                blockSize: 1 * 1024 * 1024,
                flags: []) else {
                throw CompressionError.createFileStream(stream: "compress")
            }
            defer {
                try? compressStream.close()
            }

            guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream) else {
                throw CompressionError.createFileStream(stream: "encode")
            }
            defer {
                try? encodeStream.close()
            }

            try Data(contentsOf: sourceURL, options: .mappedIfSafe).withUnsafeBytes {
                header.append(.blob(key: ArchiveHeader.FieldKey("DAT"), size: UInt64($0.count)))
                try encodeStream.writeHeader(header)
                try encodeStream.writeBlob(key: ArchiveHeader.FieldKey("DAT"), from: $0)
            }
        } else {
            puppyDebug("lzfse compression is not supported on this macOS version")
        }
    }
}
