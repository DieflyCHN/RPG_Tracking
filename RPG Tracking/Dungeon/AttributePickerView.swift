//
//  AttributePickerView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI
import SwiftData

struct AttributePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AttributeGroup.name) private var groups: [AttributeGroup]

    var onSelect: (RPGAttribute) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section(group.name) {
                        let items = group.entries.sorted(by: { $0.name < $1.name })
                        if items.isEmpty {
                            Text("暂无属性")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(items) { attr in
                                Button {
                                    onSelect(attr)
                                    dismiss()
                                } label: {
                                    Text(attr.name)
                                }
                            }
                        }
                    }
                }

                if groups.isEmpty {
                    Text("请先创建属性")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("选择属性")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
