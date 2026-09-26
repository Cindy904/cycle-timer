import Foundation
import SwiftUI
import UIKit
import AVFoundation

private struct StoredData: Codable {
    var projects: [TimerProject] = []
    var records: [TimerRecord] = []
    var activeSession: TimerSession?
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var projects: [TimerProject] = []
    @Published private(set) var records: [TimerRecord] = []
    @Published private(set) var activeSession: TimerSession?
    @Published private(set) var progress: SessionProgress?
    @Published var notice: String?
    @Published var soundEnabled = true
    @Published var vibrationEnabled = true

    private let fileURL: URL
    private let reminders = ReminderService()
    private var activePlan: TimerPlan?
    private var previousSegmentIndex: Int?
    private var lastCheckpointBucket = 0
    private var completionPlayer: AVAudioPlayer?
    private var scheduledCompletionSessionID: UUID?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appendingPathComponent("cycle-timer-data.json")
        soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        vibrationEnabled = UserDefaults.standard.object(forKey: "vibrationEnabled") as? Bool ?? true
        reminders.soundEnabled = soundEnabled
        if let tone = NSDataAsset(name: "CompletionTone") {
            completionPlayer = try? AVAudioPlayer(data: tone.data)
            completionPlayer?.prepareToPlay()
        }
        load()
    }

    var visibleProjects: [TimerProject] {
        projects.filter { !$0.isArchived }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var archivedProjects: [TimerProject] {
        projects.filter(\.isArchived).sorted { $0.updatedAt > $1.updatedAt }
    }

    var currentPlan: TimerPlan? { activePlan }

    func plan(for project: TimerProject) -> TimerPlan? {
        try? PlanCompiler.compile(project)
    }

    func save(_ project: TimerProject) throws {
        _ = try PlanCompiler.compile(project)
        guard activeSession?.project.id != project.id else {
            throw NSError(domain: "CycleTimer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "正在计时的项目暂时不能编辑"])
        }
        var value = project
        value.updatedAt = Date()
        if let index = projects.firstIndex(where: { $0.id == value.id }) {
            projects[index] = value
        } else {
            projects.append(value)
        }
        persist()
    }

    func copy(_ project: TimerProject) {
        var value = project
        value.id = UUID()
        value.title += " 副本"
        value.createdAt = Date()
        value.updatedAt = Date()
        value.isArchived = false
        value.groups = value.groups.map { group in
            var result = group
            result.id = UUID()
            result.steps = group.steps.map { step in
                var copy = step
                copy.id = UUID()
                return copy
            }
            return result
        }
        projects.append(value)
        persist()
    }

    func archive(_ project: TimerProject, archived: Bool) {
        guard activeSession?.project.id != project.id else { return }
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].isArchived = archived
        projects[index].updatedAt = Date()
        persist()
    }

    func start(_ project: TimerProject) async {
        guard activeSession == nil else {
            notice = "请先结束当前计时"
            return
        }
        guard let plan = try? PlanCompiler.compile(project) else {
            notice = "项目配置需要修改后才能开始"
            return
        }
        cancelScheduledCompletion()
        let uptime = ProcessInfo.processInfo.systemUptime
        let session = TimerSession(project: project, uptime: uptime)
        activeSession = session
        activePlan = plan
        previousSegmentIndex = 0
        lastCheckpointBucket = 0
        progress = session.progress(at: uptime, plan: plan)
        persist()
        Task {
            let notificationsAllowed = await reminders.requestPermissionIfNeeded()
            guard let currentSession = activeSession,
                  currentSession.id == session.id,
                  currentSession.status == .running else { return }
            if notificationsAllowed {
                if !(await reminders.schedule(session: currentSession, plan: plan, uptime: ProcessInfo.processInfo.systemUptime)) {
                    notice = "后台提醒未能全部安排；请保持屏幕亮起使用"
                }
            } else {
                notice = "通知未开启；锁屏时可能听不到阶段提示"
            }
        }
    }

    private func scheduleCompletionCue(for session: TimerSession, plan: TimerPlan) {
        guard scheduledCompletionSessionID != session.id,
              soundEnabled,
              UIApplication.shared.applicationState == .active,
              let player = completionPlayer else { return }
        let remaining = Double(plan.totalSeconds) - session.elapsed(at: ProcessInfo.processInfo.systemUptime, plan: plan)
        guard remaining > 0, remaining <= 2 else { return }
        player.currentTime = 0
        player.prepareToPlay()
        let preciseRemaining = Double(plan.totalSeconds) - session.elapsed(at: ProcessInfo.processInfo.systemUptime, plan: plan)
        guard preciseRemaining > 0 else { return }
        if player.play(atTime: player.deviceCurrentTime + preciseRemaining) {
            scheduledCompletionSessionID = session.id
        }
    }

    private func cancelScheduledCompletion() {
        guard scheduledCompletionSessionID != nil else { return }
        completionPlayer?.stop()
        completionPlayer?.currentTime = 0
        completionPlayer?.prepareToPlay()
        scheduledCompletionSessionID = nil
    }

    func refresh() {
        guard var session = activeSession, let plan = activePlan else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        let next = session.progress(at: uptime, plan: plan)
        progress = next
        if session.status == .running { scheduleCompletionCue(for: session, plan: plan) }
        if session.status == .running && next.elapsedSeconds >= Double(plan.totalSeconds) {
            let cueWasScheduled = scheduledCompletionSessionID == session.id
            scheduledCompletionSessionID = nil
            if UIApplication.shared.applicationState == .active && soundEnabled && !cueWasScheduled {
                completionPlayer?.currentTime = 0
                completionPlayer?.play()
            }
            session.finish(at: uptime, plan: plan)
            activeSession = session
            finishRecord(for: session, plan: plan, uptime: uptime)
            reminders.invalidate()
            if UIApplication.shared.applicationState == .active {
                if vibrationEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            }
        } else if session.status == .running {
            let changedSegment = next.currentSegmentIndex != previousSegmentIndex
            let checkpointBucket = Int(next.elapsedSeconds) / 5
            if changedSegment || checkpointBucket > lastCheckpointBucket {
                previousSegmentIndex = next.currentSegmentIndex
                lastCheckpointBucket = checkpointBucket
                session.elapsedBeforeCurrentRun = next.elapsedSeconds
                session.runStartedUptime = uptime
                session.bootAnchor = Date().timeIntervalSince1970 - uptime
                activeSession = session
                if changedSegment && vibrationEnabled && UIApplication.shared.applicationState == .active {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                persist()
            }
        }
    }

    func pause() {
        guard var session = activeSession, let plan = activePlan else { return }
        cancelScheduledCompletion()
        session.pause(at: ProcessInfo.processInfo.systemUptime, plan: plan)
        activeSession = session
        progress = session.progress(at: ProcessInfo.processInfo.systemUptime, plan: plan)
        reminders.invalidate()
        persist()
    }

    func resume() {
        guard var session = activeSession, let plan = activePlan else { return }
        cancelScheduledCompletion()
        session.resume(at: ProcessInfo.processInfo.systemUptime)
        activeSession = session
        persist()
        Task {
            if !(await reminders.schedule(session: session, plan: plan, uptime: ProcessInfo.processInfo.systemUptime)) {
                notice = "后台提醒未能全部安排；请保持屏幕亮起使用"
            }
        }
    }

    func endEarly() {
        guard var session = activeSession, let plan = activePlan else { return }
        cancelScheduledCompletion()
        let uptime = ProcessInfo.processInfo.systemUptime
        session.endEarly(at: uptime, plan: plan)
        activeSession = session
        progress = session.progress(at: uptime, plan: plan)
        finishRecord(for: session, plan: plan, uptime: uptime)
        reminders.invalidate()
    }

    func closeResult() {
        cancelScheduledCompletion()
        activeSession = nil
        activePlan = nil
        progress = nil
        previousSegmentIndex = nil
        lastCheckpointBucket = 0
        persist()
    }

    func discardActiveSession() {
        guard activeSession != nil else { return }
        cancelScheduledCompletion()
        reminders.invalidate()
        activeSession = nil
        activePlan = nil
        progress = nil
        previousSegmentIndex = nil
        lastCheckpointBucket = 0
        persist()
    }

    func restart() async {
        guard let project = activeSession?.project,
              activeSession?.status == .completed || activeSession?.status == .endedEarly else { return }
        closeResult()
        await start(project)
    }

    func updateSettings(sound: Bool, vibration: Bool) {
        if !sound { cancelScheduledCompletion() }
        soundEnabled = sound
        vibrationEnabled = vibration
        UserDefaults.standard.set(sound, forKey: "soundEnabled")
        UserDefaults.standard.set(vibration, forKey: "vibrationEnabled")
        reminders.soundEnabled = sound
        if let session = activeSession, let plan = activePlan, session.status == .running {
            Task {
                if await reminders.requestPermissionIfNeeded() {
                    _ = await reminders.schedule(session: session, plan: plan, uptime: ProcessInfo.processInfo.systemUptime)
                } else {
                    reminders.invalidate()
                    notice = "通知未开启；锁屏时可能听不到阶段提示"
                }
            }
        }
    }

    private func finishRecord(for session: TimerSession, plan: TimerPlan, uptime: TimeInterval) {
        guard !records.contains(where: { $0.id == session.id }) else { return }
        records.insert(TimerRecord(session: session, plan: plan, uptime: uptime), at: 0)
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(StoredData.self, from: data) else { return }
        projects = decoded.projects
        records = decoded.records
        guard var session = decoded.activeSession,
              let plan = try? PlanCompiler.compile(session.project) else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        if session.status == .running && !session.hasSameBoot(at: uptime) {
            session.status = .paused
            notice = "设备或系统时间发生变化，已从最近保存的位置暂停计时"
            activeSession = session
            persist()
        }
        activeSession = session
        activePlan = plan
        progress = session.progress(at: uptime, plan: plan)
        previousSegmentIndex = progress?.currentSegmentIndex
        lastCheckpointBucket = Int(session.elapsedBeforeCurrentRun) / 5
        if session.status == .running {
            refresh()
            if activeSession?.status == .running {
                Task {
                    if !(await reminders.schedule(session: session, plan: plan, uptime: uptime)) {
                        notice = "后台提醒未能全部安排；请保持屏幕亮起使用"
                    }
                }
            }
        }
    }

    private func persist() {
        let value = StoredData(projects: projects, records: records, activeSession: activeSession)
        guard let data = try? JSONEncoder().encode(value) else {
            notice = "保存失败，请稍后重试"
            return
        }
        do { try data.write(to: fileURL, options: .atomic) }
        catch { notice = "本地保存失败：\(error.localizedDescription)" }
    }
}
