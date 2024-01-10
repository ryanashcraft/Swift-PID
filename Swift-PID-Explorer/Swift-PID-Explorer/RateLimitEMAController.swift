import PID
import Foundation

class RateLimitEMAController {
    private let alpha: Double
    private let increaseFactor: Double
    private let decreaseFactor: Double

    private var emaDuration: Double
    public private(set) var throttleDuration: Double

    init(
        initialRateLimit: Double,
        alpha: Double = 0.1,
        increaseFactor: Double = 1.2,
        decreaseFactor: Double = 0.9
    ) {
        self.throttleDuration = initialRateLimit
        self.emaDuration = initialRateLimit
        self.alpha = alpha
        self.increaseFactor = increaseFactor
        self.decreaseFactor = decreaseFactor
    }

    func record(outcome: Outcome) {
        switch outcome {
        case .failure:
            throttleDuration *= increaseFactor
        case .success:
            throttleDuration *= decreaseFactor
        }

        // Update EMA
        emaDuration = alpha * throttleDuration + (1 - alpha) * emaDuration

        // Use EMA as the new throttle duration to stabilize changes
        throttleDuration = emaDuration
    }
}
