//
//  Model.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 06.04.25.
//

import Foundation
import GRDB
import SFBAudioEngine

protocol ModelType {
    var id: Int64 { get }
}

enum Model {
    struct Song: Codable, PersistableRecord, FetchableRecord, ModelType,
        TableRecord, Equatable, Identifiable, Hashable
    {
        let path: URL
        let directory: URL
        let songTitle: String
        let artistName: String
        let albumTitle: String
        let duration: Double
        let trackNumber: Int
        let discNumber: Int
        let modifiedStamp: Date
        var rowid: Int64! = nil
        var id: Int64 { rowid }

        static var databaseSelection: [any SQLSelectable] {
            [.allColumns, .rowID]
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.rowid == rhs.rowid
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(rowid)
        }
    }
    struct Directory: Codable, PersistableRecord, FetchableRecord, ModelType,
        Hashable
    {
        let path: URL
        let modifiedStamp: Date
        var rowid: Int64! = nil
        var id: Int64 { rowid }
        static var databaseSelection: [any SQLSelectable] {
            [.allColumns, .rowID]
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(rowid)
        }
    }
    struct Artist: Codable, PersistableRecord, FetchableRecord, ModelType {
        let name: String
        var rowid: Int64! = nil
        var id: Int64 { rowid }
        static var databaseSelection: [any SQLSelectable] {
            [.allColumns, .rowID]
        }
    }
    struct Album: Codable, PersistableRecord, FetchableRecord, ModelType,
        Hashable, Identifiable
    {
        let title: String
        let artist: String
        var rowid: Int64! = nil
        var id: Int64 { rowid }
        static var databaseSelection: [any SQLSelectable] {
            [.allColumns, .rowID]
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(rowid)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.rowid == rhs.rowid
        }
    }

    static func writeSchema(_ db: Database) throws {
        try db.create(
            table: "directory",
            options: [.ifNotExists]
        ) { t in
            t.column("path", .text).primaryKey()
            t.column("modifiedStamp", .datetime).notNull()
        }
        try db.create(table: "artist", options: [.ifNotExists]) {
            t in
            t.column("name", .text).primaryKey()
        }
        try db.create(table: "album", options: [.ifNotExists]) {
            t in
            t.primaryKey {
                t.column("title", .text)
                t.column("artist", .text)
            }
            t.foreignKey(
                ["artist"],
                references: "artist",
                columns: ["name"],
                onDelete: .cascade,
                onUpdate: .cascade
            )
        }
        try db.create(table: "song", options: [.ifNotExists]) {
            t in
            t.column("path", .text).primaryKey()
            t.column("directory", .text).notNull()
            t.column("songTitle", .text).notNull()
            t.column("artistName", .text).notNull()
            t.column("albumTitle", .text).notNull()
            t.column("duration", .double).notNull()
            t.column("trackNumber", .integer)
            t.column("discNumber", .integer)
            t.column("modifiedStamp", .datetime)

            t.foreignKey(
                ["albumTitle", "artistName"],
                references: "album",
                columns: ["title", "artist"],
                onDelete: .cascade,
                onUpdate: .cascade
            )
            t.foreignKey(
                ["directory"],
                references: "directory",
                columns: ["path"],
                onDelete: .cascade,
                onUpdate: .cascade
            )
        }

        try db.execute(
            sql: #"""
                CREATE VIRTUAL TABLE IF NOT EXISTS songSearch USING FTS5 (
                title,
                artistName,
                albumTitle,
                path UNINDEXED,
                tokenize="trigram"
                )
                """#
        )

    }
}
