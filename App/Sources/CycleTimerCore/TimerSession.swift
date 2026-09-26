import Foundation

public enum SessionStatus: String, Codable, Sendable {
    case running
    case paused
    case completed
    case endedEarly
}

public struct SessionProgress: Sendable {
    public var elapsedSeconds: TimeInterval
    public var currentSegmentIndex: Int?
    public var remainingSegmentSeconds: Int
    public var remainingTotalSeconds: Int
    public var completedFocusCount: Int
    public var completedProjectLoops: Int
    public var focusElapsedSeconds: Int
    public var intervalElapsedSeconds: Int
}

public struct TimerSession: Identifiable, Codable, Sendable {
    public var id: UUID
    public var project: TimerProject
    public var startedAt: Date
    public var runStartedUptime: TimeInterval
    public var bootAnchor: TimeInterval
    public var elapsedBeforeCurrentRun: TimeInterval
    public var status: SessionStatus
    public var endedAt: Date?

    public init(project: TimerProject, uptime: TimeInterval, wallDate: Date = Date()) {
        self.id = UUID()
        self.project = project
        self.startedAt = wallDate
        self.runStartedUptime = uptime
        self.bootAnchor = wallDate.timeIntervalSince1970 - uptime
        self.elapsedBeforeCurrentRun = 0
        self.status = .running
        self.endedAt = nil
    }

    public func elapsed(at uptime: TimeInterval, plan: TimerPlan) -> TimeInterval {
        if status == .running {
            return min(Double(plan.totalSeconds), elapsedBeforeCurrentRun + max(0, uptime - runStartedUptime))
        }
        return min(Double(plan.totalSeconds), elapsedBeforeCurrentRun)
    }

    public mutating func pause(at uptime: TimeInterval, plan: TimerPlan) {
        guard status == .running else { return }
        elapsedBeforeCurrentRun = elapsed(at: uptime, plan: plan)
        status = .paused
    }

    public mutating func resume(at uptime: TimeInterval, wallDate: Date = Date()) {
        guard status == .paused else { return }
        runStartedUptime = uptime
        bootAnchor = wallDate.timeIntervalSince1970 - uptime
        status = .running
    }

    public mutating func finish(at uptime: TimeInterval, plan: TimerPlan, wallDate: Date = Date()) {
        guard status == .running, elapsed(at: uptime, plan: plan) >= Double(plan.totalSeconds) else { return }
        elapsedBeforeCurrentRun = Double(plan.totalSeconds)
        status = .completed
        endedAt = wallDate
    }

    public mutating func endEarly(at uptime: TimeInterval, plan: TimerPlan, wallDate: Date = Date()) {
        guard status == .running || status == .paused else { return }
        elapsedBeforeCurrentRun = elapsed(at: uptime, plan: plan)
        status = elapsedBeforeCurrentRun >= Double(plan.totalSeconds) ? .completed : .endedEarly
        endedAt = wallDate
    }

    public func hasSameBoot(at uptime: TimeInterval, wallDate: Date = Date()) -> Bool {
        guard uptime >= runStartedUptime else { return false }
        let currentAnchor = wallDate.timeIntervalSince1970 - uptime
        return abs(currentAnchor - bootAnchor) < 10
    }

    public func progress(at uptime: TimeInterval, plan: TimerPlan) -> SessionProgress {
        let elapsed = elapsed(at: uptime, plan: plan)
        let index = plan.segmentIndex(at: elapsed)
        let segment = index.map { plan.segments[$0] }
        let remainingSegment = segment.map { max(0, Int(ceil(Double($0.endsAtSeconds) - elapsed))) } ?? 0
        let completedLoops = Set(plan.segments.map(\.projectRepeat)).filter { loop in
            let loopSegments = plan.segments.filter { $0.projectRepeat == loop && $0.source != .projectInterval }
            guard let last = loopSegments.last else { return false }
            return Double(last.endsAtSeconds) <= elapsed
        }.count
        var focusTime = 0.0
        var intervalTime = 0.0
        for item in plan.segments {
            let duration = max(0, min(elapsed, Double(item.endsAtSeconds)) - Double(item.startsAtSeconds))
            if item.kind == .focus { focusTime += duration } else { intervalTime += duration }
        }
        return SessionProgress(
            elapsedSeconds: elapsed,
            currentSegmentIndex: index,
            remainingSegmentSeconds: remainingSegment,
            remainingTotalSeconds: max(0, Int(ceil(Double(plan.totalSeconds) - elapsed))),
            completedFocusCount: plan.completedFocusCount(at: elapsed),
            completedProjectLoops: completedLoops,
            focusElapsedSeconds: Int(focusTime.rounded(.down)),
            intervalElapsedSeconds: Int(intervalTime.rounded(.down))
        )
    }
}

public struct TimerRecord: Identifiable, Codable, Sendable {
    public var id: UUID
    public var project: TimerProject
    public var startedAt: Date
    public var endedAt: Date
    public var status: SessionStatus
    public var completedFocusCount: Int
    public var plannedFocusCount: Int
    public var completedProjectLoops: Int
    public var plannedProjectLoops: Int
    public var focusElapsedSeconds: Int
    public var intervalElapsedSeconds: Int

    public init(session: TimerSession, plan: TimerPlan, uptime: TimeInterval, wallDate: Date = Date()) {
        let progress = session.progress(at: uptime, plan: plan)
        self.id = session.id
        self.project = session.project
        self.startedAt = session.startedAt
        self.endedAt = session.endedAt ?? wallDate
        self.status = session.status
        self.completedFocusCount = progress.completedFocusCount
        self.plannedFocusCount = plan.focusCount
        self.completedProjectLoops = progress.completedProjectLoops
        self.plannedProjectLoops = session.project.repetitions
        self.focusElapsedSeconds = progress.focusElapsedSeconds
        self.intervalElapsedSeconds = progress.intervalElapsedSeconds
    }
}
