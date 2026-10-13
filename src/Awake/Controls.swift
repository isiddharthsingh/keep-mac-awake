import SwiftUI

struct PanelButtonStyle: ButtonStyle {
    enum Kind { case neutral, accent, destructive }

    var kind: Kind
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: kind == .neutral ? 12.5 : 13, weight: kind == .neutral ? .medium : .semibold))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, fullWidth ? 0 : 14)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: kind == .neutral ? 30 : 28)
            .background(RoundedRectangle(cornerRadius: 8).fill(background))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    private var foreground: Color {
        switch kind {
        case .neutral: .primary
        case .accent: .white
        case .destructive: .red
        }
    }

    private var background: Color {
        switch kind {
        case .neutral: Color.primary.opacity(0.07)
        case .accent: .accentColor
        case .destructive: Color.red.opacity(0.14)
        }
    }
}

/// Compact "− value +" control.
struct NumberStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus") { value = max(range.lowerBound, value - step) }
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .frame(minWidth: 20)
            stepButton("plus") { value = min(range.upperBound, value + step) }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.07)))
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 24, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}

struct StatusChip: View {
    let isOn: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isOn ? Color.green : Color.secondary.opacity(0.6))
                .frame(width: 6, height: 6)
            Text(isOn ? "On" : "Off")
        }
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(isOn ? Color.green : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(isOn ? Color.green.opacity(0.16) : Color.primary.opacity(0.06)))
    }
}

/// Full-width, menu-style row with a hover highlight, e.g. "Quit MacAwake   ⌘Q".
struct MenuRow: View {
    let title: String
    let trailing: String
    var shortcut: KeyEquivalent?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(trailing).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(hovering ? Color.primary.opacity(0.08) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut.map { KeyboardShortcut($0) })
        .padding(.horizontal, -8)
        .onHover { hovering = $0 }
    }
}
