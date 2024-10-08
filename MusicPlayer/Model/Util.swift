import Foundation

public func formatTime(_ seconds: UInt) -> String {
  let hours = seconds / 3600
  let minutes = (seconds % 3600) / 60
  let remainingSeconds = seconds % 60

  if hours > 0 {
    return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
  } else {
    return String(format: "%02d:%02d", minutes, remainingSeconds)
  }
}

public let appName = "MusicPlayer"
public let databasePath = try! FileManager.default.url(
  for: .cachesDirectory,
  in: .userDomainMask,
  appropriateFor: nil,
  create: false
)
.appending(components: String(describing: appName), "data").appendingPathExtension(
  "db"
)
.path(percentEncoded: false)
