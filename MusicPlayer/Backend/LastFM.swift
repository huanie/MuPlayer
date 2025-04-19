import BTree
import CryptoKit
import Foundation

public enum LastFM {
  private static let API_PATH = "http://ws.audioscrobbler.com/2.0/"
  private static let queue = DispatchQueue(label: "nowPlaying.queue", qos: .background)
  @MainActor
  static public func scrobble(_ song: borrowing Song) {
    if Storage.shared.apiSession.isEmpty {
      return
    }
    let request = withSignature(
      Map<String, String>(
        dictionaryLiteral: ("artist[0]", song.artistName),
        ("method", "track.scrobble"),
        ("track[0]", song.songTitle),
        ("album[0]", song.albumTitle),
        ("albumArtist[0]", song.albumArtist),
        ("trackNumber[0]", String(song.trackNumber)),
        ("duration[0]", String(song.duration)),
        ("timestamp[0]", String(UInt(Date().timeIntervalSince1970) - song.duration)),
        ("api_key", API_KEY),
        ("sk", Storage.shared.apiSession)
      ),
      secret: API_SECRET
    )
    URLSession.shared.dataTask(with: request) { data, response, error in
      guard data != nil, error == nil else {
        print("Error: \(error?.localizedDescription ?? "Unknown error")")
        return
      }
      //print(String(data: x, encoding: .utf8))
    }
    .resume()
  }
  @MainActor
  static public func updateNowPlaying(_ song: borrowing Song) {
    if Storage.shared.apiSession.isEmpty {
      return
    }
    let request = withSignature(
      Map<String, String>(
        dictionaryLiteral: ("artist", song.artistName),
        ("method", "track.updateNowPlaying"),
        ("track", song.songTitle),
        ("album", song.albumTitle),
        ("albumArtist", song.albumArtist),
        ("trackNumber", String(song.trackNumber)),
        ("duration", String(song.duration)),
        ("api_key", API_KEY),
        ("sk", Storage.shared.apiSession)
      ),
      secret: API_SECRET
    )
    URLSession.shared.dataTask(with: request) { data, response, error in
      guard data != nil, error == nil else {
        print("Error: \(error?.localizedDescription ?? "Unknown error")")
        return
      }
      //print(String(data: x, encoding: .utf8))
    }
    .resume()
  }
  static private func withSignature(
    _ parameters: consuming Map<String, String>, secret: borrowing String
  ) -> URLRequest {
    var url = URLComponents(string: API_PATH)!
    var urlParameters = parameters.map {
      URLQueryItem(name: $0.0, value: $0.1)
    }
    var signature = parameters.reduce(into: String()) { (accum, next) in
      if next.0 == "format" {
        return
      }
      accum.append(next.0)
      accum.append(next.1)
    }
    signature.append(secret)
    let md5 = Insecure.MD5.hash(data: Data(signature.utf8)).map {
      String(format: "%02hhx", $0)
    }.joined()

    urlParameters.append(
      URLQueryItem(
        name: "api_sig",
        value: md5))
    url.queryItems = urlParameters
    var request = URLRequest(url: url.url!)
    request.httpMethod = "POST"
    return request
  }
  static public func authenticate(
    username: String, password: String,
    errorCallback: @Sendable @escaping (String) -> Void,
    successCallback: @Sendable @escaping (String) -> Void
  ) {
    let request = withSignature(
      Map<String, String>(
        dictionaryLiteral: ("method", "auth.getMobileSession"),
        ("api_key", API_KEY),
        ("format", "json"),
        ("password", password),
        ("username", username)
      ), secret: API_SECRET)

    URLSession.shared.dataTask(with: request) { data, response, error in
      guard let data = data, error == nil else {
        print("error")
        errorCallback(
          "Error: \(error?.localizedDescription ?? "Unknown error")")
        return
      }

      if let jsonString = String(data: data, encoding: .utf8) {
        let regex = /"key"\s*:\s*"(.+?)",/
        if let match = try! regex.firstMatch(in: jsonString) {
          successCallback(String(match.1))
        } else {
          errorCallback(jsonString)
        }
      }
    }
    .resume()
  }
}
