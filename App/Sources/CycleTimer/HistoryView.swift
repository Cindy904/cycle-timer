import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore

    private var totalSeconds: Int { store.records.reduce(0) { $0 + $1.focusElapsedSeconds } }
    private var completedProjects: Int { store.records.filter { $0.status == .completed }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AppPageHeading(title: "历史记录")
                    HStack(spacing: 12) {
                        statCard("完成项目数", "\(completedProjects)", "square.stack.3d.up", VisualStyle.olive)
                        statCard("有效计时", TimerFormat.readable(totalSeconds), "timer", VisualStyle.teal)
                    }
                    if store.records.isEmpty {
                        SoftCard {
                            Text("完成一次计时后，记录会出现在这里。")
                                .foregroundStyle(VisualStyle.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    ForEach(store.records) { record in
                        SoftCard {
                            HStack(alignment: .top, spacing: 13) {
                                Image(systemName: record.status == .completed ? "checkmark.circle.fill" : "clock.fill")
                                    .font(.system(size: 23))
                                    .foregroundStyle(record.status == .completed ? VisualStyle.teal : VisualStyle.honey)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(record.project.title)
                                        .font(.headline)
                                        .foregroundStyle(VisualStyle.ink)
                                    Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(VisualStyle.muted)
                                    Text("计时段 \(record.completedFocusCount)/\(record.plannedFocusCount) · 完成次数 \(record.completedProjectLoops)/\(record.plannedProjectLoops)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(VisualStyle.muted)
                                }
                                Spacer()
                                Text(TimerFormat.clock(record.focusElapsedSeconds))
                                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                                    .foregroundStyle(VisualStyle.ink)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 38)
            }
            .background(VisualStyle.canvas)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Color.clear.frame(width: 28, height: 28).accessibilityHidden(true)
                }
            }
        }
    }

    private func statCard(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(VisualStyle.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title).font(.caption).foregroundStyle(VisualStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(VisualStyle.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(VisualStyle.line, lineWidth: 1))
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    AppPageHeading(title: "设置")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("提醒").font(.subheadline).foregroundStyle(VisualStyle.muted)
                        SoftCard {
                            VStack(alignment: .leading, spacing: 15) {
                                Toggle("提示声音", isOn: Binding(
                                    get: { store.soundEnabled },
                                    set: { store.updateSettings(sound: $0, vibration: store.vibrationEnabled) }
                                ))
                                Divider()
                                Toggle("震动提醒", isOn: Binding(
                                    get: { store.vibrationEnabled },
                                    set: { store.updateSettings(sound: store.soundEnabled, vibration: $0) }
                                ))
                                Text("锁屏提醒受通知权限、静音与专注模式影响。")
                                    .font(.caption)
                                    .foregroundStyle(VisualStyle.muted)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("关于").font(.subheadline).foregroundStyle(VisualStyle.muted)
                        SoftCard {
                            VStack(spacing: 15) {
                                LabeledContent("应用", value: "循环计时")
                                Divider()
                                LabeledContent("版本", value: "0.1.0")
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 38)
            }
            .background(VisualStyle.canvas)
            .tint(VisualStyle.oliveDark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Color.clear.frame(width: 28, height: 28).accessibilityHidden(true)
                }
            }
        }
    }
}

#Preview("历史记录") {
    TabView {
        HistoryView()
            .tabItem { Label("记录", systemImage: "chart.bar.xaxis") }
    }
    .environmentObject(AppStore())
    .preferredColorScheme(.light)
}

#Preview("设置") {
    SettingsView()
        .environmentObject(AppStore())
        .preferredColorScheme(.light)
}
