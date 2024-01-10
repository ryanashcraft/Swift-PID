import Collections
import Foundation

public enum Outcome {
    case success
    case failure
}

public class RateLimitPIDController {
    private let pidController: PIDController
    private let outcomeWindowSize: Int
    private let targetSuccessRate: Double
    private var outcomes: Deque<Outcome> = []

    /// Initializes a new instance of the PID-based rate limiter.
    ///
    /// - Parameters:
    ///    - kp: The proportional gain. Determines the immediate response of the controller to the current error. A higher `kp` results in a more aggressive response to errors.
    ///    - ki: The integral gain. Accounts for the accumulation of past errors over time, emphasizing the effect of persistent, ongoing failures or successes.
    ///    - kd: The derivative gain. Responds to the rate of change of the error, helping to anticipate and counteract future errors based on current trends.
    ///    - errorWindowSize: Defines the window size for accumulating the integral error. A larger window considers a longer history of errors for a more gradual response.
    ///    - targetSuccessRate: The desired success rate the controller aims to achieve. A higher target may cause the controller to be overly conservative.
    ///    - initialRateLimit: The initial value for the rate limit, serving as the starting point for the PID controller's adjustments.
    ///    - outcomeWindowSize: Specifies the number of recent requests to consider when calculating the current success rate. A smaller window size makes the success rate calculation more responsive to recent outcomes.
    public init(
        kp: Double = 0.2,
        ki: Double = 0.1,
        kd: Double = 0.05,
        errorWindowSize: Int,
        targetSuccessRate: Double,
        initialRateLimit: Double,
        outcomeWindowSize: Int
    ) {
        self.pidController = PIDController(kp: kp, ki: ki, kd: kd, errorWindowSize: errorWindowSize, setpoint: targetSuccessRate, initialOutput: initialRateLimit)
        self.outcomeWindowSize = outcomeWindowSize
        self.targetSuccessRate = targetSuccessRate
    }

    public func record(outcome: Outcome) {
        outcomes.append(outcome)

        if outcomes.count > outcomeWindowSize {
            outcomes.removeFirst(outcomes.count - outcomeWindowSize)
        }

        let successRate = Double(outcomes.filter({ $0 == .success }).count) / Double(outcomes.count)

        pidController.update(processVariable: successRate)
    }

    public var rateLimit: Double {
        pidController.output
    }
}
