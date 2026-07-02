import SwiftUI
import AVFoundation
import CoreHaptics

struct FlashlightView: View {
    @State private var isFiring = false
    @State private var hapticEngine: CHHapticEngine?
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: isFiring ? "flame.fill" : "flashlight.off.fill")
                .font(.system(size: 80))
                .foregroundColor(isFiring ? .orange : .gray)
            
            // Fire Button
            Button(action: {
                fireMuzzleFlash()
                playGunshotHaptic()
            }) {
                Text("FIRE!")
                    .font(.title)
                    .bold()
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            // Get Hit Button
            Button(action: {
                playGetHitHaptic()
            }) {
                Text("TAKE DAMAGE")
                    .font(.title)
                    .bold()
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .onAppear {
            // Boot up the haptic engine onAppear
            prepareHaptics()
        }
    }

    // MARK: - Flashlight Logic
    
    func fireMuzzleFlash() {
        isFiring = true
        Task {
            setTorch(on: true)
            try? await Task.sleep(nanoseconds: 50_000_000)
            setTorch(on: false)
            await MainActor.run { isFiring = false }
        }
    }
    
    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if on {
                if device.isTorchModeSupported(.on) {
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                }
            } else {
                if device.isTorchActive || device.torchMode != .off {
                    device.torchMode = .off
                }
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error)")
        }
    }
    
    // MARK: - Audio (What else would it be)
    func playGunshotAudio() {
            guard let soundAsset = NSDataAsset(name: "mixedgun-rayne") else {
                print("Could not find the audio asset in the catalog.")
                return
            }
            
            do {
                audioPlayer = try AVAudioPlayer(data: soundAsset.data)
                
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } catch {
                print("Failed to play audio: \(error.localizedDescription)")
            }
        }
    
    // MARK: - CoreHaptics Logic
    
    func prepareHaptics() {
        // Check if the device actually supports haptics (iPads usually don't)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("There was an error creating the haptic engine: \(error.localizedDescription)")
        }
    }
    
    func playGunshotHaptic() {
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
            
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            
            do {
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                // FIX: Changed createPlayer to makePlayer
                let player = try hapticEngine?.makePlayer(with: pattern)
                try player?.start(atTime: 0)
            } catch {
                print("Failed to play gunshot haptic: \(error.localizedDescription)")
            }
        }
    
    func playGetHitHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
        
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 0.4)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play get hit haptic: \(error.localizedDescription)")
        }
    }
}
