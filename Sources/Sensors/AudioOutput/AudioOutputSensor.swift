import Foundation
import CoreAudio
import ControlPlaneSDK

// MARK: - C-level callback

private func audioPropertyListener(
    _ objectID: AudioObjectID,
    _ numAddresses: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let ptr = clientData else { return kAudioHardwareNoError }
    Unmanaged<AudioOutputSensor>.fromOpaque(ptr).takeUnretainedValue().refreshSnapshot()
    return kAudioHardwareNoError
}

// MARK: - Sensor

public final class AudioOutputSensor: BaseSensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.audiooutput" }
    public override var pluginDisplayName: String { "Audio Output" }

    private var listeningToProperty = false

    public override required init() {
        super.init()
    }

    public override func start() async {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let kr = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            audioPropertyListener,
            Unmanaged.passUnretained(self).toOpaque()
        )
        listeningToProperty = (kr == kAudioHardwareNoError)
        refreshSnapshot()
    }

    public override func stop() async {
        if listeningToProperty {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &addr,
                audioPropertyListener,
                Unmanaged.passUnretained(self).toOpaque()
            )
            listeningToProperty = false
        }
        publishInactive()
    }

    func refreshSnapshot() {
        var defaultOutputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var sz = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddr,
            0, nil,
            &sz, &deviceID
        )

        guard deviceID != kAudioObjectUnknown else {
            publishSnapshot(readings: [
                SensorReading(key: "outputDevice",    label: "Output Device",     value: .string("")),
                SensorReading(key: "outputDeviceUID", label: "Output Device UID", value: .string("")),
            ])
            return
        }

        // Device name
        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameRef: CFString = "" as CFString
        sz = UInt32(MemoryLayout<CFString>.size)
        AudioObjectGetPropertyData(deviceID, &nameAddr, 0, nil, &sz, &nameRef)
        let name = nameRef as String

        // Device UID
        var uidAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uidRef: CFString = "" as CFString
        sz = UInt32(MemoryLayout<CFString>.size)
        AudioObjectGetPropertyData(deviceID, &uidAddr, 0, nil, &sz, &uidRef)
        let uid = uidRef as String

        publishSnapshot(readings: [
            SensorReading(key: "outputDevice",    label: "Output Device",     value: .string(name)),
            SensorReading(key: "outputDeviceUID", label: "Output Device UID", value: .string(uid)),
        ])
    }
}
