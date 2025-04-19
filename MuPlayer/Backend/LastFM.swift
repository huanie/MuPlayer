//
//  LastFMModel.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 19.04.25.
//

import AppKit
import BTree
import CryptoKit
import SwiftUI

private let API_PATH = "http://ws.audioscrobbler.com/2.0/"
class LastFM {
    private let defaults = UserDefaults.standard

    func scrobble(_ song: borrowing Model.Song) {
        if apiSession.isEmpty {
            return
        }
        let request = withSignature(
            Map<String, String>(
                dictionaryLiteral: ("artist[0]", song.artistName),
                ("method", "track.scrobble"),
                ("track[0]", song.songTitle),
                ("album[0]", song.albumTitle),
                ("albumArtist[0]", song.albumTitle),
                ("trackNumber[0]", String(song.trackNumber)),
                ("duration[0]", String(UInt(song.duration))),
                (
                    "timestamp[0]",
                    String(
                        UInt(Date().timeIntervalSince1970) - UInt(song.duration)
                    )
                ),
                ("api_key", Secrets.API_KEY),
                ("sk", apiSession)
            ),
            secret: Secrets.API_SECRET
        )
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard data != nil, error == nil else {
                print(
                    "Error: \(error?.localizedDescription ?? "Unknown error")"
                )
                return
            }
        }
        .resume()
    }

    func updateNowPlaying(_ song: borrowing Model.Song) {
        if apiSession.isEmpty {
            return
        }
        let request = withSignature(
            Map<String, String>(
                dictionaryLiteral: ("artist", song.artistName),
                ("method", "track.updateNowPlaying"),
                ("track", song.songTitle),
                ("album", song.albumTitle),
                ("albumArtist", song.artistName),
                ("trackNumber", String(song.trackNumber)),
                ("duration", String(UInt(song.duration))),
                ("api_key", Secrets.API_KEY),
                ("sk", apiSession)
            ),
            secret: Secrets.API_SECRET
        )
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard data != nil, error == nil else {
                print(
                    "Error: \(error?.localizedDescription ?? "Unknown error")"
                )
                return
            }
        }
        .resume()
    }

    func authenticate(
        username: String,
        password: String,
        /// error message
        errorCallback: @Sendable @escaping (String) -> Void,
        /// api session key
        successCallback: @Sendable @escaping (String) -> Void
    ) {
        let request = withSignature(
            Map<String, String>(
                dictionaryLiteral: ("method", "auth.getMobileSession"),
                ("api_key", Secrets.API_KEY),
                ("format", "json"),
                ("password", password),
                ("username", username)
            ),
            secret: Secrets.API_SECRET
        )

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                errorCallback(
                    "Error: \(error?.localizedDescription ?? "Unknown error")"
                )
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

    private func withSignature(
        _ parameters: consuming Map<String, String>,
        secret: borrowing String
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
                value: md5
            )
        )
        url.queryItems = urlParameters
        var request = URLRequest(url: url.url!)
        request.httpMethod = "POST"

        return request
    }

    var apiSession: String {
        get { defaults.string(forKey: "lastFMAPISession") ?? "" }
        set { defaults.set(newValue, forKey: "lastFMAPISession") }
    }

    var username: String {
        get { defaults.string(forKey: "lastFMUsername") ?? "" }
        set { defaults.set(newValue, forKey: "lastFMUsername") }
    }

    var password: String {
        get { defaults.string(forKey: "lastFMPassword") ?? "" }
        set { defaults.set(newValue, forKey: "lastFMPassword") }
    }

    enum VerificationState: Int {
        case none, verified
    }

    var isVerified: VerificationState {
        get {
            VerificationState(
                rawValue: defaults.integer(forKey: "lastFMisVerified")
            ) ?? .none
        }
        set { defaults.set(newValue, forKey: "lastFMisVerified") }
    }
}
