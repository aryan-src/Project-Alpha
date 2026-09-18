import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate.shared
app.delegate = delegate
app.run()
