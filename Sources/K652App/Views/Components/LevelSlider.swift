import SwiftUI
import K652Kit

struct LevelSlider: View {
    let title: String
    let low: String
    let high: String
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(title).frame(width: 80, alignment: .leading)
            Text(low).font(.caption).foregroundStyle(.secondary)
            Slider(value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                   in: Double(ModeSettings.levels.lowerBound)...Double(ModeSettings.levels.upperBound), step: 1)
                .frame(maxWidth: 320)
            Text(high).font(.caption).foregroundStyle(.secondary)
            Text("\(value)").monospacedDigit().frame(width: 20)
        }
    }
}
