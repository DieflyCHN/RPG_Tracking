//
//  WheelComponents.swift
//  RPG Tracking
//  暂时放弃使用（保留以便后续对比或回滚）
//

import SwiftUI

struct WheelDecimalRow: View {
    let title: String
    let wholeRange: ClosedRange<Int>
    @Binding var whole: Int
    @Binding var fraction: Int
    private let pickerScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            HStack(spacing: 4) {
                Picker("", selection: $whole) {
                    ForEach(Array(wholeRange), id: \.self) { value in
                        Text("\(value)")
                            .font(.system(size: 14))
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 60, height: 36)
                .scaleEffect(pickerScale)
                .clipped()

                Text(".")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)
                    .frame(width: 10)
                    .zIndex(1)

                Picker("", selection: $fraction) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)")
                            .font(.system(size: 14))
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 50, height: 36)
                .scaleEffect(pickerScale)
                .clipped()
            }
        }
    }
}

struct WheelTwoDecimalRow: View {
    let title: String
    let wholeRange: ClosedRange<Int>
    @Binding var whole: Int
    @Binding var tenth: Int
    @Binding var hundredth: Int
    private let pickerScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            HStack(spacing: 4) {
                Picker("", selection: $whole) {
                    ForEach(Array(wholeRange), id: \.self) { value in
                        Text("\(value)")
                            .font(.system(size: 14))
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 60, height: 36)
                .scaleEffect(pickerScale)
                .clipped()

                Text(".")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)
                    .frame(width: 10)
                    .zIndex(1)

                Picker("", selection: $tenth) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)")
                            .font(.system(size: 14))
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 50, height: 36)
                .scaleEffect(pickerScale)
                .clipped()

                Picker("", selection: $hundredth) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)")
                            .font(.system(size: 14))
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 50, height: 36)
                .scaleEffect(pickerScale)
                .clipped()
            }
        }
    }
}

struct BaseValueWheelRow: View {
    let title: String
    @Binding var whole: Int
    @Binding var fraction: Int
    private let pickerScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            HStack(spacing: 4) {
                Picker("", selection: $whole) {
                    ForEach(1...10, id: \.self) { value in
                        Text("\(value)")
                            .font(.system(size: 14))
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 60, height: 36)
                .scaleEffect(pickerScale)
                .clipped()

                Text(".")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)
                    .frame(width: 10)
                    .zIndex(1)

                Picker("", selection: $fraction) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)")
                            .font(.system(size: 14))
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 50, height: 36)
                .scaleEffect(pickerScale)
                .clipped()
            }
        }
    }
}

struct WheelIntRow: View {
    let title: String
    let range: ClosedRange<Int>
    @Binding var value: Int
    private let pickerScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            Picker("", selection: $value) {
                ForEach(Array(range), id: \.self) { item in
                    Text("\(item)")
                        .font(.system(size: 14))
                        .tag(item)
                }
            }
            .pickerStyle(.wheel)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(width: 90, height: 36)
            .scaleEffect(pickerScale)
            .clipped()
        }
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
