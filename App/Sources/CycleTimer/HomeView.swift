import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    let showTimer: (TimerProject?) -> Void
    @State private var editingProject: TimerProject?
    @State private var viewingProject: TimerProject?
    @State private var showsArchive = false
    @State private var quickSetup: QuickTimerKind?
    @State private var pendingQuickProject: TimerProject?
    @State private var activeSwipeOffset: CGFloat = 0
    @State private var activeSwipeStartOffset: CGFloat?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    header
                    templateSection
                    if let session = store.activeSession { activeCard(session) }
                    HStack {
                        Text("我的项目")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(VisualStyle.ink)
                        Spacer()
                        Button {
                            editingProject = TimerProject(groups: [TimerGroup(steps: [])])
                        } label: {
                            Label("新建", systemImage: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(VisualStyle.oliveDark)
                        }
                    }
                    if store.visibleProjects.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.visibleProjects) { project in
                            ProjectCard(
                                project: project,
                                plan: store.plan(for: project),
                                isBusy: store.activeSession != nil,
                                start: { start(project) },
                                detail: { viewingProject = project },
                                edit: { editingProject = project },
                                copy: { store.copy(project) },
                                archive: { store.archive(project, archived: true) }
                            )
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
                    Menu {
                        Button("查看归档", systemImage: "archivebox") { showsArchive = true }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                            .foregroundStyle(VisualStyle.olive)
                    }
                }
            }
            .sheet(item: $editingProject) { project in
                ProjectEditor(initial: project) { saved in
                    try store.save(saved)
                }
            }
            .sheet(item: $viewingProject) { project in ProjectDetailView(project: project) }
            .sheet(isPresented: $showsArchive) { ArchiveView() }
            .sheet(item: $quickSetup, onDismiss: {
                if let project = pendingQuickProject {
                    pendingQuickProject = nil
                    if store.activeSession == nil {
                        showTimer(project)
                    } else {
                        store.notice = "请先结束当前计时"
                    }
                }
            }) { kind in
                QuickTimerSetup(kind: kind, isBusy: store.activeSession != nil) { project in
                    pendingQuickProject = project
                    quickSetup = nil
                }
            }
        }
    }

    private var header: some View {
        AppPageHeading(title: "循环计时")
    }

    private func activeCard(_ session: TimerSession) -> some View {
        ZStack(alignment: .trailing) {
            Button {
                store.discardActiveSession()
                activeSwipeOffset = 0
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("移除")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 98, height: 74)
                .background(Color.red, in: RoundedRectangle(cornerRadius: 18))
            }
            .accessibilityLabel("移除当前计时")
            SoftCard {
                HStack(spacing: 14) {
                    Image(systemName: session.status == .paused ? "pause.circle.fill" : "timer")
                        .font(.system(size: 33))
                        .foregroundStyle(VisualStyle.olive)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.status == .completed || session.status == .endedEarly ? "查看本次结果" : "正在进行")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VisualStyle.muted)
                        Text(session.project.title)
                            .font(.headline)
                            .foregroundStyle(VisualStyle.ink)
                    }
                    Spacer()
                    Button { showTimer(nil) } label: {
                        Image(systemName: "arrow.up.right")
                            .font(.headline)
                            .foregroundStyle(VisualStyle.ink)
                            .frame(width: 42, height: 42)
                            .background(VisualStyle.olive, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityLabel("返回当前计时")
                }
            }
            .offset(x: activeSwipeOffset)
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        if activeSwipeStartOffset == nil { activeSwipeStartOffset = activeSwipeOffset }
                        activeSwipeOffset = max(-98, min(0, (activeSwipeStartOffset ?? 0) + value.translation.width))
                    }
                    .onEnded { value in
                        activeSwipeStartOffset = nil
                        withAnimation(.easeOut(duration: 0.2)) {
                            if value.translation.width < -45 { activeSwipeOffset = -98 }
                            else if value.translation.width > 45 { activeSwipeOffset = 0 }
                            else { activeSwipeOffset = activeSwipeOffset < -50 ? -98 : 0 }
                        }
                    }
            )
        }
    }
    private var emptyState: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("还没有项目")
                    .font(.headline)
                    .foregroundStyle(VisualStyle.ink)
                Text("点击「新建」，创建自己的计时项目。")
                    .font(.subheadline)
                    .foregroundStyle(VisualStyle.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 106, alignment: .leading)
        }
    }

    private var templateSection: some View {
        HStack(spacing: 12) {
            template("单步骤重复", subtitle: "45秒 × 8次", symbol: "repeat", color: VisualStyle.teal, kind: .single)
            template("多步骤循环", subtitle: "（40秒+20秒）×5组", symbol: "square.stack.3d.up.fill", color: VisualStyle.sky, kind: .multiple)
        }
    }

    private func template(_ title: String, subtitle: String, symbol: String, color: Color, kind: QuickTimerKind) -> some View {
        Button { quickSetup = kind } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 46, height: 46)
                    .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
                Spacer(minLength: 12)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VisualStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(VisualStyle.muted)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 132, alignment: .topLeading)
            .padding(17)
            .background(VisualStyle.surface, in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(VisualStyle.line, lineWidth: 1))
            .shadow(color: VisualStyle.ink.opacity(0.035), radius: 7, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func start(_ project: TimerProject) {
        guard store.activeSession == nil else {
            store.notice = "请先结束当前计时"
            return
        }
        showTimer(project)
    }
}

private struct ProjectCard: View {
    let project: TimerProject
    let plan: TimerPlan?
    let isBusy: Bool
    let start: () -> Void
    let detail: () -> Void
    let edit: () -> Void
    let copy: () -> Void
    let archive: () -> Void

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(project.title)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(VisualStyle.ink)
                        if plan == nil {
                            Text("配置需要检查")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    Menu {
                        Button("查看详情", systemImage: "list.bullet.rectangle", action: detail)
                        Button("编辑", systemImage: "pencil", action: edit)
                        Button("复制", systemImage: "square.on.square", action: copy)
                        Button("归档", systemImage: "archivebox", action: archive)
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(VisualStyle.muted)
                            .frame(width: 36, height: 32)
                    }
                }
                HStack(spacing: 8) {
                    Spacer()
                    Button(action: edit) {
                        Label("编辑", systemImage: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VisualStyle.muted)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 11)
                            .background(VisualStyle.paleHoney, in: RoundedRectangle(cornerRadius: 11))
                    }
                    Button(action: start) {
                        Label("开始", systemImage: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VisualStyle.buttonInk)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 11)
                            .background(VisualStyle.olive, in: RoundedRectangle(cornerRadius: 11))
                    }
                    .disabled(isBusy || plan == nil)
                }
            }
            .frame(minHeight: 110)
        }
    }
}

private struct ArchiveView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if store.archivedProjects.isEmpty {
                        SoftCard {
                            Text("暂无归档项目")
                                .font(.system(size: 16))
                                .foregroundStyle(VisualStyle.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(store.archivedProjects) { project in
                            SoftCard {
                                HStack(spacing: 12) {
                                    Text(project.title)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(VisualStyle.ink)
                                    Spacer()
                                    Button("恢复") { store.archive(project, archived: false) }
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(VisualStyle.muted)
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 11)
                                        .background(VisualStyle.paleHoney, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
            }
            .background(VisualStyle.canvas)
            .tint(VisualStyle.oliveDark)
            .navigationTitle("归档项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(VisualStyle.oliveDark)
                            .frame(width: 44, height: 44)
                            .background(VisualStyle.surface, in: Circle())
                            .overlay(Circle().stroke(VisualStyle.line, lineWidth: 1))
                    }
                    .accessibilityLabel("返回")
                }
            }
        }
    }
}

private struct ProjectDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showsPreview = false
    let project: TimerProject

    private var plan: TimerPlan? { store.plan(for: project) }
    private var history: [TimerRecord] { store.records.filter { $0.project.id == project.id } }

    var body: some View {
        NavigationStack {
            List {
                Section("当前方案") {
                    LabeledContent("循环组", value: "\(project.groups.count)")
                    LabeledContent("整套重复", value: "\(project.repetitions) 次")
                    if let plan {
                        LabeledContent("总时长", value: TimerFormat.readable(plan.totalSeconds))
                        LabeledContent("计时段", value: "\(plan.focusCount) 个")
                        Button("查看完整执行顺序") { showsPreview = true }
                    }
                }
                Section("历史投入") {
                    LabeledContent("完成次数", value: "\(history.reduce(0) { $0 + $1.completedProjectLoops })")
                    LabeledContent("有效计时", value: TimerFormat.readable(history.reduce(0) { $0 + $1.focusElapsedSeconds }))
                }
                Section("最近记录") {
                    if history.isEmpty { Text("还没有记录").foregroundStyle(VisualStyle.muted) }
                    ForEach(history.prefix(20)) { record in
                        HStack {
                            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Text("\(record.completedFocusCount)/\(record.plannedFocusCount)")
                                .foregroundStyle(VisualStyle.muted)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(VisualStyle.canvas)
            .tint(VisualStyle.oliveDark)
            .navigationTitle(project.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
            .sheet(isPresented: $showsPreview) {
                if let plan { PlanPreview(plan: plan) }
            }
        }
    }
}
