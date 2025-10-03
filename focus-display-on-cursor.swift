#!/usr/bin/env swift
import Foundation
import CoreGraphics
import AppKit

let YABAI = "/opt/homebrew/bin/yabai"   // <-- change if your path differs

// MARK: - Config knobs
let DEBUG = false                          // set to true to enable debug logging
let debounceSeconds: TimeInterval = 0.18   // avoid double switch on corners
let throttleMs: UInt64 = 12                // handle at most every 12ms (~83Hz)

// MARK: - State
var eventTap: CFMachPort?
var lastDisplayID: CGDirectDisplayID = 0
var lastSwitch = Date.distantPast
var lastHandledTs: UInt64 = 0

// Cached display rectangles to avoid per-event CoreGraphics queries
var displayRects: [(id: CGDirectDisplayID, rect: CGRect)] = []

// MARK: - Helpers
@discardableResult
func sh(_ args: [String]) -> (stdout: Data, stderr: Data, exitCode: Int32) {
    let p = Process()
    p.launchPath = "/usr/bin/env"
    p.arguments = args
    let out = Pipe()
    let err = Pipe()
    p.standardOutput = out
    p.standardError = err
    p.launch()
    p.waitUntilExit()
    return (
        out.fileHandleForReading.readDataToEndOfFile(),
        err.fileHandleForReading.readDataToEndOfFile(),
        p.terminationStatus
    )
}

struct YabaiDisplay: Decodable { let index: Int }
struct YabaiWindow: Decodable {
    let id: Int
    let pid: Int
    let app: String
    let role: String
    let `is-minimized`: Bool?
}
struct YabaiSpace: Decodable {
    let index: Int
    let `is-visible`: Bool
}

// Ask yabai which display the mouse is on *right now* and focus it.
func focusDisplayUnderMouse() {
    let displayResult = sh([YABAI,"-m","query","--displays","--display","mouse"])

    guard let d = try? JSONDecoder().decode(YabaiDisplay.self, from: displayResult.stdout) else {
        if DEBUG {
            fputs("ERROR: Failed to decode display query\n", stderr)
            if let str = String(data: displayResult.stdout, encoding: .utf8) {
                fputs("  stdout: \(str)\n", stderr)
            }
            if let str = String(data: displayResult.stderr, encoding: .utf8), !str.isEmpty {
                fputs("  stderr: \(str)\n", stderr)
            }
        }
        return
    }

    if DEBUG { fputs("  → Display index: \(d.index)\n", stderr) }

    // Try to focus window under mouse first
    if DEBUG { fputs("  → Trying to focus window under mouse...\n", stderr) }
    let mouseResult = sh([YABAI,"-m","window","--focus","mouse"])
    let mouseStderr = String(data: mouseResult.stderr, encoding: .utf8) ?? ""

    if mouseResult.exitCode == 0 {
        if DEBUG { fputs("  ✓ Focused window under mouse\n", stderr) }
        return
    }

    if DEBUG {
        fputs("  ✗ No window under mouse (exit \(mouseResult.exitCode))\n", stderr)
        if !mouseStderr.isEmpty {
            fputs("    \(mouseStderr.trimmingCharacters(in: .whitespacesAndNewlines))\n", stderr)
        }
    }

    // Query windows on this display to find what's visible
    if DEBUG { fputs("  → Querying windows on display \(d.index)...\n", stderr) }
    let windowsResult = sh([YABAI,"-m","query","--windows","--display","\(d.index)"])

    do {
        let windows = try JSONDecoder().decode([YabaiWindow].self, from: windowsResult.stdout)
        if DEBUG { fputs("  → Found \(windows.count) windows\n", stderr) }

        // Filter out minimized windows, prefer visible ones
        let visibleWindows = windows.filter { $0.`is-minimized` != true }

        guard let targetWindow = visibleWindows.first else {
            if DEBUG { fputs("  ✗ No visible windows on this display\n", stderr) }
            return
        }

        if DEBUG {
            fputs("  → Target: \(targetWindow.app) (PID \(targetWindow.pid), role: \"\(targetWindow.role)\")\n", stderr)
        }

        // Activate the app via NSRunningApplication - this does NOT move the cursor
        // NOTE: This function is now called from main thread via dispatch in event callback
        if DEBUG { fputs("  → Activating app via NSRunningApplication (PID \(targetWindow.pid))...\n", stderr) }

        if let app = NSRunningApplication(processIdentifier: pid_t(targetWindow.pid)) {
            let success = app.activate()
            if DEBUG {
                if success {
                    fputs("  ✓ Activated \(targetWindow.app) (no cursor warp)\n", stderr)
                } else {
                    fputs("  ✗ Failed to activate \(targetWindow.app)\n", stderr)
                }
            }
        } else {
            if DEBUG { fputs("  ✗ Could not find running app with PID \(targetWindow.pid)\n", stderr) }
        }
    } catch {
        if DEBUG {
            fputs("  ✗ Failed to decode windows: \(error)\n", stderr)
            if let str = String(data: windowsResult.stderr, encoding: .utf8), !str.isEmpty {
                fputs("    stderr: \(str.trimmingCharacters(in: .whitespacesAndNewlines))\n", stderr)
            }
        }
    }
}

// Build list of active display bounds
func rebuildDisplays() {
    var count: UInt32 = 16
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    let err = CGGetActiveDisplayList(count, &ids, &count)
    if err == .success {
        ids = Array(ids.prefix(Int(count)))
        displayRects = ids.map { ($0, CGDisplayBounds($0)) }
    } else {
        displayRects = []
    }
}

// Simple point->display lookup using cached bounds
func displayForPoint(_ p: CGPoint) -> CGDirectDisplayID? {
    for (id, rect) in displayRects {
        if rect.contains(p) { return id }
    }
    return nil
}

// Rebuild on display changes (plug/unplug, arrangement, etc.)
func displayReconfigCallback(_ display: CGDirectDisplayID,
                             _ flags: CGDisplayChangeSummaryFlags,
                             _ userInfo: UnsafeMutableRawPointer?) {
    rebuildDisplays()
}

// MARK: - Start
rebuildDisplays()
CGDisplayRegisterReconfigurationCallback(displayReconfigCallback, nil)

// Only listen to mouseMoved (not drags), keeps the event volume lower
let mask: CGEventMask = 1 << CGEventType.mouseMoved.rawValue

eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: { _, type, event, _ in
        // Re-enable the tap if macOS temporarily disables it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // Throttle: only handle at most every `throttleMs`
        let ts = event.timestamp               // nanoseconds
        let minIntervalNs = throttleMs * 1_000_000
        if ts - lastHandledTs < minIntervalNs {
            return Unmanaged.passUnretained(event)
        }
        lastHandledTs = ts

        // Display crossing detection
        let loc = event.location
        if let did = displayForPoint(loc) {
            if did != lastDisplayID {
                if Date().timeIntervalSince(lastSwitch) > debounceSeconds {
                    if DEBUG { fputs("Display changed from \(lastDisplayID) to \(did)\n", stderr) }
                    lastDisplayID = did
                    lastSwitch = Date()

                    // Dispatch to main thread to avoid crashes with Process/AppKit APIs
                    DispatchQueue.main.async {
                        focusDisplayUnderMouse()
                    }
                }
            }
        }

        return Unmanaged.passUnretained(event)
    },
    userInfo: nil
)

guard let tap = eventTap else {
    fputs("Failed to create event tap. Grant Accessibility/Input Monitoring, then retry.\n", stderr)
    exit(1)
}

let rl = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)!
CFRunLoopAddSource(CFRunLoopGetCurrent(), rl, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
CFRunLoopRun()

