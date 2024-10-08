import MusicPlayerFFI
import SwiftUI

//
//  WelcomeView.swift
//  MusicPlayer
//
//  Created by Huan Nguyen on 23.07.24.
//

struct WelcomeView: View {
  func handleDroppedURLS(_ urls: [URL]) -> Bool {
    let x = urls.filter {
      do { return try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false } catch {
        return false
      }
    }.map {
      $0.path(percentEncoded: false)
    }
    directories.formUnion(x)
    return x.count != 0
  }

  @State private var directories = Set<String>()
  @State private var multiSelection = Set<String>()
  @State private var pickFile = false
  @State private var isScanning = false
  @Binding var done: Bool
  var body: some View {
    if isScanning {
      ProgressView(label: {
        Text("Scanning")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      ).progressViewStyle(.circular).padding()
    } else {
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
          }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.white).onTapGesture {
            pickFile = true
          }
        } else {
          List(Array(directories), id: \.self, selection: $multiSelection) { dir in
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
          }.buttonStyle(BorderlessButtonStyle()).frame(width: 20, height: 20).fileImporter(
            isPresented: $pickFile, allowedContentTypes: [.directory],
            allowsMultipleSelection: true,
            onCompletion: {
              if case .success(let urls) = $0 {
                directories.formUnion(urls.map { $0.path(percentEncoded: false) })
              }
            })
          Divider()
          Button(action: {
            directories.subtract(multiSelection)
          }) {
            Image(nsImage: NSImage(named: NSImage.removeTemplateName)!)
          }.buttonStyle(BorderlessButtonStyle()).frame(width: 20, height: 20).keyboardShortcut(
            .delete)
          Divider()
          Spacer()
          Button(
            "Scan",
            action: {
              isScanning = true
              Task {
                for dir in directories {
                  if scan_directory(dir, databasePath) != 0 {
                    preconditionFailure("Some error at scanning the music files")
                  }
                }

                isScanning = false
                done = true
              }
            }
          ).disabled(directories.count == 0)
            .keyboardShortcut(.defaultAction)
            .padding()
        }.frame(height: 30)
      }.dropDestination(
        for: URL.self,
        action: { urls, _ in
          handleDroppedURLS(urls)
        })
    }
  }
}
