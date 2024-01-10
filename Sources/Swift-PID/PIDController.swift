import Collections
import Foundation

public class PIDController {
    public var kp: Double = 0.2
    public var ki: Double = 0.1
    public var kd: Double = 0.05
    public var errorWindowSize: Int

    public var setpoint: Double
    public private(set) var output: Double

    private var errors: Deque<Double> = []

    public init(
        kp: Double = 0.2,
        ki: Double = 0.1,
        kd: Double = 0.05,
        errorWindowSize: Int,
        setpoint: Double,
        initialOutput: Double
    ) {
        self.kp = kp
        self.ki = ki
        self.kd = kd
        self.errorWindowSize = errorWindowSize
        self.setpoint = setpoint
        self.output = initialOutput
    }

    private func record(error: Double) {
        errors.append(error)

        if errors.count > errorWindowSize {
            errors.removeFirst(errors.count - errorWindowSize)
        }
    }

    public var errorSum: Double {
        errors.reduce(0, +)
    }

    public func update(processVariable: Double) {
        // Calculate and record error
        let error = setpoint - processVariable
        record(error: error)

        // Proportional
        let p = kp * error

        // Integral
        let i = ki * errorSum

        // Derivative
        let previousError = errors.last ?? 0
        let d = kd * (error - previousError)

        // Update
        self.output = output + (p + i + d)
    }
}
