import Foundation
import TermKit

func installCrashHandler() {
    let handler: @convention(c) (Int32) -> Void = { sig in
        // While not strictly async-signal-safe, doing this in a generic fatal handler will typically succeed in grabbing the stack context.
        var report = "=== CBTC TERMINAL CLIENT CRASH ===\n"
        report += "Signal received: \(sig)\n"
        report += "Date: \(Date())\n\n"
        report += "Call Stack Symbols:\n"
        report += Thread.callStackSymbols.joined(separator: "\n")
        report += "\n=================================="
        
        let path = FileManager.default.currentDirectoryPath + "/crash_backtrace.txt"
        try? report.write(toFile: path, atomically: true, encoding: .utf8)
        
        // Re-raise the signal to terminate correctly
        signal(sig, SIG_DFL)
        raise(sig)
    }
    
    signal(SIGABRT, handler)
    signal(SIGILL, handler)
    signal(SIGSEGV, handler)
    signal(SIGFPE, handler)
    signal(SIGBUS, handler)
}

installCrashHandler()
Application.prepare()

let top = Application.top
let win = Window(" CBTC METRO SIMULATOR - TERMINAL ")
win.width = Dim.fill()
win.height = Dim.fill()
top.addSubview(win)

let ui = TerminalUI(window: win)
ui.start()

Application.run()

