import Charts
import Collections
import SwiftUI
import PID

@Observable
private class ViewModel {
    var setpointInput: String = "0"
    var errorWindowSizeInput: String = "30"
    var kpInput: String = "0.1"
    var kdInput: String = "0.01"
    var kiInput: String = "0.05"

    var pidController = PIDController(errorWindowSize: 30, setpoint: 0, initialOutput: 0)

    var clock: Int = 0
    var setpoints: Deque<(Int, Double)> = []
    var processVariables: Deque<(Int, Double)> = []
    var outputs: Deque<(Int, Double)> = []

    func tick() async {
        clock += 1

        if let setpoint = NumberFormatter().number(from: setpointInput)?.doubleValue {
            pidController.setpoint = setpoint
        }

        if let kp = NumberFormatter().number(from: kpInput)?.doubleValue {
            pidController.kp = kp
        }

        if let ki = NumberFormatter().number(from: kiInput)?.doubleValue {
            pidController.ki = ki
        }

        if let kd = NumberFormatter().number(from: kdInput)?.doubleValue {
            pidController.kd = kd
        }

        if let errorWindowSize = NumberFormatter().number(from: errorWindowSizeInput)?.intValue {
            pidController.errorWindowSize = errorWindowSize
        }

        let lastProcessVariable = processVariables.last?.1 ?? 0
        let lastOutput = outputs.last?.1 ?? 0
        let processVariable = lastProcessVariable + lastOutput

        pidController.update(processVariable: processVariable)

        setpoints.append((clock, pidController.setpoint))
        processVariables.append((clock, processVariable))
        outputs.append((clock, pidController.output))
    }
}

@MainActor
struct PIDContentView: View {
    @State private var viewModel = ViewModel()

    var body: some View {
        VStack {
            Chart {
                ForEach(viewModel.setpoints, id: \.0) { (x, y) in
                    LineMark(
                        x: .value("Time", x),
                        y: .value("Setpoint", y)
                    )
                    .foregroundStyle(by: .value("Metric", "Setpoint"))
                }

                ForEach(viewModel.processVariables, id: \.0) { (x, y) in
                    LineMark(
                        x: .value("Time", x),
                        y: .value("Process Variable", y)
                    )
                    .foregroundStyle(by: .value("Metric", "Process Variable"))
                }

                ForEach(viewModel.outputs, id: \.0) { (x, y) in
                    LineMark(
                        x: .value("Time", x),
                        y: .value("Output", y)
                    )
                    .foregroundStyle(by: .value("Metric", "Output"))
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
                    TextField("Setpoint", text: $viewModel.setpointInput)
                    TextField("Error Window Size", text: $viewModel.errorWindowSizeInput)
                    TextField("KP", text: $viewModel.kpInput)
                    TextField("KD", text: $viewModel.kdInput)
                    TextField("KI", text: $viewModel.kiInput)
                } header: {
                    Text("Inputs")
                }
            }
        }
        .task {
            while true {
                try! await Task.sleep(seconds: 1)
                await viewModel.tick()
            }
        }
    }
}

#Preview {
    PIDContentView()
}
