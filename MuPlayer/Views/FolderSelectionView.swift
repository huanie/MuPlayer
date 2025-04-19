//
//  FolderSelectionView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 06.04.25.
//

import AppKit
import SwiftUI

enum ScanProgress {
    case none, scanning, done, error
}

extension URL {
    fileprivate func isChild(of parent: URL) -> Bool {
        let parentComponents = parent.standardized.pathComponents
        let selfComponents = self.standardized.pathComponents
        // A child must have more path components than the parent
        guard selfComponents.count > parentComponents.count else {
            return false
        }
        // get the parent's directories and check if they are contained
        return Array(selfComponents.prefix(parentComponents.count))
            == parentComponents
    }
}

struct FolderSelectionView: View {
    private func handleDroppedURLS(_ urls: [URL]) -> Bool {
        let x = urls.filter {
            do {
                return try $0.resourceValues(forKeys: [.isDirectoryKey])
                    .isDirectory ?? false
            } catch {
                return false
            }
        }
        var count = 0
        for toInsert in x {
            if !directories.contains(where: { dir in
                toInsert.isChild(of: URL(string: dir)!)
            }) {
                directories.insert(toInsert.path(percentEncoded: true))
                count += 1
            }
        }

        return count != 0
    }
    @Binding var isScanning: ScanProgress
    @State var directories: Set<String> = Set()
    @State private var multiSelection: Set<String> = Set()
    @State private var pickFile = false
    @Binding var errors: [MusicScanner.ScanError]
    let scanFun: (Set<URL>, URL) -> [MusicScanner.ScanError]?
    var body: some View {
        VStack(spacing: 0) {
            if directories.isEmpty {
                VStack(spacing: 0) {
                    Text("Drop folders").font(.body)
                    Text("or").font(.footnote)
                    HStack {
                        Text("Add folders with the")
                        Image(nsImage: NSImage(named: NSImage.addTemplateName)!)
                        Text("Button")
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(
                    Color.white
                ).onTapGesture {
                    pickFile = true
                }
            } else {
                List(Array(directories), id: \.self, selection: $multiSelection)
                { dir in
                    Text(dir)
                }.onTapGesture {
                    pickFile = true
                }
            }
            HStack(spacing: 0) {
                Button(action: {
                    pickFile = true
                }) {
                    Image(nsImage: NSImage(named: NSImage.addTemplateName)!)
                }.buttonStyle(BorderlessButtonStyle()).frame(
                    width: 20,
                    height: 20
                ).fileImporter(
                    isPresented: $pickFile,
                    allowedContentTypes: [.directory],
                    allowsMultipleSelection: true,
                    onCompletion: {
                        if case .success(let urls) = $0 {
                            for toInsert in urls {
                                if !directories.contains(where: { dir in
                                    toInsert.isChild(of: URL(string: dir)!)
                                }) {
                                    directories.insert(
                                        toInsert.path(percentEncoded: false)
                                    )
                                }
                            }
                        }
                    }
                )
                Divider()
                Button(action: {
                    directories.subtract(multiSelection)
                }) {
                    Image(nsImage: NSImage(named: NSImage.removeTemplateName)!)
                }.buttonStyle(BorderlessButtonStyle()).frame(
                    width: 20,
                    height: 20
                ).keyboardShortcut(
                    .delete
                )
                Divider()
                Spacer()
                Button(
                    "Scan",
                    action: {
                        DispatchQueue.global(qos: .userInitiated).async {
                            DispatchQueue.main.sync {
                                isScanning = .scanning
                            }
                            if let err = scanFun(
                                Set(directories.map({
                                    URL(string: $0)!
                                })),
                                Globals.DATABASE_PATH
                            ) {
                                DispatchQueue.main.async {
                                    self.errors = err
                                    isScanning = .error
                                }
                            } else {
                                DispatchQueue.main.sync {
                                    isScanning = .done
                                }
                            }
                        }
                    }
                )
                .disabled(directories.count == 0)
                .keyboardShortcut(.defaultAction)
                .padding()
            }.frame(height: 30)
        }.dropDestination(
            for: URL.self,
            action: { urls, _ in
                if self.isScanning == .scanning {
                    return false
                }
                return handleDroppedURLS(urls)
            }
        )
    }
}
