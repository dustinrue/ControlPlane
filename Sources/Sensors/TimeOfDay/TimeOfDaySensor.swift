import Foundation
import ControlPlaneSDK

public final class TimeOfDaySensor: BaseSensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.timeofday" }
    public override var pluginDisplayName: String { "Time of Day" }

    private var timerTask: Task<Void, Never>?

    public override required init() {
        super.init()
    }

    public override func start() async {
        refreshSnapshot()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                let now = Date()
                let nextMinute = Calendar.current.nextDate(
                    after: now,
                    matching: DateComponents(second: 0),
                    matchingPolicy: .nextTime
                ) ?? now.addingTimeInterval(60)
                let delay = nextMinute.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                guard !Task.isCancelled else { return }
                self?.refreshSnapshot()
            }
        }
    }

    public override func stop() async {
        timerTask?.cancel()
        timerTask = nil
        publishInactive()
    }

    private func refreshSnapshot() {
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .weekday], from: now)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let timeString = String(format: "%02d:%02d", hour, minute)
        let weekdaySymbols = cal.weekdaySymbols
        let weekdayIdx = (comps.weekday ?? 1) - 1
        let dayName = weekdaySymbols.indices.contains(weekdayIdx) ? weekdaySymbols[weekdayIdx] : ""

        publishSnapshot(readings: [
            SensorReading(key: "hour",      label: "Hour",       value: .number(Double(hour))),
            SensorReading(key: "minute",    label: "Minute",     value: .number(Double(minute))),
            SensorReading(key: "time",      label: "Time",       value: .string(timeString)),
            SensorReading(key: "dayOfWeek", label: "Day of Week", value: .string(dayName)),
        ])
    }
}
