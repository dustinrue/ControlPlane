import Foundation
import SystemConfiguration
import ControlPlaneSDK

public final class HostAvailabilitySensor: BaseSensor, DynamicKeySensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.hostavailability" }
    public override var pluginDisplayName: String { "Host Availability" }

    private var reachabilityRefs: [String: SCNetworkReachability] = [:]

    public override required init() {
        super.init()
    }

    public override func start() async {
        // Keys are pushed via setMonitoredKeys before or after start; refresh current state.
        refreshSnapshot()
    }

    public override func stop() async {
        for (_, ref) in reachabilityRefs {
            SCNetworkReachabilityUnscheduleFromRunLoop(ref, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        }
        reachabilityRefs.removeAll()
        publishInactive()
    }

    public func setMonitoredKeys(_ keys: [String]) {
        let newSet = Set(keys)
        let oldSet = Set(reachabilityRefs.keys)

        for removed in oldSet.subtracting(newSet) {
            if let ref = reachabilityRefs[removed] {
                SCNetworkReachabilityUnscheduleFromRunLoop(ref, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            }
            reachabilityRefs.removeValue(forKey: removed)
        }

        for added in newSet.subtracting(oldSet) {
            guard let ref = SCNetworkReachabilityCreateWithName(nil, added) else { continue }
            var ctx = SCNetworkReachabilityContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: nil
            )
            SCNetworkReachabilitySetCallback(ref, { _, _, info in
                guard let info else { return }
                Unmanaged<HostAvailabilitySensor>.fromOpaque(info).takeUnretainedValue().refreshSnapshot()
            }, &ctx)
            SCNetworkReachabilityScheduleWithRunLoop(ref, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            reachabilityRefs[added] = ref
        }
        refreshSnapshot()
    }

    private func refreshSnapshot() {
        let readings = reachabilityRefs.map { hostname, ref -> SensorReading in
            var flags: SCNetworkReachabilityFlags = []
            SCNetworkReachabilityGetFlags(ref, &flags)
            let reachable = flags.contains(.reachable) && !flags.contains(.connectionRequired)
            return SensorReading(key: hostname, label: hostname, value: .boolean(reachable))
        }
        publishSnapshot(readings: readings)
    }
}
