//
//  TriggerController.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit
 
protocol TriggerControllerDelegate: AnyObject {
    func triggerController(_ controller: TriggerController, didUpdateState state: TriggerState)
    func triggerController(_ controller: TriggerController, didDetectDirection direction: TriggerDirection)
}
 
final class TriggerController: ObservableObject {
    static let shared = TriggerController()
 
    weak var delegate: TriggerControllerDelegate?
 
    var onTrigger: ((TriggerDirection) -> Void)?
 
    @Published private(set) var state = TriggerState() {
        didSet {
            delegate?.triggerController(self, didUpdateState: state)
        }
    }
 
    private var observation: NSKeyValueObservation?
    private let audioSession = AVAudioSession.sharedInstance()
 
    private var hiddenTriggerView: MPVolumeView?
    private var systemSlider: UISlider?
 
    private let silentEngine = AVAudioEngine()
    private let silentPlayer = AVAudioPlayerNode()
 
    private var lastSliderUpdateTime: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.05

    // When false the volume button behaves normally (lobby, menus).
    // When true (gameplay) the button is intercepted as a game trigger.
    private var isEnabled = false
 
    private init() {
        try? audioSession.setCategory(.playback, options: [.duckOthers])
        try? audioSession.setActive(true)

        let currentVolume = audioSession.outputVolume
        state.baselineTrigger = min(max(currentVolume, 0.05), 0.95)

        startSilentPlayback()
        
        DispatchQueue.main.async {
            self.setupHiddenTriggerView()
        }
 
        observation = audioSession.observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
            guard let self = self else { return }
            guard let oldVal = change.oldValue, let newVal = change.newValue, oldVal != newVal else { return }

            // Outside gameplay, keep the Master slider in sync with hardware volume buttons.
            guard self.isEnabled else {
                DispatchQueue.main.async {
                    self.state.baselineTrigger = min(max(newVal, 0.05), 0.95)
                }
                return
            }

            DispatchQueue.main.async {
                if abs(newVal - self.state.baselineTrigger) < 0.001 {
                    return
                }

                let direction: TriggerDirection = newVal > oldVal ? .up : .down

                self.triggerVisualFeedback(message: direction == .up ? "Trigger UP Hit" : "Trigger DOWN Hit")
                self.delegate?.triggerController(self, didDetectDirection: direction)
                self.onTrigger?(direction)

                // Tombol melewati throttle supaya loop hardware langsung ter-reset instan
                self.pinTrigger(to: self.state.baselineTrigger, forceImmediate: true)
            }
        }
    }
 
    // MARK: - Silent audio session keep-alive
 
    private func startSilentPlayback() {
        silentEngine.attach(silentPlayer)
        silentEngine.connect(silentPlayer, to: silentEngine.mainMixerNode, format: nil)
        silentEngine.mainMixerNode.outputVolume = 0.0
 
        try? silentEngine.start()
 
        let format = silentEngine.mainMixerNode.outputFormat(forBus: 0)
        let frameCount = AVAudioFrameCount(format.sampleRate * 1.0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
 
        silentPlayer.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        silentPlayer.play()
    }
 
    // MARK: - Hidden system trigger (volume) slider
 
    private func setupHiddenTriggerView() {
        let triggerView = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 100, height: 40))
        triggerView.alpha = 0.001
        triggerView.isUserInteractionEnabled = false
        self.hiddenTriggerView = triggerView
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        window.addSubview(triggerView)
 
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.systemSlider = self.findSliderDeep(in: triggerView)
            self.pinTrigger(to: self.state.baselineTrigger, forceImmediate: true)
        }
    }
 
    private func findSliderDeep(in view: UIView) -> UISlider? {
        if let slider = view as? UISlider {
            return slider
        }
        for subview in view.subviews {
            if let slider = findSliderDeep(in: subview) {
                return slider
            }
        }
        return nil
    }
 
    func pinTrigger(to value: Float, forceImmediate: Bool = false) {
        if systemSlider == nil, let triggerView = hiddenTriggerView {
            systemSlider = findSliderDeep(in: triggerView)
        }
 
        guard let slider = systemSlider else {
            print("Error on systemSlider")
            return
        }
 
        if !forceImmediate {
            let now = Date()
            guard now.timeIntervalSince(lastSliderUpdateTime) >= throttleInterval else { return }
            lastSliderUpdateTime = now
        }
 
        slider.setValue(value, animated: false)
        slider.sendActions(for: .valueChanged)
    }
 
    // MARK: - Public API untuk View/ViewController
 
    func updateBaseline(_ value: Float) {
        state.baselineTrigger = value
        pinTrigger(to: value, forceImmediate: false)
    }
 
    /// Enable trigger interception — call when entering the game scene.
    func reactivate() {
        isEnabled = true
        try? audioSession.setActive(true)
        if !silentEngine.isRunning { try? silentEngine.start() }
        if !silentPlayer.isPlaying { silentPlayer.play() }

        if hiddenTriggerView?.superview == nil {
            setupHiddenTriggerView()
        } else {
            pinTrigger(to: state.baselineTrigger, forceImmediate: true)
        }
    }

    /// Disable trigger interception — call when leaving the game scene so the
    /// volume button restores normal system-volume behaviour in the lobby/menus.
    func disable() {
        isEnabled = false
        hiddenTriggerView?.removeFromSuperview()
        systemSlider = nil
    }
 
    private func triggerVisualFeedback(message: String) {
        state.statusMessage = message
        state.showIndicator = true
 
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.state.showIndicator = false
        }
    }
 
    deinit {
        observation?.invalidate()
    }
}
 
