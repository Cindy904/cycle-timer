import SwiftUI

struct TimerScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var confirmsEnd = false
    @State private var displayMode: TimerDisplayMode = .clock
    @State private var preparationEndsAt = Date().addingTimeInterval(3)
    @State private var isStarting = false
    @State private var startFailed = false
    @State private var replayProject: TimerProject?
    @State private var preparationRound = 0
    let startingProject: TimerProject?
    let close: () -> Void

    var body: some View {
        Group {
            if let session = store.activeSession,
               let plan = store.currentPlan,
               let progress = store.progress {
                if session.status == .completed || session.status == .endedEarly {
                    result(session: session, plan: plan, progress: progress)
                } else {
                    running(session: session, plan: plan, progress: progress)
                }
            } else if startFailed || (startingProject == nil && replayProject == nil) {
                startError
            } else {
                preparation
            }
        }
        .task(id: preparationRound) {
            guard let project = replayProject ?? startingProject, store.activeSession == nil else { return }
            preparationEndsAt = Date().addingTimeInterval(3)
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            isStarting = true
            await store.start(project)
            if store.activeSession == nil { startFailed = true }
        }
        .confirmationDialog("结束本次计时？", isPresented: $confirmsEnd) {
            Button("结束并保存进度", role: .destructive) { store.endEarly() }
            Button("继续计时") { store.resume() }
            Button("保持暂停", role: .cancel) { }
        } message: {
            Text("已经完成的计时段会保留。")
        }
    }

    private var startError: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.clock")
                .font(.system(size: 42))
                .foregroundStyle(VisualStyle.oliveDark)
            Text("计时未能开始")
                .font(.title2.bold())
                .foregroundStyle(VisualStyle.ink)
            Text(store.notice ?? "请返回设置页重试。")
                .font(.subheadline)
                .foregroundStyle(VisualStyle.muted)
            Button("返回首页", action: close)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 10)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualStyle.canvas.ignoresSafeArea())
    }

    private var preparation: some View {
        VStack(spacing: 22) {
            HStack {
                Button("取消") { close() }
                    .foregroundStyle(VisualStyle.muted)
                Spacer()
            }
            Spacer()
            Text("准备开始")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(VisualStyle.ink)
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                Text(isStarting ? "开始" : "\(max(1, Int(ceil(preparationEndsAt.timeIntervalSince(context.date)))))")
                    .font(.system(size: 108, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(VisualStyle.oliveDark)
                    .frame(height: 140)
            }
            Text("计时将在 3 秒后开始")
                .font(.subheadline)
                .foregroundStyle(VisualStyle.muted)
            Spacer()
        }
        .padding(25)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualStyle.canvas.ignoresSafeArea())
    }

    private func running(session: TimerSession, plan: TimerPlan, progress: SessionProgress) -> some View {
        let segment = progress.currentSegmentIndex.map { plan.segments[$0] }
        let isSavedProject = store.projects.contains { $0.id == session.project.id }
        return GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack {
                    if isSavedProject {
                        Text(session.project.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(VisualStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(VisualStyle.surface, in: Capsule())
                            .overlay(Capsule().stroke(VisualStyle.line, lineWidth: 1))
                            .padding(.horizontal, 60)
                            .frame(maxWidth: .infinity)
                    }
                    HStack {
                        Button(action: close) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(VisualStyle.ink)
                                .frame(width: 44, height: 44)
                                .background(VisualStyle.surface, in: Circle())
                                .overlay(Circle().stroke(VisualStyle.line, lineWidth: 1))
                        }
                        .accessibilityLabel("返回首页，计时继续")
                        Spacer()
                        if segment?.kind == .focus {
                            Button {
                                displayMode = displayMode == .clock ? .digital : .clock
                            } label: {
                                Image(systemName: displayMode == .clock ? "number" : "clock")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(VisualStyle.oliveDark)
                                    .frame(width: 44, height: 44)
                                    .background(VisualStyle.surface, in: Circle())
                                    .overlay(Circle().stroke(VisualStyle.line, lineWidth: 1))
                            }
                            .accessibilityLabel(displayMode == .clock ? "切换为数字倒计时" : "切换为时钟倒计时")
                        } else {
                            Color.clear.frame(width: 44, height: 44)
                        }
                    }
                }
                .padding(.horizontal, 23)
                .padding(.top, 18)

                Spacer(minLength: 10)
                Group {
                    if segment?.kind == .interval {
                        RestMeditationView()
                            .frame(height: min(geo.size.height * 0.32, 255))
                            .padding(.horizontal, 23)
                    } else if displayMode == .clock {
                        AnalogCountdownView(
                            remaining: progress.remainingSegmentSeconds,
                            duration: segment?.durationSeconds ?? 1,
                            accent: VisualStyle.olive
                        )
                        .frame(width: min(geo.size.width * 0.68, 270), height: min(geo.size.width * 0.68, 270))
                    } else {
                        Text(TimerFormat.clock(progress.remainingSegmentSeconds))
                            .font(.system(size: min(geo.size.width * 0.2, 82), weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(VisualStyle.ink)
                            .contentTransition(.numericText())
                            .frame(height: min(geo.size.width * 0.68, 270))
                    }
                }
                .accessibilityLabel("剩余 \(TimerFormat.readable(progress.remainingSegmentSeconds))")
                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    Text(session.status == .paused ? "已暂停" : segment?.kind == .interval ? "休息中" : "计时中")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(segment?.kind == .interval ? VisualStyle.teal : VisualStyle.olive)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(segment?.kind == .interval ? VisualStyle.paleTeal : VisualStyle.paleOlive, in: Capsule())
                    if segment?.kind == .focus, let title = segment?.title, title != "计时" {
                        Text(title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(VisualStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if displayMode == .clock || segment?.kind == .interval {
                        Text(TimerFormat.clock(progress.remainingSegmentSeconds))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(VisualStyle.ink)
                    }
                }
                .padding(.horizontal, 22)

                Spacer(minLength: 12)
                VStack(spacing: 14) {
                    if let notice = store.notice {
                        Text(notice)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(VisualStyle.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(VisualStyle.paleHoney, in: RoundedRectangle(cornerRadius: 12))
                            .onTapGesture { store.notice = nil }
                    }
                    GeometryReader { bar in
                        Capsule().fill(VisualStyle.line)
                            .overlay(alignment: .leading) {
                                Capsule().fill(VisualStyle.olive)
                                    .frame(width: bar.size.width * min(1, progress.elapsedSeconds / Double(max(1, plan.totalSeconds))))
                            }
                    }
                    .frame(height: 7)
                    HStack {
                        Text("已完成 \(progress.completedFocusCount)/\(plan.focusCount) 个计时段")
                        Spacer()
                        Text("总剩余 \(TimerFormat.clock(progress.remainingTotalSeconds))")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VisualStyle.muted)

                    if let next = progress.currentSegmentIndex.flatMap({ $0 + 1 < plan.segments.count ? plan.segments[$0 + 1] : nil }) {
                        HStack {
                            Image(systemName: "arrow.turn.down.right")
                            Text("下一步：\(next.kind == .interval ? "休息" : next.title)")
                            Spacer()
                            Text(TimerFormat.clock(next.durationSeconds))
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VisualStyle.ink)
                        .padding(16)
                        .background(VisualStyle.surface, in: RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).stroke(VisualStyle.line, lineWidth: 1))
                    }

                    Button {
                        if session.status == .paused { store.resume() } else { store.pause() }
                    } label: {
                        Label(session.status == .paused ? "继续" : "暂停",
                              systemImage: session.status == .paused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: segment?.kind == .interval ? VisualStyle.teal : VisualStyle.olive))

                    Button("结束本次计时") {
                        if session.status == .running { store.pause() }
                        confirmsEnd = true
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(VisualStyle.muted)
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 23)
                .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VisualStyle.canvas.ignoresSafeArea())
        }
    }

    private func result(session: TimerSession, plan: TimerPlan, progress: SessionProgress) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Group {
                if session.status == .completed {
                    CompletionHero()
                } else {
                    EarlyEndHero()
                }
            }
                .frame(height: 215)
                .padding(.horizontal, 27)
            Text(session.status == .completed ? "任务达成！" : "本次已结束")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(VisualStyle.ink)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            Text(session.project.title)
                .font(.headline)
                .foregroundStyle(VisualStyle.muted)
            SoftCard {
                VStack(spacing: 17) {
                    resultRow("完成计时段", "\(progress.completedFocusCount) / \(plan.focusCount)")
                    resultRow("完成次数", "\(progress.completedProjectLoops) / \(session.project.repetitions)")
                    resultRow("有效计时", TimerFormat.readable(progress.focusElapsedSeconds))
                    resultRow("间隔时间", TimerFormat.readable(progress.intervalElapsedSeconds))
                }
            }
            .padding(.horizontal, 24)
            Spacer()
            Button("再来一次") {
                store.closeResult()
                replayProject = session.project
                preparationEndsAt = Date().addingTimeInterval(3)
                isStarting = false
                startFailed = false
                preparationRound += 1
            }
            .buttonStyle(PrimaryButtonStyle(color: VisualStyle.teal))
            .padding(.horizontal, 24)
            Button("返回项目") {
                store.closeResult()
                close()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(VisualStyle.muted)
            .padding(.horizontal, 24)
            .padding(.bottom, 27)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualStyle.canvas.ignoresSafeArea())
        .overlay {
            if session.status == .completed {
                StarBurstView()
                    .allowsHitTesting(false)
            }
        }
    }

    private func resultRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(VisualStyle.muted)
            Spacer()
            Text(value).fontWeight(.bold).foregroundStyle(VisualStyle.ink)
        }
        .font(.system(size: 15))
    }
}

private enum TimerDisplayMode {
    case clock
    case digital
}

private struct AnalogCountdownView: View {
    let remaining: Int
    let duration: Int
    let accent: Color

    private var fraction: Double { min(1, max(0, Double(remaining) / Double(max(1, duration)))) }

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(VisualStyle.surface)
                Circle().stroke(VisualStyle.line, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                ForEach(0..<60, id: \.self) { tick in
                    Capsule()
                        .fill(tick.isMultiple(of: 5) ? VisualStyle.ink : VisualStyle.line)
                        .frame(width: tick.isMultiple(of: 5) ? 3 : 1, height: tick.isMultiple(of: 5) ? 14 : 7)
                        .offset(y: -diameter * 0.39)
                        .rotationEffect(.degrees(Double(tick) * 6))
                }
                Capsule()
                    .fill(VisualStyle.ink)
                    .frame(width: 5, height: diameter * 0.29)
                    .offset(y: -diameter * 0.145)
                    .rotationEffect(.degrees(-360 * (1 - fraction)))
                Circle().fill(accent).frame(width: 15, height: 15)
            }
            .frame(width: diameter, height: diameter)
            .shadow(color: VisualStyle.ink.opacity(0.05), radius: 12, y: 5)
        }
    }
}

private struct RestMeditationView: View {
    var body: some View {
        Image("RestMeditation")
            .resizable()
            .scaledToFit()
            .accessibilityLabel("休息，人物正在放松打坐")
    }
}

private struct CompletionHero: View {
    var body: some View {
        Image("CompletionCelebrate")
            .resizable()
            .scaledToFit()
            .accessibilityLabel("庆祝任务达成的人物插画")
    }
}

private struct EarlyEndHero: View {
    var body: some View {
        Image("EarlyEndReflect")
            .resizable()
            .scaledToFit()
            .accessibilityLabel("提前结束时安静思考的人物插画")
    }
}

private struct StarBurstView: View {
    @State private var exploded = false
    @State private var faded = false
    @State private var stars: [FlyingStar]
    private let previewExpanded: Bool
    private let colors: [Color] = [
        VisualStyle.teal, VisualStyle.olive, VisualStyle.honey,
        VisualStyle.sky, VisualStyle.violet,
        Color(red: 0.98, green: 0.48, blue: 0.39)
    ]

    init(previewExpanded: Bool = false) {
        self.previewExpanded = previewExpanded
        _exploded = State(initialValue: previewExpanded)
        _stars = State(initialValue: (0..<88).map(FlyingStar.init))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(stars) { star in
                    particle(star, in: geometry.size)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .task {
            guard !previewExpanded else { return }
            exploded = true
            try? await Task.sleep(for: .seconds(1.85))
            guard !Task.isCancelled else { return }
            faded = true
        }
    }

    private func particle(_ star: FlyingStar, in size: CGSize) -> some View {
        Image(systemName: star.isSparkle ? "sparkle" : "star.fill")
            .font(.system(size: star.size))
            .foregroundStyle(colors[star.colorIndex])
            .scaleEffect(exploded ? 1 : 0.12)
            .rotationEffect(.degrees(exploded ? star.rotation : 0))
            .opacity(faded ? 0 : 1)
            .position(
                x: size.width * (0.5 + (exploded ? star.dx : star.startX)),
                y: size.height * (0.5 + (exploded ? star.dy : star.startY))
            )
            .animation(.easeOut(duration: star.flightDuration).delay(star.launchDelay), value: exploded)
            .animation(.easeOut(duration: star.fadeDuration).delay(star.fadeDelay), value: faded)
    }

    private struct FlyingStar: Identifiable {
        let id: Int
        let dx: CGFloat
        let dy: CGFloat
        let startX: CGFloat
        let startY: CGFloat
        let size: CGFloat
        let rotation: Double
        let flightDuration: Double
        let launchDelay: Double
        let fadeDelay: Double
        let fadeDuration: Double
        let colorIndex: Int
        let isSparkle: Bool

        init(_ index: Int) {
            id = index
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = Double.random(in: 0.12...1.15)
            dx = CGFloat(cos(angle) * distance * Double.random(in: 0.56...0.76))
            dy = CGFloat(sin(angle) * distance * Double.random(in: 0.56...0.76))
            startX = CGFloat.random(in: -0.025...0.025)
            startY = CGFloat.random(in: -0.012...0.012)
            size = CGFloat.random(in: 9...24)
            rotation = Double.random(in: -220...220)
            flightDuration = Double.random(in: 0.75...1.5)
            launchDelay = Double.random(in: 0...0.22)
            fadeDelay = Double.random(in: 0...1.8)
            fadeDuration = Double.random(in: 0.55...1.05)
            colorIndex = Int.random(in: 0..<6)
            isSparkle = Bool.random()
        }
    }
}

#Preview("圆形倒计时") {
    AnalogCountdownView(remaining: 45, duration: 60, accent: VisualStyle.olive)
        .frame(width: 270, height: 270)
        .padding(30)
        .background(VisualStyle.canvas)
}

#Preview("启动流程") {
    TimerScreen(startingProject: .singleStep(), close: {})
        .environmentObject(AppStore())
}

#Preview("休息插画") {
    ZStack {
        VisualStyle.canvas.ignoresSafeArea()
        RestMeditationView()
            .frame(height: 255)
            .padding(24)
    }
}

#Preview("完成插画") {
    ZStack {
        VisualStyle.canvas.ignoresSafeArea()
        CompletionHero()
            .frame(height: 215)
            .padding(24)
    }
}

#Preview("全屏星星") {
    VisualStyle.canvas.ignoresSafeArea()
        .overlay { StarBurstView(previewExpanded: true) }
}

#Preview("星星渐隐") {
    VisualStyle.canvas.ignoresSafeArea()
        .overlay { StarBurstView() }
}
