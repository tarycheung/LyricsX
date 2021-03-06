//
//  AppDelegate.swift
//
//  This file is part of LyricsX
//  Copyright (C) 2017  Xander Deng
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Cocoa
import ServiceManagement
import Then
import MASShortcut

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    static var shared: AppDelegate? {
        return NSApplication.shared().delegate as? AppDelegate
    }
    
    @IBOutlet weak var lyricsOffsetTextField: NSTextField!
    @IBOutlet weak var lyricsOffsetStepper: NSStepper!
    @IBOutlet weak var statusBarMenu: NSMenu!
    
    var desktopLyrics: NSWindowController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        registerUserDefaults()
        
        desktopLyrics = NSStoryboard.main().instantiateController(withIdentifier: .DesktopLyricsWindow)
        desktopLyrics?.showWindow(nil)
        desktopLyrics?.window?.makeKeyAndOrderFront(nil)
        
        MenuBarLyrics.shared.statusItem.menu = statusBarMenu
        
        let controller = AppController.shared
        lyricsOffsetStepper.bind(NSValueBinding, to: controller, withKeyPath: #keyPath(AppController.lyricsOffset), options: [NSContinuouslyUpdatesValueBindingOption: true])
        lyricsOffsetTextField.bind(NSValueBinding, to: controller, withKeyPath: #keyPath(AppController.lyricsOffset), options: [NSContinuouslyUpdatesValueBindingOption: true])
        
        setupShortcuts()
        
        NSRunningApplication.runningApplications(withBundleIdentifier: LyricsXHelperIdentifier).forEach { $0.terminate() }
        if !SMLoginItemSetEnabled(LyricsXHelperIdentifier as CFString, defaults[.LaunchAndQuitWithPlayer]) {
            log("Failed to set login item enabled")
        }
        
        let sharedKeys = [
            UserDefaults.DefaultKeys.LaunchAndQuitWithPlayer.rawValue,
            UserDefaults.DefaultKeys.PreferredPlayerIndex.rawValue
        ]
        sharedKeys.forEach {
            groupDefaults.bind($0, to: defaults, withKeyPath: $0)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        UserDefaults.standard.synchronize()
        if defaults[.LaunchAndQuitWithPlayer] {
            let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/LyricsXHelper.app")
            NSWorkspace.shared().launchApplication(url.path)
        }
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.identifier {
        case "WriteToiTunes"?:
            return MusicPlayerManager.shared.player is iTunes && AppController.shared.currentLyrics != nil
        case "WrongLyrics"?:
            return AppController.shared.currentLyrics != nil
        default:
            return true
        }
    }
    
    private func setupShortcuts() {
        let binder = MASShortcutBinder.shared()!
        binder.bindShortcut(with: .ShortcutOffsetIncrease) {
            self.increaseOffset(nil)
        }
        binder.bindShortcut(with: .ShortcutOffsetDecrease) {
            self.decreaseOffset(nil)
        }
        binder.bindShortcut(with: .ShortcutWriteToiTunes) {
            self.writeToiTunes(nil)
        }
        binder.bindShortcut(with: .ShortcutWrongLyrics) {
            self.wrongLyrics(nil)
        }
    }
    
    // MARK: - Menubar Action
    
    @IBAction func increaseOffset(_ sender: Any?) {
        AppController.shared.lyricsOffset += 100
    }
    
    @IBAction func decreaseOffset(_ sender: Any?) {
        AppController.shared.lyricsOffset -= 100
    }
    
    @IBAction func writeToiTunes(_ sender: Any?) {
        AppController.shared.writeToiTunes(overwrite: true)
    }
    
    @IBAction func wrongLyrics(_ sender: Any?) {
        let track = MusicPlayerManager.shared.player?.currentTrack
        let title = track?.name ?? ""
        let artist = track?.artist ?? ""
        WrongLyricsUtil.shared.noMatching(title: title, artist: artist)
        AppController.shared.currentLyrics = nil
    }
    
    func registerUserDefaults() {
        let defaultsUrl = Bundle.main.url(forResource: "UserDefaults", withExtension: "plist")!
        var defaults = NSDictionary(contentsOf: defaultsUrl) as! [String: AnyObject]
        defaults["DesktopLyricsColor"] = NSKeyedArchiver.archivedData(withRootObject: #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)) as AnyObject
        defaults["DesktopLyricsShadowColor"] = NSKeyedArchiver.archivedData(withRootObject: #colorLiteral(red: 0, green: 0.9914394021, blue: 1, alpha: 1)) as AnyObject
        defaults["DesktopLyricsBackgroundColor"] = NSKeyedArchiver.archivedData(withRootObject: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.6041579279)) as AnyObject
        UserDefaults.standard.register(defaults: defaults)
    }
}

extension MASShortcutBinder {
    
    func bindShortcut<T>(with defaultKay: UserDefaults.DefaultKey<T>, to action: @escaping () -> Void) {
        bindShortcut(withDefaultsKey: defaultKay.rawValue, toAction: action)
    }
}
