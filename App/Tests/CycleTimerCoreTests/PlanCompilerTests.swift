import XCTest
@testable import CycleTimerCore

final class PlanCompilerTests: XCTestCase {
    func testSingleStepWithNoTrailingInterval() throws {
        let plan = try PlanCompiler.compile(.singleStep())
        XCTAssertEqual(plan.totalSeconds, 465)
        XCTAssertEqual(plan.focusCount, 8)
        XCTAssertEqual(plan.segments.count, 15)
        XCTAssertEqual(plan.segments.last?.kind, .focus)
    }

    func testSequentialUnequalSteps() throws {
        let plan = try PlanCompiler.compile(.sequential())
        XCTAssertEqual(plan.totalSeconds, 6000)
        XCTAssertEqual(plan.segments.map(\.durationSeconds), [1200, 1800, 2400, 600])
    }

    func testStepRepeatDiffersFromGroupRepeat() throws {
        var project = TimerProject.combined()
        project.groups[0].steps[0].repetitions = 3
        project.groups[0].steps[1].repetitions = 3
        project.groups[0].repetitions = 1
        XCTAssertEqual(try PlanCompiler.compile(project).segments.filter { $0.kind == .focus }.map(\.title),
                       ["步骤 A", "步骤 A", "步骤 A", "步骤 B", "步骤 B", "步骤 B"])

        project.groups[0].steps[0].repetitions = 1
        project.groups[0].steps[1].repetitions = 1
        project.groups[0].repetitions = 3
        XCTAssertEqual(try PlanCompiler.compile(project).segments.filter { $0.kind == .focus }.map(\.title),
                       ["步骤 A", "步骤 B", "步骤 A", "步骤 B", "步骤 A", "步骤 B"])
    }

    func testFullCombinationAndSessionBoundaries() throws {
        let project = TimerProject(
            title: "组合",
            repetitions: 2,
            loopIntervalSeconds: 90,
            groups: [
                TimerGroup(name: "力量", repetitions: 2, loopIntervalSeconds: 60, steps: [
                    TimerStep(name: "A", durationSeconds: 40, repetitions: 3, repetitionIntervalSeconds: 20),
                    TimerStep(kind: .interval, name: "换项", durationSeconds: 30),
                    TimerStep(name: "B", durationSeconds: 30, repetitions: 2, repetitionIntervalSeconds: 15)
                ]),
                TimerGroup(name: "拉伸", steps: [TimerStep(name: "C", durationSeconds: 120)])
            ]
        )
        let plan = try PlanCompiler.compile(project)
        XCTAssertEqual(plan.totalSeconds, 1510)
        XCTAssertEqual(plan.focusSeconds, 960)
        XCTAssertEqual(plan.intervalSeconds, 550)
        XCTAssertEqual(plan.focusCount, 22)
        XCTAssertEqual(plan.segments.count, 41)

        var session = TimerSession(project: project, uptime: 100, wallDate: Date(timeIntervalSince1970: 1_000))
        session.pause(at: 150, plan: plan)
        XCTAssertEqual(session.elapsed(at: 250, plan: plan), 50)
        session.resume(at: 250, wallDate: Date(timeIntervalSince1970: 1_150))
        XCTAssertEqual(session.elapsed(at: 300, plan: plan), 100)
        XCTAssertEqual(session.progress(at: 300, plan: plan).completedFocusCount, 2)
        session.finish(at: 1710, plan: plan)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.progress(at: 1710, plan: plan).completedProjectLoops, 2)
    }

    func testLimitRejectsUnboundedExpansion() throws {
        var project = TimerProject.singleStep()
        project.groups[0].steps[0].repetitions = 30
        XCTAssertThrowsError(try PlanCompiler.compile(project)) { error in
            XCTAssertEqual(error as? PlanIssue, .tooManySegments)
        }
    }

    func testHourPickerRangeAndDailyLimit() throws {
        let longStep = TimerProject(title: "长计时", groups: [
            TimerGroup(steps: [TimerStep(durationSeconds: 23 * 3600 + 59 * 60 + 59)])
        ])
        XCTAssertEqual(try PlanCompiler.compile(longStep).totalSeconds, 86_399)

        var repeated = longStep
        repeated.groups[0].steps[0].repetitions = 2
        XCTAssertThrowsError(try PlanCompiler.compile(repeated)) { error in
            XCTAssertEqual(error as? PlanIssue, .tooLong)
        }
    }

    func testExplicitFinalIntervalCountsTowardCompletion() throws {
        let project = TimerProject(title: "有收尾的流程", groups: [
            TimerGroup(steps: [
                TimerStep(name: "任务", durationSeconds: 20),
                TimerStep(kind: .interval, name: "收尾", durationSeconds: 10)
            ])
        ])
        let plan = try PlanCompiler.compile(project)
        let session = TimerSession(project: project, uptime: 100)
        XCTAssertEqual(plan.totalSeconds, 30)
        XCTAssertEqual(session.progress(at: 125, plan: plan).completedFocusCount, 1)
        XCTAssertEqual(session.progress(at: 125, plan: plan).completedProjectLoops, 0)
        XCTAssertEqual(session.progress(at: 130, plan: plan).completedProjectLoops, 1)
    }

    func testPauseAndEarlyEndPreservePartialTime() throws {
        let project = TimerProject.singleStep()
        let plan = try PlanCompiler.compile(project)
        var session = TimerSession(project: project, uptime: 100)
        session.pause(at: 170, plan: plan)
        session.endEarly(at: 500, plan: plan)
        let result = session.progress(at: 500, plan: plan)
        XCTAssertEqual(session.status, .endedEarly)
        XCTAssertEqual(result.completedFocusCount, 1)
        XCTAssertEqual(result.focusElapsedSeconds, 55)
        XCTAssertEqual(result.intervalElapsedSeconds, 15)
    }
}
