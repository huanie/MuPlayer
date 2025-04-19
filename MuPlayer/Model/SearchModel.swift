//
//  SearchModel.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 18.04.25.
//

import AsyncAlgorithms
import SwiftUI

@Observable
class SearchModel {
    var searchQuery = ""
    @ObservationIgnored var queryChannel = AsyncChannel<String>()
    var searchResult: [Model.Song] = []
    var selectedSong: Model.Song? = nil
    
    func reset() {
        searchQuery = ""
        searchResult = []
    }
}

extension View {
    func debounce<T: Sendable & Equatable>(
        _ query: Binding<T>,
        using channel: AsyncChannel<T>,
        for duration: Duration,
        action: @Sendable @escaping (T) async -> Void
    ) -> some View {
        self
            .task {
                for await query in channel.debounce(for: duration) {
                    await action(query)
                }
            }
            .task(id: query.wrappedValue) {
                await channel.send(query.wrappedValue)
            }
    }

    func debounce<T: Sendable & Equatable>(
        _ query: Binding<T>,
        using channel: AsyncChannel<T>,
        for duration: Duration,
        action: @Sendable @escaping () async -> Void
    ) -> some View {
        self
            .task {
                for await _ in channel.debounce(for: duration) {
                    await action()
                }
            }
            .task(id: query.wrappedValue) {
                await channel.send(query.wrappedValue)
            }
    }
}
