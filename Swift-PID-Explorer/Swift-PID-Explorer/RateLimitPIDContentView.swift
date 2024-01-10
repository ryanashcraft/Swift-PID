import Charts
import Collections
import SwiftUI
import PID

@Observable
private class ViewModel {
    struct Sample {
        let clock: Int
        let outcome: Outcome
        let rateLimit: Double
    }

    var kpInput: String = "2"
    var kiInput: String = "0.05"
    var kdInput: String = "0.01"
    var errorWindowSizeInput: String = "20"
    var outcomeWindowSizeInput: String = "2"
    var initialRateLimitInput: String = "5"
    var serverRateLimitInput: String = "15"
    var targetSuccessRateInput: String = "0.98"

    var clock: Int = 0
    var samples: Deque<Sample> = []
    var pidController: RateLimitPIDController?
    var currentRateLimit: Double?

    private var kp: Double?
    private var ki: Double?
    private var kd: Double?
    private var errorWindowSize: Int?
    private var outcomeWindowSize: Int?
    private var initialRateLimit: Double?
    private var serverRateLimit: Double?
    private var targetSuccessRate: Double?

    func reset() {
        clock = 0
        samples = []
        pidController = nil
        currentRateLimit = nil
    }

    func applyInputs() {
        kp = kpInput.parseDouble()
        ki = kiInput.parseDouble()
        kd = kdInput.parseDouble()
        errorWindowSize = errorWindowSizeInput.parseInt()
        outcomeWindowSize = outcomeWindowSizeInput.parseInt()
        initialRateLimit = initialRateLimitInput.parseDouble()
        serverRateLimit = serverRateLimitInput.parseDouble()
        targetSuccessRate = targetSuccessRateInput.parseDouble()

        if currentRateLimit == nil {
            currentRateLimit = initialRateLimit
        }

        if let kp, let ki, let kd, let errorWindowSize, let outcomeWindowSize, let initialRateLimit, let targetSuccessRate {
            pidController = RateLimitPIDController(kp: kp, ki: ki, kd: kd, errorWindowSize: errorWindowSize, targetSuccessRate: targetSuccessRate, initialRateLimit: currentRateLimit ?? initialRateLimit, outcomeWindowSize: outcomeWindowSize)
        }
    }

    var errorRate: Double {
        samples.count > 0 ? (Double(samples.filter({ $0.outcome == .failure }).count) / Double(samples.count)) : 0
    }

    func tick() {
        guard let pidController, let serverRateLimit, let currentRateLimit else { return }

        clock += 1

        let outcome: Outcome = currentRateLimit > serverRateLimit ? .success: .failure
        pidController.record(outcome: outcome)
        samples.append(.init(clock: clock, outcome: outcome, rateLimit: currentRateLimit))
        self.currentRateLimit = pidController.rateLimit
    }
}

@MainActor
struct RateLimitPIDContentView: View {
    @State private var viewModel = ViewModel()
    @State private var isPlaying = false
    @State private var speed: TimeInterval = 0.1

    nonisolated func run() async {
        while true {
            try! await Task.sleep(seconds: speed)

            await MainActor.run {
                if isPlaying {
                    viewModel.tick()
                }
            }
        }
    }

    var body: some View {
        VStack {
            Chart {
                ForEach(viewModel.samples, id: \.clock) { sample in
                    PointMark(
                        x: .value("Time", sample.clock),
                        y: .value("Rate Limit", sample.rateLimit)
                    )
                    .foregroundStyle(sample.outcome == .success ? .green : .red)
                }
            }
            .chartXAxis(.automatic)
            .chartYAxis(.automatic)
            .chartLegend(.visible)
            .padding()
        }
        .inspector(isPresented: .constant(true)) {
            Form {
                Section {
                    TextField("Initial Rate Limit", text: $viewModel.initialRateLimitInput)
                    TextField("Server Rate Limit", text: $viewModel.serverRateLimitInput)
                    TextField("Target Success Rate", text: $viewModel.targetSuccessRateInput)
                    TextField("Error Window Size", text: $viewModel.errorWindowSizeInput)
                    TextField("Outcome Window Size", text: $viewModel.outcomeWindowSizeInput)
                    TextField("KP", text: $viewModel.kpInput)
                    TextField("KI", text: $viewModel.kiInput)
                    TextField("KD", text: $viewModel.kdInput)

                    Button("Apply") {
                        viewModel.applyInputs()
                    }
                } header: {
                    Text("Inputs")
                }

                if viewModel.pidController != nil {
                    Section {
                        Button {
                            isPlaying.toggle()
                        } label: {
                            if isPlaying {
                                Image(systemName: "pause")
                            } else {
                                Image(systemName: "play")
                            }
                        }
                        
                        Picker("Speed", selection: $speed) {
                            Text("1/5ms").tag(0.005)
                            Text("1/10ms").tag(0.01)
                            Text("1/50ms").tag(0.05)
                            Text("1/100ms").tag(0.1)
                            Text("1/200ms").tag(0.2)
                            Text("1/500ms").tag(0.5)
                            Text("1/1s").tag(1.0)
                        }
                    }

                    Section {
                        Button {
                            viewModel.reset()
                        } label: {
                            Text("Reset")
                        }
                    }

                    Section {
                        LabeledContent("Error Rate") {
                            Text("\(viewModel.errorRate, specifier: "%.2f")")
                        }
                    }
                }
            }
        }
        .task {
            await run()
        }
    }
}

#Preview {
    PIDContentView()
}

private extension String {
    func parseDouble() -> Double? {
        NumberFormatter().number(from: self)?.doubleValue
    }

    func parseInt() -> Int? {
        NumberFormatter().number(from: self)?.intValue
    }
}
