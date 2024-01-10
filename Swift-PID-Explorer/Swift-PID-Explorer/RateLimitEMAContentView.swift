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

    var alphaInput: String = "0.1"
    var increaseFactorInput: String = "1.2"
    var decreaseFactorInput: String = "0.9"
    var initialRateLimitInput: String = "2"
    var serverRateLimitInput: String = "15"

    var clock: Int = 0
    var samples: Deque<Sample> = []
    var rateLimitController: RateLimitEMAController?
    var currentRateLimit: Double?

    private var alpha: Double?
    private var increaseFactor: Double?
    private var decreaseFactor: Double?
    private var initialRateLimit: Double?
    private var serverRateLimit: Double?
    private var targetSuccessRate: Double?

    func reset() {
        clock = 0
        samples = []
        rateLimitController = nil
        currentRateLimit = nil
    }

    func applyInputs() {
        alpha = alphaInput.parseDouble()
        increaseFactor = increaseFactorInput.parseDouble()
        decreaseFactor = decreaseFactorInput.parseDouble()
        initialRateLimit = initialRateLimitInput.parseDouble()
        serverRateLimit = serverRateLimitInput.parseDouble()

        if currentRateLimit == nil {
            currentRateLimit = initialRateLimit
        }

        if let alpha, let increaseFactor, let decreaseFactor, let initialRateLimit {
            rateLimitController = RateLimitEMAController(
                initialRateLimit: currentRateLimit ?? initialRateLimit,
                alpha: alpha,
                increaseFactor: increaseFactor,
                decreaseFactor: decreaseFactor
            )
        }
    }

    var errorRate: Double {
        samples.count > 0 ? (Double(samples.filter({ $0.outcome == .failure }).count) / Double(samples.count)) : 0
    }

    func tick() {
        guard let rateLimitController, let serverRateLimit, let currentRateLimit else { return }

        clock += 1

        let outcome: Outcome = currentRateLimit > serverRateLimit ? .success: .failure
        rateLimitController.record(outcome: outcome)
        samples.append(.init(clock: clock, outcome: outcome, rateLimit: currentRateLimit))
        self.currentRateLimit = rateLimitController.throttleDuration
    }
}

@MainActor
struct RateLimitEMAContentView: View {
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
                    TextField("Alpha", text: $viewModel.alphaInput)
                    TextField("Increase Factor", text: $viewModel.increaseFactorInput)
                    TextField("Decrease Factor", text: $viewModel.decreaseFactorInput)

                    Button("Apply") {
                        viewModel.applyInputs()
                    }
                } header: {
                    Text("Inputs")
                }

                if viewModel.rateLimitController != nil {
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

private extension String {
    func parseDouble() -> Double? {
        NumberFormatter().number(from: self)?.doubleValue
    }

    func parseInt() -> Int? {
        NumberFormatter().number(from: self)?.intValue
    }
}
