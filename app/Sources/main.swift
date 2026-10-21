import AppKit
let boot=DispatchTime.now().uptimeNanoseconds
let application=NSApplication.shared
let delegate=ApplicationDelegate(boot:boot)
application.delegate=delegate
application.setActivationPolicy(.accessory)
application.run()
