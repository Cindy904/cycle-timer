import SwiftUI

enum VisualStyle {
    // Warm neutrals and garden greens inspired by the user's visual reference.
    static let canvas = Color(red: 0.996, green: 0.984, blue: 0.964) // #FEFBF6
    static let surface = Color.white
    static let ink = Color(red: 0.19, green: 0.24, blue: 0.18) // #303D2E
    static let buttonInk = Color(red: 0.12, green: 0.18, blue: 0.11) // #1F2E1C
    static let muted = Color(red: 0.40, green: 0.44, blue: 0.38) // #667061
    static let olive = Color(red: 0.48, green: 0.62, blue: 0.37) // #7A9E5E
    static let oliveDark = Color(red: 0.34, green: 0.47, blue: 0.26) // #577843
    static let teal = Color(red: 0.08, green: 0.66, blue: 0.61) // #14A89C
    static let sky = Color(red: 0.13, green: 0.62, blue: 0.75) // #219EBF
    static let violet = Color(red: 0.53, green: 0.40, blue: 0.87) // #8766DE
    static let honey = Color(red: 0.81, green: 0.64, blue: 0.36) // #CFA35C
    static let paleOlive = Color(red: 0.93, green: 0.96, blue: 0.89)
    static let paleTeal = Color(red: 0.88, green: 0.96, blue: 0.94)
    static let paleSky = Color(red: 0.89, green: 0.96, blue: 0.98)
    static let paleHoney = Color(red: 0.97, green: 0.94, blue: 0.88)
    static let line = Color(red: 0.90, green: 0.85, blue: 0.77) // #E6D9C4
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = VisualStyle.olive

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(VisualStyle.buttonInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SoftCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .background(VisualStyle.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(VisualStyle.line, lineWidth: 1))
            .shadow(color: VisualStyle.ink.opacity(0.035), radius: 7, y: 3)
    }
}

struct AppPageHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(VisualStyle.ink)
            .padding(.top, 8)
    }
}

enum IllustrationMood {
    case welcome
    case active
    case interval
    case completed
}

/// Original shapes drawn in SwiftUI so the app stays sharp at every iPhone size.
struct FlatIllustration: View {
    let mood: IllustrationMood

    private var base: Color {
        switch mood {
        case .welcome: VisualStyle.paleOlive
        case .active: VisualStyle.paleTeal
        case .interval: VisualStyle.paleHoney
        case .completed: VisualStyle.paleOlive
        }
    }

    private var accent: Color {
        switch mood {
        case .welcome, .completed: VisualStyle.olive
        case .active: VisualStyle.teal
        case .interval: VisualStyle.honey
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous).fill(base)
                Circle().fill(.white.opacity(0.52)).frame(width: w * 0.45).offset(x: w * 0.31, y: -h * 0.26)
                Circle().fill(accent.opacity(0.26)).frame(width: w * 0.2).offset(x: -w * 0.37, y: h * 0.27)

                // A quiet oversized clock anchors the illustration without setting a usage category.
                Circle()
                    .fill(.white)
                    .frame(width: min(w, h) * 0.66)
                    .overlay(Circle().stroke(accent.opacity(0.18), lineWidth: 12))
                    .offset(x: w * 0.23, y: h * 0.05)
                Capsule().fill(accent).frame(width: 7, height: h * 0.16)
                    .rotationEffect(.degrees(28)).offset(x: w * 0.23, y: -h * 0.01)
                Capsule().fill(accent).frame(width: 6, height: h * 0.12)
                    .rotationEffect(.degrees(-60)).offset(x: w * 0.29, y: h * 0.08)
                Circle().fill(accent).frame(width: 12).offset(x: w * 0.23, y: h * 0.05)

                // Geometric person, composed of filled blocks with no character outline.
                Capsule().fill(VisualStyle.ink).frame(width: w * 0.32, height: h * 0.095)
                    .rotationEffect(.degrees(-33)).offset(x: -w * 0.10, y: h * 0.25)
                Capsule().fill(VisualStyle.ink).frame(width: w * 0.29, height: h * 0.09)
                    .rotationEffect(.degrees(36)).offset(x: -w * 0.26, y: h * 0.24)
                RoundedRectangle(cornerRadius: 20).fill(accent)
                    .frame(width: w * 0.22, height: h * 0.29)
                    .rotationEffect(.degrees(-13)).offset(x: -w * 0.18, y: -h * 0.01)
                Capsule().fill(Color(red: 0.98, green: 0.72, blue: 0.58))
                    .frame(width: w * 0.30, height: h * 0.075)
                    .rotationEffect(.degrees(-28)).offset(x: -w * 0.04, y: h * 0.01)
                Circle().fill(Color(red: 0.98, green: 0.72, blue: 0.58))
                    .frame(width: h * 0.20).offset(x: -w * 0.18, y: -h * 0.23)
                Ellipse().fill(VisualStyle.ink)
                    .frame(width: h * 0.22, height: h * 0.12)
                    .rotationEffect(.degrees(-17)).offset(x: -w * 0.20, y: -h * 0.30)

                Image(systemName: mood == .completed ? "sparkle" : "arrow.triangle.2.circlepath")
                    .font(.system(size: max(18, w * 0.075), weight: .bold))
                    .foregroundStyle(accent)
                    .offset(x: w * 0.37, y: -h * 0.29)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}
