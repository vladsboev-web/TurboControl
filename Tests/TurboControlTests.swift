import Foundation

private var passedTests = 0
private var failedTests = 0

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String, line: Int = #line) {
    if actual == expected {
        passedTests += 1
    } else {
        failedTests += 1
        fputs("FAIL [line \(line)] \(name): expected \(expected), got \(actual)\n", stderr)
    }
}

private func expectTrue(_ condition: Bool, _ name: String, line: Int = #line) {
    if condition {
        passedTests += 1
    } else {
        failedTests += 1
        fputs("FAIL [line \(line)] \(name): expected true\n", stderr)
    }
}

private func makeInput(
    reason: AutomationReason = .metricsTick,
    isTurboDisabled: Bool = false,
    isPluggedIn: Bool = true,
    batteryPercentage: Int = 80,
    cpuTemp: Double = 60.0,
    frontmostAppRule: AppTurboRule? = nil,
    onACPowerAction: PowerTurboAction = .keep,
    onBatteryPowerAction: PowerTurboAction = .keep,
    isPowerAutomationActive: Bool = false,
    allowTurboOnLowBatteryWhenPluggedIn: Bool = false,
    autoTempEnabled: Bool = false,
    autoTempDisableThreshold: Double = 90.0,
    autoTempEnableThreshold: Double = 75.0,
    autoBatteryEnabled: Bool = false,
    autoBatteryDisableThreshold: Double = 20.0,
    autoBatteryEnableThreshold: Double = 30.0
) -> AutomationInput {
    AutomationInput(
        reason: reason,
        isTurboDisabled: isTurboDisabled,
        isPluggedIn: isPluggedIn,
        batteryPercentage: batteryPercentage,
        cpuTemp: cpuTemp,
        frontmostAppRule: frontmostAppRule,
        onACPowerAction: onACPowerAction,
        onBatteryPowerAction: onBatteryPowerAction,
        isPowerAutomationActive: isPowerAutomationActive,
        allowTurboOnLowBatteryWhenPluggedIn: allowTurboOnLowBatteryWhenPluggedIn,
        autoTempEnabled: autoTempEnabled,
        autoTempDisableThreshold: autoTempDisableThreshold,
        autoTempEnableThreshold: autoTempEnableThreshold,
        autoBatteryEnabled: autoBatteryEnabled,
        autoBatteryDisableThreshold: autoBatteryDisableThreshold,
        autoBatteryEnableThreshold: autoBatteryEnableThreshold
    )
}

func runSmartFanCurveTests() {
    expectEqual(FanControlService.calculateSmartRPM(temp: 45.0), 1500, "Below 52C clamps to 1500 RPM")
    expectEqual(FanControlService.calculateSmartRPM(temp: 52.0), 1500, "At 52C is 1500 RPM")
    expectEqual(FanControlService.calculateSmartRPM(temp: 55.0), 2000, "At 55C is 2000 RPM")
    expectEqual(FanControlService.calculateSmartRPM(temp: 60.0), 2800, "At 60C midpoint is 2800 RPM")
    expectEqual(FanControlService.calculateSmartRPM(temp: 65.0), 3600, "At 65C is 3600 RPM")
    expectEqual(FanControlService.calculateSmartRPM(temp: 75.0), 5200, "At 75C is 5200 RPM")
    expectEqual(FanControlService.calculateSmartRPM(temp: 84.0), 7200, "At 84C hits 7200 RPM")
    expectEqual(FanControlService.calculateSmartRPM(temp: 98.0), 7200, "Above 84C stays 7200 RPM")
    
    var prev = 0
    var monotonic = true
    for temp in 40...100 {
        let rpm = FanControlService.calculateSmartRPM(temp: Double(temp))
        if rpm < prev { monotonic = false; break }
        prev = rpm
    }
    expectTrue(monotonic, "Smart fan curve must be monotonically non-decreasing")
}

func runAutomationRuleTests() {
    // 1. Active app priority
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            isTurboDisabled: false,
            cpuTemp: 50.0,
            frontmostAppRule: .disable,
            autoTempEnabled: true
        )),
        .disableTurbo,
        "App rule .disable disables Turbo even at cool temp"
    )
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            isTurboDisabled: true,
            isPluggedIn: false,
            batteryPercentage: 10,
            cpuTemp: 95.0,
            frontmostAppRule: .enable,
            autoTempEnabled: true,
            autoBatteryEnabled: true
        )),
        .enableTurbo,
        "App rule .enable overrides hot temp and low battery"
    )
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            isTurboDisabled: true,
            frontmostAppRule: .disable
        )),
        .noChange,
        "App rule matching current state returns .noChange"
    )
    
    // 2. Power transition rules
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            reason: .powerTransition,
            isTurboDisabled: true,
            isPluggedIn: true,
            onACPowerAction: .enable
        )),
        .enableTurbo,
        "Plugged in with .enable turns Turbo on"
    )
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            reason: .powerTransition,
            isTurboDisabled: true,
            isPluggedIn: true,
            cpuTemp: 92.0,
            onACPowerAction: .enable,
            autoTempEnabled: true,
            autoTempDisableThreshold: 90.0
        )),
        .noChange,
        "Plugged in .enable is blocked if CPU temp is above disable threshold"
    )
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            reason: .powerTransition,
            isTurboDisabled: true,
            isPluggedIn: true,
            batteryPercentage: 15,
            onACPowerAction: .enable,
            allowTurboOnLowBatteryWhenPluggedIn: false,
            autoBatteryEnabled: true,
            autoBatteryDisableThreshold: 20.0
        )),
        .noChange,
        "Plugged in .enable is blocked on low battery unless explicitly allowed"
    )
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            reason: .powerTransition,
            isTurboDisabled: true,
            isPluggedIn: true,
            batteryPercentage: 15,
            onACPowerAction: .enable,
            allowTurboOnLowBatteryWhenPluggedIn: true,
            autoBatteryEnabled: true,
            autoBatteryDisableThreshold: 20.0
        )),
        .enableTurbo,
        "Plugged in .enable succeeds on low battery when allowTurboOnLowBatteryWhenPluggedIn is true"
    )
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            reason: .powerTransition,
            isTurboDisabled: false,
            isPluggedIn: false,
            onBatteryPowerAction: .disable
        )),
        .disableTurbo,
        "Unplugged with .disable turns Turbo off"
    )
    
    // 3. Temperature thresholds & sensor failure guard
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            isTurboDisabled: false,
            cpuTemp: 90.0,
            autoTempEnabled: true,
            autoTempDisableThreshold: 90.0
        )),
        .disableTurbo,
        "Reaching disable temp threshold disables Turbo"
    )
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            isTurboDisabled: true,
            cpuTemp: 0.0,
            autoTempEnabled: true,
            autoTempDisableThreshold: 90.0,
            autoTempEnableThreshold: 75.0
        )),
        .noChange,
        "Sensor error (0C) never re-enables Turbo"
    )
    
    // 4. Battery thresholds
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            isTurboDisabled: false,
            isPluggedIn: false,
            batteryPercentage: 20,
            autoBatteryEnabled: true,
            autoBatteryDisableThreshold: 20.0
        )),
        .disableTurbo,
        "Low battery on battery power disables Turbo"
    )
    
    // 5. Hysteresis re-enable
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            isTurboDisabled: true,
            isPluggedIn: true,
            cpuTemp: 82.0,
            autoTempEnabled: true,
            autoTempDisableThreshold: 90.0,
            autoTempEnableThreshold: 75.0
        )),
        .noChange,
        "Temp inside hysteresis band (75 < 82 < 90) keeps Turbo disabled"
    )
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            isTurboDisabled: true,
            isPluggedIn: true,
            batteryPercentage: 80,
            cpuTemp: 74.0,
            autoTempEnabled: true,
            autoTempDisableThreshold: 90.0,
            autoTempEnableThreshold: 75.0
        )),
        .enableTurbo,
        "Cooling below enable threshold re-enables Turbo"
    )
    expectEqual(
        AutomationService.decideTurboState(input: makeInput(
            isTurboDisabled: true,
            isPluggedIn: false,
            batteryPercentage: 50,
            cpuTemp: 60.0,
            autoTempEnabled: true,
            autoTempDisableThreshold: 90.0,
            autoTempEnableThreshold: 75.0,
            autoBatteryEnabled: true,
            autoBatteryDisableThreshold: 20.0,
            autoBatteryEnableThreshold: 30.0
        )),
        .noChange,
        "Cooling down on battery does not re-enable when battery automation requires charging"
    )
}

@main
struct TestRunner {
    static func main() {
        runSmartFanCurveTests()
        runAutomationRuleTests()
        
        print("TurboControlTests: \(passedTests) passed, \(failedTests) failed")
        if failedTests > 0 {
            exit(1)
        }
    }
}
