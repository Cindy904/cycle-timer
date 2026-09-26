import SwiftUI

struct ProjectEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TimerProject
    @State private var errorMessage: String?
    private let isNew: Bool
    let onSave: (TimerProject) throws -> Void

    init(initial: TimerProject, onSave: @escaping (TimerProject) throws -> Void) {
        _draft = State(initialValue: initial)
        isNew = initial.title.isEmpty
        self.onSave = onSave
    }

    private var stepCount: Int { draft.groups.reduce(0) { $0 + $1.steps.count } }
    private var plan: TimerPlan? {
        var preview = draft
        if preview.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { preview.title = "预览" }
        return try? PlanCompiler.compile(preview)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SoftCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("项目名称")
                                .font(.system(size: 13))
                                .foregroundStyle(VisualStyle.muted)
                            TextField("例如：晨间拉伸", text: $draft.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(VisualStyle.ink)
                                .textInputAutocapitalization(.never)
                        }
                    }
                    HStack {
                        Text("步骤配置")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(VisualStyle.ink)
                        Spacer()
                        Text("\(stepCount) / \(PlanCompiler.maximumConfiguredSteps)")
                            .font(.subheadline)
                            .foregroundStyle(VisualStyle.muted)
                    }
                    if stepCount == 0 {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(VisualStyle.line, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .frame(height: 128)
                            .background(VisualStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                            .accessibilityLabel("暂无步骤")
                    }
                    ForEach(draft.groups.indices, id: \.self) { index in
                        if !draft.groups[index].steps.isEmpty {
                            SoftCard {
                                GroupEditor(group: $draft.groups[index], showGroupName: draft.groups.count > 1)
                            }
                        }
                    }
                    Button { addStep(kind: .focus) } label: {
                        Label("添加步骤", systemImage: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VisualStyle.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(VisualStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(VisualStyle.line, style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
                    }
                    .disabled(stepCount >= PlanCompiler.maximumConfiguredSteps)
                    if stepCount > 0 {
                        Button("添加循环组") {
                            draft.groups.append(TimerGroup(name: "第 \(draft.groups.count + 1) 组", steps: []))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VisualStyle.oliveDark)
                        .disabled(draft.groups.count >= PlanCompiler.maximumGroups)
                    }
                    SoftCard {
                        VStack(alignment: .leading, spacing: 15) {
                            CountInputField(title: "整套循环", value: $draft.repetitions, suffix: "遍")
                            if draft.repetitions > 1 {
                                Toggle("循环之间休息", isOn: Binding(
                                    get: { draft.loopIntervalSeconds > 0 },
                                    set: { draft.loopIntervalSeconds = $0 ? 15 : 0 }
                                ))
                                if draft.loopIntervalSeconds > 0 {
                                    WheelDurationField(title: "休息时长", seconds: $draft.loopIntervalSeconds)
                                }
                            }
                        }
                    }
                    SoftCard {
                        HStack {
                            Text("预计总时长")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(VisualStyle.ink)
                            Spacer()
                            Text(plan.map { TimerFormat.clock($0.totalSeconds) } ?? "00:00")
                                .font(.system(size: 23, weight: .bold, design: .rounded))
                                .foregroundStyle(VisualStyle.ink)
                        }
                    }
                    .background(VisualStyle.paleOlive, in: RoundedRectangle(cornerRadius: 22))
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
            .background(VisualStyle.canvas)
            .navigationTitle(isNew ? "新建项目" : "编辑项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 38, height: 38)
                            .background(VisualStyle.surface, in: Circle())
                            .overlay(Circle().stroke(VisualStyle.line, lineWidth: 1))
                    }
                    .accessibilityLabel("返回")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .fontWeight(.bold)
                }
            }
            .tint(VisualStyle.oliveDark)
            .alert("项目还不能保存", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func addStep(kind: SegmentKind) {
        guard stepCount < PlanCompiler.maximumConfiguredSteps else { return }
        if draft.groups.isEmpty { draft.groups = [TimerGroup(steps: [])] }
        let name = kind == .focus ? "步骤 \(stepCount + 1)" : "休息"
        draft.groups[draft.groups.count - 1].steps.append(TimerStep(kind: kind, name: name, durationSeconds: kind == .focus ? 30 : 15))
    }

    private func save() {
        do {
            _ = try PlanCompiler.compile(draft)
            try onSave(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct GroupEditor: View {
    @Binding var group: TimerGroup
    let showGroupName: Bool

    var body: some View {
        if showGroupName {
            TextField("组名称", text: $group.name)
                .font(.headline)
            CountInputField(title: "本组循环", value: $group.repetitions, suffix: "次")
            if group.repetitions > 1 {
                WheelDurationField(title: "组循环之间", seconds: $group.loopIntervalSeconds)
            }
        }

        ForEach(group.steps.indices, id: \.self) { index in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("步骤名称", text: $group.steps[index].name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(VisualStyle.oliveDark)
                    Spacer()
                    Menu {
                        Button("复制步骤", systemImage: "square.on.square") { duplicate(index) }
                        Button("上移", systemImage: "arrow.up") { move(index, by: -1) }
                            .disabled(index == 0)
                        Button("下移", systemImage: "arrow.down") { move(index, by: 1) }
                            .disabled(index == group.steps.count - 1)
                        Button("删除", systemImage: "trash", role: .destructive) { group.steps.remove(at: index) }
                            .disabled(group.steps.count == 1)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(VisualStyle.muted)
                    }
                }
                StepEditor(step: $group.steps[index])
            }
            .padding(.vertical, 8)
        }

    }

    private func duplicate(_ index: Int) {
        var copy = group.steps[index]
        copy.id = UUID()
        group.steps.insert(copy, at: index + 1)
    }

    private func move(_ index: Int, by offset: Int) {
        let destination = index + offset
        guard group.steps.indices.contains(destination) else { return }
        group.steps.swapAt(index, destination)
    }
}

private struct StepEditor: View {
    @Binding var step: TimerStep

    var body: some View {
        Picker("类型", selection: $step.kind) {
            Text("计时").tag(SegmentKind.focus)
            Text("间隔").tag(SegmentKind.interval)
        }
        .pickerStyle(.segmented)
        .onChange(of: step.kind) { _, kind in
            if kind == .interval {
                step.repetitions = 1
                step.repetitionIntervalSeconds = 0
            }
        }
        WheelDurationField(title: "持续时间", seconds: $step.durationSeconds)
            .padding(.top, 12)
        if step.kind == .focus {
            CountInputField(title: "重复", value: $step.repetitions, suffix: "次")
            if step.repetitions > 1 {
                Toggle("每次计时之间休息", isOn: Binding(
                    get: { step.repetitionIntervalSeconds > 0 },
                    set: { step.repetitionIntervalSeconds = $0 ? 15 : 0 }
                ))
                if step.repetitionIntervalSeconds > 0 {
                    WheelDurationField(title: "休息时长", seconds: $step.repetitionIntervalSeconds)
                }
            }
        }
    }
}

private struct WheelDurationField: View {
    let title: String
    @Binding var seconds: Int

    private var hours: Binding<Int> {
        Binding(get: { seconds / 3600 },
                set: { seconds = min(23, max(0, $0)) * 3600 + seconds % 3600 })
    }
    private var minutes: Binding<Int> {
        Binding(get: { seconds % 3600 / 60 },
                set: { seconds = seconds / 3600 * 3600 + min(59, max(0, $0)) * 60 + seconds % 60 })
    }
    private var remainingSeconds: Binding<Int> {
        Binding(get: { seconds % 60 },
                set: { seconds = seconds / 60 * 60 + min(59, max(0, $0)) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(VisualStyle.ink)
            HStack(spacing: 0) {
                column("小时", value: hours, range: 0...23)
                column("分钟", value: minutes, range: 0...59)
                column("秒", value: remainingSeconds, range: 0...59)
            }
            .frame(height: 130)
        }
    }

    private func column(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        ZStack {
            Picker(title, selection: value) {
                ForEach(range, id: \.self) { number in
                    Text("\(number)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .offset(x: -17)
                        .tag(number)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(VisualStyle.ink)
                .offset(x: 22)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .clipped()
    }
}

private struct CountInputField: View {
    let title: String
    @Binding var value: Int
    let suffix: String
    @State private var input = ""

    var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VisualStyle.ink)
            Spacer()
            TextField("次数", text: $input)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(VisualStyle.ink)
                .frame(width: 56, height: 42)
                .background(VisualStyle.paleOlive, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("\(title)次数")
                .onAppear { input = String(value) }
                .onChange(of: input) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber))
                    guard let parsed = Int(digits) else {
                        if newValue != digits { input = digits }
                        return
                    }
                    let clamped = min(8, max(1, parsed))
                    value = clamped
                    if input != String(clamped) { input = String(clamped) }
                }
                .onChange(of: value) { _, newValue in
                    if input != String(newValue) { input = String(newValue) }
                }
            Text(suffix)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VisualStyle.ink)
        }
    }
}

enum QuickTimerKind: String, Identifiable {
    case single
    case multiple

    var id: String { rawValue }
    var title: String { self == .single ? "单步骤重复" : "多步骤循环" }
}

struct QuickTimerSetup: View {
    @Environment(\.dismiss) private var dismiss
    @State private var singleSeconds = 0
    @State private var singleRepeats = 1
    @State private var steps = [
        TimerStep(name: "步骤 1", durationSeconds: 0),
        TimerStep(name: "步骤 2", durationSeconds: 0)
    ]
    @State private var cycles = 1
    @State private var hasRest: Bool
    @State private var restSeconds = 0

    let kind: QuickTimerKind
    let isBusy: Bool
    let onStart: (TimerProject) -> Void

    init(kind: QuickTimerKind, isBusy: Bool, onStart: @escaping (TimerProject) -> Void) {
        self.kind = kind
        self.isBusy = isBusy
        self.onStart = onStart
        _hasRest = State(initialValue: kind == .single)
    }

    private var project: TimerProject {
        let rest = hasRest ? restSeconds : 0
        if kind == .single {
            return TimerProject(title: kind.title, groups: [TimerGroup(steps: [
                TimerStep(name: "计时", durationSeconds: singleSeconds,
                          repetitions: singleRepeats, repetitionIntervalSeconds: rest)
            ])])
        }
        return TimerProject(title: kind.title, groups: [TimerGroup(
            repetitions: cycles,
            loopIntervalSeconds: rest,
            steps: steps
        )])
    }

    private var plan: TimerPlan? {
        let needsRestDuration = hasRest && (kind == .single ? singleRepeats > 1 : cycles > 1)
        guard !needsRestDuration || restSeconds > 0 else { return nil }
        return try? PlanCompiler.compile(project)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if kind == .single {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 19) {
                                WheelDurationField(title: "单次时长", seconds: $singleSeconds)
                                CountInputField(title: "重复", value: $singleRepeats, suffix: "次")
                            }
                        }
                    } else {
                        HStack {
                            Text("步骤配置").font(.headline).foregroundStyle(VisualStyle.ink)
                            Spacer()
                            Text("\(steps.count) / 8").font(.subheadline).foregroundStyle(VisualStyle.muted)
                        }
                        ForEach(steps.indices, id: \.self) { index in
                            SoftCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        TextField("步骤名称", text: $steps[index].name)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(VisualStyle.oliveDark)
                                        Spacer()
                                        Menu {
                                            Button("复制步骤", systemImage: "square.on.square") { duplicateStep(index) }
                                                .disabled(steps.count >= 8)
                                            Button("上移", systemImage: "arrow.up") { moveStep(index, by: -1) }
                                                .disabled(index == 0)
                                            Button("下移", systemImage: "arrow.down") { moveStep(index, by: 1) }
                                                .disabled(index == steps.count - 1)
                                            Button("删除", systemImage: "trash", role: .destructive) { steps.remove(at: index) }
                                                .disabled(steps.count == 1)
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .foregroundStyle(VisualStyle.muted)
                                        }
                                    }
                                    StepEditor(step: $steps[index])
                                }
                            }
                        }
                        Button {
                            steps.append(TimerStep(name: "步骤 \(steps.count + 1)", durationSeconds: 0))
                        } label: {
                            Label("添加步骤", systemImage: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(VisualStyle.muted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(VisualStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(VisualStyle.line, style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
                        }
                        .disabled(steps.count >= 8)
                        SoftCard {
                            VStack(alignment: .leading, spacing: 15) {
                                CountInputField(title: "整套循环", value: $cycles, suffix: "遍")
                                if cycles > 1 {
                                    Toggle("循环之间间隔", isOn: $hasRest)
                                        .font(.system(size: 16, weight: .semibold))
                                    if hasRest {
                                        WheelDurationField(title: "间隔时长", seconds: $restSeconds)
                                    }
                                }
                            }
                        }
                    }
                    if kind == .single {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 15) {
                                Toggle("每次计时之间间隔", isOn: $hasRest)
                                    .font(.system(size: 16, weight: .semibold))
                                if hasRest {
                                    WheelDurationField(title: "间隔时长", seconds: $restSeconds)
                                }
                            }
                        }
                    }
                    HStack {
                        Text("预计总时长")
                        Spacer()
                        Text(plan.map { TimerFormat.clock($0.totalSeconds) } ?? "—")
                    }
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(VisualStyle.ink)
                    .padding(.horizontal, 3)
                    if isBusy {
                        Text("请先结束当前计时，再开始新的一次。")
                            .font(.caption)
                            .foregroundStyle(VisualStyle.muted)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 25)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(VisualStyle.canvas)
            .safeAreaInset(edge: .bottom) {
                Button {
                    guard plan != nil else { return }
                    onStart(project)
                } label: {
                    Label("开始计时", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(plan == nil || isBusy)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(VisualStyle.canvas)
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("返回")
                }
            }
            .tint(VisualStyle.oliveDark)
        }
    }

    private func duplicateStep(_ index: Int) {
        guard steps.count < 8 else { return }
        var copy = steps[index]
        copy.id = UUID()
        steps.insert(copy, at: index + 1)
    }

    private func moveStep(_ index: Int, by offset: Int) {
        let destination = index + offset
        guard steps.indices.contains(destination) else { return }
        steps.swapAt(index, destination)
    }
}

struct PlanPreview: View {
    @Environment(\.dismiss) private var dismiss
    let plan: TimerPlan

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(plan.segments.indices, id: \.self) { index in
                        let item = plan.segments[index]
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(item.kind == .focus ? VisualStyle.olive : VisualStyle.teal)
                                .frame(width: 27, height: 27)
                                .background(item.kind == .focus ? VisualStyle.paleOlive : VisualStyle.paleTeal, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.subheadline.weight(.semibold))
                                Text("第 \(item.projectRepeat) 套 · \(item.groupName) · 第 \(item.groupRepeat) 遍")
                                    .font(.caption)
                                    .foregroundStyle(VisualStyle.muted)
                            }
                            Spacer()
                            Text(TimerFormat.clock(item.durationSeconds))
                                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        }
                    }
                }
            }
            .navigationTitle("完整执行顺序")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(VisualStyle.canvas)
            .tint(VisualStyle.oliveDark)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}

#Preview("新建项目") {
    ProjectEditor(initial: TimerProject(groups: [TimerGroup(steps: [])])) { _ in }
        .preferredColorScheme(.light)
}

#Preview("项目步骤") {
    ProjectEditor(initial: TimerProject(groups: [TimerGroup(steps: [TimerStep(name: "热身", durationSeconds: 30)])])) { _ in }
        .preferredColorScheme(.light)
}

#Preview("一次性多步骤") {
    QuickTimerSetup(kind: .multiple, isBusy: false) { _ in }
        .preferredColorScheme(.light)
}

#Preview("一次性单步骤") {
    QuickTimerSetup(kind: .single, isBusy: false) { _ in }
        .preferredColorScheme(.light)
}
