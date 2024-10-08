import Foundation
import GRDB

struct Buffer<T: FetchableRecord & Model> {
    let database: DatabaseQueue
    let pageSize: Int
    var page = 0
    let totalSize: UInt
    let query: Statement
    private var anchors: [T]
    let anchorQuery: String

    func currentPage() throws -> [T] {
        return try self.database.read { _ in
            try T.fetchAll(
                self.query,
                arguments: [self.anchors[self.page].rowid, self.pageSize]
            )
        }
    }

    mutating func nextPage() throws -> [T] {
        if self.pageSize - 1 == self.page {
            preconditionFailure("Already on last page")
        }
        self.page += 1
        return try self.currentPage()
    }

    mutating func previousPage() throws -> [T] {
        if self.page == 0 {
            preconditionFailure("Already on first page")
        }
        self.page -= 1
        return try self.currentPage()
    }

    mutating func getPage(_ page: UInt) throws -> [T] {
        if self.anchors.count <= page {
            preconditionFailure(
                "Provided page \(page) is out of bounds of [0..\(self.pageSize)]"
            )
        }
        self.page = Int(page)
        return try self.currentPage()
    }

    init(
        databaseQueue: DatabaseQueue, pageSize: Int, totalSizeQuery: String,
        anchorQuery: String,
        fetchQuery: String
    ) throws {
        self.database = databaseQueue
        self.pageSize = pageSize
        self.anchors = []
        self.page = 0
        self.totalSize = try self.database.read {
            try (UInt.fetchOne($0, sql: totalSizeQuery)!)
        }
        self.query = try self.database.read { db in
            try db.cachedStatement(sql: fetchQuery)
        }
        self.anchorQuery = anchorQuery
        self.anchors = try self.database.read { db in
            try T.fetchAll(db, sql: anchorQuery, arguments: [self.pageSize])
        }
    }
}

public class LazyList<T: FetchableRecord & Model>: RandomAccessCollection {
    private var data: Buffer<T>
    private var buffer: [T]
    func updateBuffer(_ page: UInt) {
        self.buffer = try! self.data.getPage(page)
    }

    public subscript(position: Int) -> T {
        let requestedPage = Int(position / self.data.pageSize)
        if requestedPage != self.data.page {
            self.updateBuffer(UInt(requestedPage))
        }
        return self.buffer[position % self.data.pageSize]
    }

    public init(
        _ db: DatabaseQueue, totalSizeQuery: String, anchorQuery: String,
        fetchQuery: String
    ) {
        self.data = try! Buffer<T>(
            databaseQueue: db, pageSize: 100, totalSizeQuery: totalSizeQuery,
            anchorQuery: anchorQuery,
            fetchQuery: fetchQuery)
        self.buffer = try! self.data.currentPage()
        self.startIndex = 0
        self.endIndex = Int(self.data.totalSize - 1)
    }

    public var startIndex: Int
    public var endIndex: Int
}
