//
//  ClashStatusTool.swift
//  ClashX Pro
//
//  Created by yicheng on 2020/4/28.
//  Copyright © 2020 west2online. All rights reserved.
//

import Cocoa

class ClashStatusTool {
    static func checkPortConfig(cfg: ClashConfig?) {
        guard let cfg = cfg else { return }
        Logger.log("checkPortConfig: \(cfg.port) \(cfg.socketPort)", level: .debug)
        if cfg.port == 0 || cfg.socketPort == 0 {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("ClashXR Start Error!", comment: "")
            alert.informativeText = NSLocalizedString("Ports Open Fail, Please try to restart ClashXR", comment: "")
            alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
            alert.addButton(withTitle: "Edit Config")
            let ret = alert.runModal()
            if ret == .alertSecondButtonReturn {
                NSWorkspace.shared.openFile(Paths.configPath(for: "config"))
            }
            NSApp.terminate(nil)
        }
    }
}
