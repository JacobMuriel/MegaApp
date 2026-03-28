import Foundation
import CoreLocation
import AVFoundation
import Combine

// MARK: - Run status

enum RunStatus {
    case idle, running, paused
}

// MARK: - OutdoorRunTracker
//
// Replicates OutdoorRunTracker.swift from the original FitnessLog Swift app exactly.
//
// Critical invariants — do NOT change these without updating CLAUDE.md:
//
//   1. WALL-CLOCK TIMER.  Elapsed seconds are computed from `Date()` against
//      `runStartDate`, never from an incrementing counter.  This prevents
//      any drift caused by the timer firing late.
//
//   2. ANNOUNCEMENTS ARE LOCATION-DRIVEN.  `announceIfNeeded()` is called
//      inside `processLocations(_:)`, not from the 1-second display timer.
//      Moving it to the timer would break the "half-mile" cue when the user
//      is paused or the timer fires early.
//
//   3. GPS FIX FILTERING.  Fixes are rejected when:
//        • horizontalAccuracy > 25 m  (bad satellite geometry)
//        • fix age > 120 s            (stale cache)
//        • implied speed ≥ 8 m/s     (teleportation artefact)

@MainActor
final class OutdoorRunTracker: NSObject, ObservableObject {

    // MARK: Published state (observed by OutdoorRunView)

    @Published var status:              RunStatus = .idle
    @Published var displayElapsed:      String    = "0:00"
    @Published var distanceMiles:       Double    = 0
    @Published var currentPaceString:   String    = "--:-- /mi"
    @Published var locationAuthStatus:  CLAuthorizationStatus = .notDetermined

    // MARK: Wall-clock timing
    //
    // When running:  elapsed = pausedAccumulatedSeconds + (now − runStartDate)
    // When paused:   elapsed = pausedAccumulatedSeconds  (runStartDate is nil)

    private var runStartDate:               Date? = nil
    private var pausedAccumulatedSeconds:   Int   = 0

    var elapsedSeconds: Int {
        guard let start = runStartDate else { return pausedAccumulatedSeconds }
        return pausedAccumulatedSeconds + Int(Date().timeIntervalSince(start))
    }

    // MARK: GPS

    private let locationManager = CLLocationManager()
    private var lastValidLocation: CLLocation?
    private var distanceMeters:    Double = 0

    // MARK: TTS

    private let synthesizer           = AVSpeechSynthesizer()
    private var lastAnnouncedMilestone = 0   // each unit = 0.5 miles

    // MARK: Display refresh timer (UI only — NOT used for elapsed computation)

    private var displayTimer: Timer?

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate                   = self
        locationManager.desiredAccuracy            = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter             = 5        // metres between updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically  = false
        locationAuthStatus = locationManager.authorizationStatus
    }

    // MARK: - Permissions

    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Run control

    func start() {
        guard status == .idle else { return }
        runStartDate                = Date()
        pausedAccumulatedSeconds    = 0
        distanceMeters              = 0
        distanceMiles               = 0
        lastAnnouncedMilestone      = 0
        lastValidLocation           = nil
        status                      = .running
        setupAudioSession()
        locationManager.startUpdatingLocation()
        startDisplayTimer()
    }

    func pause() {
        guard status == .running else { return }
        // Snapshot elapsed before clearing runStartDate
        pausedAccumulatedSeconds = elapsedSeconds
        runStartDate             = nil
        status                   = .paused
        locationManager.stopUpdatingLocation()
        stopDisplayTimer()
    }

    func resume() {
        guard status == .paused else { return }
        runStartDate = Date()
        status       = .running
        locationManager.startUpdatingLocation()
        startDisplayTimer()
    }

    /// Stops the run and returns final stats. Caller is responsible for
    /// inserting a WorkoutSession into SwiftData.
    func stop() -> (durationSeconds: Int, distanceMiles: Double) {
        let finalElapsed  = elapsedSeconds
        let finalDistance = distanceMiles
        reset()
        return (finalElapsed, finalDistance)
    }

    private func reset() {
        locationManager.stopUpdatingLocation()
        stopDisplayTimer()
        status                   = .idle
        runStartDate             = nil
        pausedAccumulatedSeconds = 0
        distanceMeters           = 0
        distanceMiles            = 0
        lastValidLocation        = nil
        lastAnnouncedMilestone   = 0
        displayElapsed           = "0:00"
        currentPaceString        = "--:-- /mi"
    }

    // MARK: - Display timer (fires every second for UI refresh only)

    private func startDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDisplay()
            }
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func refreshDisplay() {
        let s = elapsedSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        displayElapsed = h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    // MARK: - GPS fix validation

    private func isValidFix(_ loc: CLLocation) -> Bool {
        // Reject bad satellite geometry
        guard loc.horizontalAccuracy > 0, loc.horizontalAccuracy <= 25 else { return false }
        // Reject stale cached fixes
        guard -loc.timestamp.timeIntervalSinceNow <= 120 else { return false }
        // Reject physically impossible speed (> 8 m/s ≈ 17.9 mph for a pedestrian)
        guard loc.speed < 8 else { return false }
        return true
    }

    // MARK: - Location processing

    private func processLocations(_ locations: [CLLocation]) {
        guard status == .running else { return }

        for loc in locations {
            guard isValidFix(loc) else { continue }

            if let last = lastValidLocation {
                distanceMeters += loc.distance(from: last)
                distanceMiles   = distanceMeters / 1609.344
                refreshPace()
            }
            lastValidLocation = loc

            // ⚠️  Announcements are triggered HERE (location-driven), not in the timer.
            announceIfNeeded()
        }
    }

    private func refreshPace() {
        guard distanceMiles > 0.05, elapsedSeconds > 0 else {
            currentPaceString = "--:-- /mi"
            return
        }
        let minPerMile = (Double(elapsedSeconds) / 60.0) / distanceMiles
        currentPaceString = Format.pace(minPerMile)
    }

    // MARK: - TTS milestones
    //
    // One milestone per 0.5 miles (804.67 m).
    // milestone 1 → "Half a mile", 2 → "1 mile", 3 → "1.5 miles", …

    private func announceIfNeeded() {
        let milestone = Int(distanceMeters / 804.67)
        guard milestone > lastAnnouncedMilestone else { return }
        lastAnnouncedMilestone = milestone
        speak(milestoneText(milestone))
    }

    private func milestoneText(_ n: Int) -> String {
        if n == 1 { return "Half a mile" }
        let miles  = Double(n) * 0.5
        let whole  = Int(miles)
        if Double(whole) == miles {
            return "\(whole) \(whole == 1 ? "mile" : "miles")"
        } else {
            return "\(Format.decimal(miles, places: 1)) miles"
        }
    }

    private func speak(_ text: String) {
        let utterance         = AVSpeechUtterance(string: text)
        utterance.rate        = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.voice       = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume      = 1.0
        synthesizer.speak(utterance)
    }

    // MARK: - Audio session
    //
    // playback + duckOthers: lets music keep playing but ducks it during announcements.

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
        try? session.setActive(true)
    }
}

// MARK: - CLLocationManagerDelegate

extension OutdoorRunTracker: CLLocationManagerDelegate {

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in processLocations(locations) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            locationAuthStatus = manager.authorizationStatus
        }
    }
}
