import Foundation

public enum SegmentKind: String, Codable, CaseIterable, Sendable {
    case focus
    case interval

    public var label: String { self == .focus ? "计时" : "间隔" }
}

public struct TimerStep: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: SegmentKind
    public var name: String
    public var durationSeconds: Int
    public var repetitions: Int
    public var repetitionIntervalSeconds: Int

    public init(
        id: UUID = UUID(),
        kind: SegmentKind = .focus,
        name: String = "步骤 1",
        durationSeconds: Int = 30,
        repetitions: Int = 1,
        repetitionIntervalSeconds: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.durationSeconds = durationSeconds
        self.repetitions = repetitions
        self.repetitionIntervalSeconds = repetitionIntervalSeconds
    }
}

public struct TimerGroup: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var repetitions: Int
    public var loopIntervalSeconds: Int
    public var steps: [TimerStep]

    public init(
        id: UUID = UUID(),
        name: String = "第 1 组",
        repetitions: Int = 1,
        loopIntervalSeconds: Int = 0,
        steps: [TimerStep] = [TimerStep()]
    ) {
        self.id = id
        self.name = name
        self.repetitions = repetitions
        self.loopIntervalSeconds = loopIntervalSeconds
        self.steps = steps
    }
}

public struct TimerProject: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var repetitions: Int
    public var loopIntervalSeconds: Int
    public var groups: [TimerGroup]
    public var createdAt: Date
    public var updatedAt: Date
    public var isArchived: Bool

    public init(
        id: UUID = UUID(),
        title: String = "",
        repetitions: Int = 1,
        loopIntervalSeconds: Int = 0,
        groups: [TimerGroup] = [TimerGroup()],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.repetitions = repetitions
        self.loopIntervalSeconds = loopIntervalSeconds
        self.groups = groups
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }

    public static func singleStep() -> TimerProject {
        TimerProject(title: "我的循环计时", groups: [
            TimerGroup(steps: [TimerStep(name: "步骤 1", durationSeconds: 45, repetitions: 8, repetitionIntervalSeconds: 15)])
        ])
    }

    public static func sequential() -> TimerProject {
        TimerProject(title: "分段计时", groups: [TimerGroup(steps: [
            TimerStep(name: "第一部分", durationSeconds: 20 * 60),
            TimerStep(name: "第二部分", durationSeconds: 30 * 60),
            TimerStep(name: "第三部分", durationSeconds: 40 * 60),
            TimerStep(name: "检查", durationSeconds: 10 * 60)
        ])])
    }

    public static func combined() -> TimerProject {
        TimerProject(title: "组合循环", groups: [TimerGroup(
            repetitions: 3,
            loopIntervalSeconds: 20,
            steps: [
                TimerStep(name: "步骤 A", durationSeconds: 40),
                TimerStep(name: "步骤 B", durationSeconds: 30)
            ]
        )])
    }
}

public enum SegmentSource: String, Codable, Sendable {
    case step
    case stepInterval
    case explicitInterval
    case groupInterval
    case projectInterval
}

public struct PlannedSegment: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var kind: SegmentKind
    public var source: SegmentSource
    public var durationSeconds: Int
    public var startsAtSeconds: Int
    public var endsAtSeconds: Int
    public var projectRepeat: Int
    public var groupName: String
    public var groupRepeat: Int
    public var stepRepeat: Int
    public var stepRepeatTotal: Int

    public init(
        id: String, title: String, kind: SegmentKind, source: SegmentSource,
        durationSeconds: Int, startsAtSeconds: Int, projectRepeat: Int,
        groupName: String, groupRepeat: Int, stepRepeat: Int, stepRepeatTotal: Int
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.source = source
        self.durationSeconds = durationSeconds
        self.startsAtSeconds = startsAtSeconds
        self.endsAtSeconds = startsAtSeconds + durationSeconds
        self.projectRepeat = projectRepeat
        self.groupName = groupName
        self.groupRepeat = groupRepeat
        self.stepRepeat = stepRepeat
        self.stepRepeatTotal = stepRepeatTotal
    }
}

public struct TimerPlan: Sendable {
    public var segments: [PlannedSegment]
    public var totalSeconds: Int { segments.last?.endsAtSeconds ?? 0 }
    public var focusSeconds: Int { segments.filter { $0.kind == .focus }.reduce(0) { $0 + $1.durationSeconds } }
    public var intervalSeconds: Int { totalSeconds - focusSeconds }
    public var focusCount: Int { segments.filter { $0.kind == .focus }.count }

    public init(segments: [PlannedSegment]) { self.segments = segments }

    public func segmentIndex(at elapsedSeconds: TimeInterval) -> Int? {
        guard elapsedSeconds < Double(totalSeconds) else { return nil }
        return segments.firstIndex { elapsedSeconds < Double($0.endsAtSeconds) }
    }

    public func completedFocusCount(at elapsedSeconds: TimeInterval) -> Int {
        segments.filter { $0.kind == .focus && Double($0.endsAtSeconds) <= elapsedSeconds }.count
    }
}

public enum TimerFormat {
    public static func clock(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let secs = safe % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }

    public static func readable(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        if safe >= 3600 { return "\(safe / 3600) 小时 \((safe % 3600) / 60) 分钟" }
        if safe >= 60 { return "\(safe / 60) 分 \(safe % 60) 秒" }
        return "\(safe) 秒"
    }
}
