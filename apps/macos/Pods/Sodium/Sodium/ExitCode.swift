enum ExitCode {
    case SUCCESS
    case FAILURE

    init (from int: Int32) {
        switch int {
        case 0:  self = .SUCCESS
        default: self = .FAILURE
        }
    }
}

extension Int32 {
    var exitCode: ExitCode { return ExitCode(from: self) }
}
