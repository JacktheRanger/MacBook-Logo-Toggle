#!/usr/bin/env python3
"""Generates the optional "MacBook Logo Toggle" shortcut (.shortcut) with a single action: open MacBook Logo Toggle.app.

This is the fallback entry for Control Center: if the native "Apple Logo Illumination" switch doesn't show up in
Edit Controls, Control Center's "Shortcut" control can run this shortcut instead (with a generic glyph).
The output is an unsigned plist; sign it with `shortcuts sign` before importing it.
Usage: make-shortcut.py <output path>
"""
import plistlib
import sys

BUNDLE_ID = "local.macbook-logo-toggle"  # must match the bundle id build.sh writes into Info.plist
APP_NAME = "MacBook Logo Toggle"

workflow = {
    "WFWorkflowClientVersion": "2700",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    # Icon colour and glyph are cosmetic; they can be changed in Shortcuts after importing.
    "WFWorkflowIcon": {
        "WFWorkflowIconStartColor": 4282601983,
        "WFWorkflowIconGlyphNumber": 59511,
    },
    "WFWorkflowTypes": [],
    "WFWorkflowInputContentItemClasses": [],
    "WFWorkflowOutputContentItemClasses": [],
    "WFWorkflowImportQuestions": [],
    "WFWorkflowHasOutputFallback": False,
    "WFWorkflowHasShortcutInputVariables": False,
    "WFQuickActionSurfaces": [],
    "WFWorkflowActions": [
        {
            "WFWorkflowActionIdentifier": "is.workflow.actions.openapp",
            "WFWorkflowActionParameters": {
                "WFAppIdentifier": BUNDLE_ID,
                "WFSelectedApp": {
                    "BundleIdentifier": BUNDLE_ID,
                    "Name": APP_NAME,
                    "TeamIdentifier": "0000000000",
                },
            },
        }
    ],
}

with open(sys.argv[1], "wb") as f:
    plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)
