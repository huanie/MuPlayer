//
//  DetailView.swift
//  MuPlayer
//
//  Created by Huan Thieu Nguyen on 17.04.25.
//

import SwiftUI

struct DetailView<Content: View, Empty: View>: View {
    let content: AnyView
    init(
        isMain: Bool,
        @ViewBuilder main: () -> Content,
        @ViewBuilder empty: () -> Empty
    ) {
        if isMain {
            self.content = AnyView(main())
        } else {
            self.content = AnyView(empty())
        }
    }
    var body: some View {
        content
    }
}
