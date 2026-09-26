import Foundation
import UserNotifications

@MainActor
final class ReminderService: NSObject, UNUserNotificationCenterDelegate {
    var soundEnabled = true
    private var generation = 0
    private let center = UNUserNotificationCenter.current()
    private let prefix = "cycle-timer."

    override init() {
        super.init()
        center.delegate = self
    }

    func requestPermissionIfNeeded() async -> Bool {
        let current = await center.notificationSettings()
        if current.authorizationStatus == .authorized || current.authorizationStatus == .provisional { return true }
        if current.authorizationStatus == .denied { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func invalidate() {
        generation += 1
        let token = generation
        Task { await removeExisting(expectedGeneration: token) }
    }

    @discardableResult
    func schedule(session: TimerSession, plan: TimerPlan, uptime: TimeInterval) async -> Bool {
        generation += 1
        let token = generation
        await removeExisting(expectedGeneration: token)
        guard token == generation else { return false }
        for (index, segment) in plan.segments.enumerated() {
            guard token == generation else { return false }
            let elapsed = session.elapsed(at: max(uptime, ProcessInfo.processInfo.systemUptime), plan: plan)
            let delay = Double(segment.endsAtSeconds) - elapsed
            guard delay > 0 else { continue }
            let content = UNMutableNotificationContent()
            if index == plan.segments.count - 1 {
                content.title = "计时完成"
                content.body = session.project.title
            } else {
                let next = plan.segments[index + 1]
                content.title = next.kind == .focus ? "开始：\(next.title)" : "间隔：\(next.title)"
                content.body = session.project.title
            }
            if soundEnabled { content.sound = .default }
            let id = "\(prefix)\(session.id.uuidString).\(index)"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            } catch {
                invalidate()
                return false
            }
            if token != generation {
                center.removePendingNotificationRequests(withIdentifiers: [id])
            }
        }
        return token == generation
    }

    private func removeExisting(expectedGeneration: Int) async {
        let requests = await center.pendingNotificationRequests()
        guard expectedGeneration == generation else { return }
        let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(notification.request.content.title == "计时完成" ? [] : [.sound])
    }
}
