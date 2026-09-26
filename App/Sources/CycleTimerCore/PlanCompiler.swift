import Foundation

public enum PlanIssue: Error, Equatable, LocalizedError, Sendable {
    case emptyTitle
    case invalidProjectName
    case emptyProject
    case tooManyGroups
    case tooManySteps
    case missingFocus
    case emptyGroup(Int)
    case invalidName
    case invalidDuration
    case invalidRepeat
    case invalidInterval
    case tooManySegments
    case tooLong

    public var errorDescription: String? {
        switch self {
        case .emptyTitle: "请填写项目名称"
        case .invalidProjectName: "项目名称需为 1–30 个字符"
        case .emptyProject: "至少需要一个循环组"
        case .tooManyGroups: "每个项目最多 8 个循环组"
        case .tooManySteps: "每个项目最多 24 个配置步骤"
        case .missingFocus: "至少需要一个计时步骤"
        case .emptyGroup(let index): "第 \(index + 1) 组至少需要一个步骤"
        case .invalidName: "组名和步骤名需为 1–30 个字符"
        case .invalidDuration: "每段时长需为 1 秒至 23 小时 59 分 59 秒"
        case .invalidRepeat: "重复次数需为 1–99"
        case .invalidInterval: "自动间隔需为 0 秒至 23 小时 59 分 59 秒"
        case .tooManySegments: "展开后最多 48 个执行段，请减少重复次数"
        case .tooLong: "计划总时长不能超过 24 小时"
        }
    }
}

public enum PlanCompiler {
    public static let maximumGroups = 8
    public static let maximumConfiguredSteps = 24
    public static let maximumSegments = 48
    public static let maximumTotalSeconds = 24 * 3600

    public static func compile(_ project: TimerProject) throws -> TimerPlan {
        let titleLength = project.title.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard titleLength > 0 else { throw PlanIssue.emptyTitle }
        guard titleLength <= 30 else { throw PlanIssue.invalidProjectName }
        guard !project.groups.isEmpty else { throw PlanIssue.emptyProject }
        guard project.groups.count <= maximumGroups else { throw PlanIssue.tooManyGroups }
        guard project.groups.reduce(0, { $0 + $1.steps.count }) <= maximumConfiguredSteps else { throw PlanIssue.tooManySteps }
        guard project.groups.flatMap(\.steps).contains(where: { $0.kind == .focus }) else { throw PlanIssue.missingFocus }
        guard (1...99).contains(project.repetitions) else { throw PlanIssue.invalidRepeat }
        guard (0...86399).contains(project.loopIntervalSeconds) else { throw PlanIssue.invalidInterval }

        for (index, group) in project.groups.enumerated() {
            guard !group.steps.isEmpty else { throw PlanIssue.emptyGroup(index) }
            guard (1...30).contains(group.name.trimmingCharacters(in: .whitespacesAndNewlines).count) else { throw PlanIssue.invalidName }
            guard (1...99).contains(group.repetitions) else { throw PlanIssue.invalidRepeat }
            guard (0...86399).contains(group.loopIntervalSeconds) else { throw PlanIssue.invalidInterval }
            for step in group.steps {
                guard (1...30).contains(step.name.trimmingCharacters(in: .whitespacesAndNewlines).count) else { throw PlanIssue.invalidName }
                guard (1...86399).contains(step.durationSeconds) else { throw PlanIssue.invalidDuration }
                guard (1...99).contains(step.repetitions) else { throw PlanIssue.invalidRepeat }
                guard (0...86399).contains(step.repetitionIntervalSeconds) else { throw PlanIssue.invalidInterval }
                if step.kind == .interval && (step.repetitions != 1 || step.repetitionIntervalSeconds != 0) {
                    throw PlanIssue.invalidRepeat
                }
            }
        }

        var segments: [PlannedSegment] = []
        var offset = 0

        func append(
            _ title: String, _ kind: SegmentKind, _ source: SegmentSource,
            _ seconds: Int, _ path: String, _ projectRepeat: Int,
            _ groupName: String, _ groupRepeat: Int,
            _ stepRepeat: Int = 1, _ stepRepeatTotal: Int = 1
        ) throws {
            guard segments.count < maximumSegments else { throw PlanIssue.tooManySegments }
            guard offset + seconds <= maximumTotalSeconds else { throw PlanIssue.tooLong }
            segments.append(PlannedSegment(
                id: path, title: title, kind: kind, source: source,
                durationSeconds: seconds, startsAtSeconds: offset,
                projectRepeat: projectRepeat, groupName: groupName,
                groupRepeat: groupRepeat, stepRepeat: stepRepeat,
                stepRepeatTotal: stepRepeatTotal
            ))
            offset += seconds
        }

        for projectIndex in 1...project.repetitions {
            for (groupIndex, group) in project.groups.enumerated() {
                for groupIndexRepeat in 1...group.repetitions {
                    for (stepIndex, step) in group.steps.enumerated() {
                        let path = "p\(projectIndex).g\(groupIndex).q\(groupIndexRepeat).s\(stepIndex)"
                        if step.kind == .interval {
                            try append(step.name, .interval, .explicitInterval, step.durationSeconds,
                                       path, projectIndex, group.name, groupIndexRepeat)
                        } else {
                            for stepIndexRepeat in 1...step.repetitions {
                                try append(step.name, .focus, .step, step.durationSeconds,
                                           "\(path).r\(stepIndexRepeat)", projectIndex,
                                           group.name, groupIndexRepeat, stepIndexRepeat, step.repetitions)
                                if stepIndexRepeat < step.repetitions && step.repetitionIntervalSeconds > 0 {
                                    try append("步骤间隔", .interval, .stepInterval, step.repetitionIntervalSeconds,
                                               "\(path).r\(stepIndexRepeat).interval", projectIndex,
                                               group.name, groupIndexRepeat)
                                }
                            }
                        }
                    }
                    if groupIndexRepeat < group.repetitions && group.loopIntervalSeconds > 0 {
                        try append("组间隔", .interval, .groupInterval, group.loopIntervalSeconds,
                                   "p\(projectIndex).g\(groupIndex).q\(groupIndexRepeat).interval",
                                   projectIndex, group.name, groupIndexRepeat)
                    }
                }
            }
            if projectIndex < project.repetitions && project.loopIntervalSeconds > 0 {
                try append("整套间隔", .interval, .projectInterval, project.loopIntervalSeconds,
                           "p\(projectIndex).interval", projectIndex, "", 1)
            }
        }

        return TimerPlan(segments: segments)
    }
}
