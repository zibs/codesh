import AppKit
import SwiftUI

struct ColorPreferencesView: View {
    private let settings = SettingsStore.shared
    private let onChange: () -> Void

    @State private var sessionLight: Color
    @State private var sessionDark: Color
    @State private var weeklyLight: Color
    @State private var weeklyDark: Color

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        let settings = SettingsStore.shared
        _sessionLight = State(
            initialValue: Color(nsColor: settings.color(for: .sessionLight) ?? SettingsStore.defaultSessionLightColor)
        )
        _sessionDark = State(
            initialValue: Color(nsColor: settings.color(for: .sessionDark) ?? SettingsStore.defaultSessionDarkColor)
        )
        _weeklyLight = State(
            initialValue: Color(nsColor: settings.color(for: .weeklyLight) ?? SettingsStore.defaultWeeklyLightColor)
        )
        _weeklyDark = State(
            initialValue: Color(nsColor: settings.color(for: .weeklyDark) ?? SettingsStore.defaultWeeklyDarkColor)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status Bar Colors")
                .font(.headline)

            GroupBox("Session (left)") {
                VStack(alignment: .leading, spacing: 8) {
                    ColorPicker("Light Mode", selection: $sessionLight, supportsOpacity: false)
                    ColorPicker("Dark Mode", selection: $sessionDark, supportsOpacity: false)
                }
                .padding(.top, 4)
            }

            GroupBox("Weekly (right)") {
                VStack(alignment: .leading, spacing: 8) {
                    ColorPicker("Light Mode", selection: $weeklyLight, supportsOpacity: false)
                    ColorPicker("Dark Mode", selection: $weeklyDark, supportsOpacity: false)
                }
                .padding(.top, 4)
            }

            HStack {
                Spacer()
                Button("Reset Defaults") {
                    resetDefaults()
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .onChange(of: sessionLight) {
            store(sessionLight, role: .sessionLight)
        }
        .onChange(of: sessionDark) {
            store(sessionDark, role: .sessionDark)
        }
        .onChange(of: weeklyLight) {
            store(weeklyLight, role: .weeklyLight)
        }
        .onChange(of: weeklyDark) {
            store(weeklyDark, role: .weeklyDark)
        }
    }

    private func store(_ color: Color, role: SettingsStore.ColorRole) {
        settings.setColor(NSColor(color), for: role)
        onChange()
    }

    private func resetDefaults() {
        settings.resetColorsToDefaults()
        sessionLight = Color(nsColor: SettingsStore.defaultSessionLightColor)
        sessionDark = Color(nsColor: SettingsStore.defaultSessionDarkColor)
        weeklyLight = Color(nsColor: SettingsStore.defaultWeeklyLightColor)
        weeklyDark = Color(nsColor: SettingsStore.defaultWeeklyDarkColor)
        onChange()
    }
}
