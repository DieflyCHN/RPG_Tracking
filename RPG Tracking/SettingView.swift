//
//  SettingView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI

struct SettingView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("设置")
                    .font(.title)
                    .bold()

                Spacer()

                Text("""
                     版本：v1.0.0-beta
                     日期：2026.02.03
                     """)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .safeAreaPadding(.top)
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
