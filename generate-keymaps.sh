#!/usr/bin/env bash

set -eu

# This was copied from the Carbon toolkit, Carbon.HIToolbox.Events.

data=$(cat <<EOF
public var kVK_ANSI_A: Int { get }
public var kVK_ANSI_S: Int { get }
public var kVK_ANSI_D: Int { get }
public var kVK_ANSI_F: Int { get }
public var kVK_ANSI_H: Int { get }
public var kVK_ANSI_G: Int { get }
public var kVK_ANSI_Z: Int { get }
public var kVK_ANSI_X: Int { get }
public var kVK_ANSI_C: Int { get }
public var kVK_ANSI_V: Int { get }
public var kVK_ANSI_B: Int { get }
public var kVK_ANSI_Q: Int { get }
public var kVK_ANSI_W: Int { get }
public var kVK_ANSI_E: Int { get }
public var kVK_ANSI_R: Int { get }
public var kVK_ANSI_Y: Int { get }
public var kVK_ANSI_T: Int { get }
public var kVK_ANSI_1: Int { get }
public var kVK_ANSI_2: Int { get }
public var kVK_ANSI_3: Int { get }
public var kVK_ANSI_4: Int { get }
public var kVK_ANSI_6: Int { get }
public var kVK_ANSI_5: Int { get }
public var kVK_ANSI_Equal: Int { get }
public var kVK_ANSI_9: Int { get }
public var kVK_ANSI_7: Int { get }
public var kVK_ANSI_Minus: Int { get }
public var kVK_ANSI_8: Int { get }
public var kVK_ANSI_0: Int { get }
public var kVK_ANSI_RightBracket: Int { get }
public var kVK_ANSI_O: Int { get }
public var kVK_ANSI_U: Int { get }
public var kVK_ANSI_LeftBracket: Int { get }
public var kVK_ANSI_I: Int { get }
public var kVK_ANSI_P: Int { get }
public var kVK_ANSI_L: Int { get }
public var kVK_ANSI_J: Int { get }
public var kVK_ANSI_Quote: Int { get }
public var kVK_ANSI_K: Int { get }
public var kVK_ANSI_Semicolon: Int { get }
public var kVK_ANSI_Backslash: Int { get }
public var kVK_ANSI_Comma: Int { get }
public var kVK_ANSI_Slash: Int { get }
public var kVK_ANSI_N: Int { get }
public var kVK_ANSI_M: Int { get }
public var kVK_ANSI_Period: Int { get }
public var kVK_ANSI_Grave: Int { get }
public var kVK_ANSI_KeypadDecimal: Int { get }
public var kVK_ANSI_KeypadMultiply: Int { get }
public var kVK_ANSI_KeypadPlus: Int { get }
public var kVK_ANSI_KeypadClear: Int { get }
public var kVK_ANSI_KeypadDivide: Int { get }
public var kVK_ANSI_KeypadEnter: Int { get }
public var kVK_ANSI_KeypadMinus: Int { get }
public var kVK_ANSI_KeypadEquals: Int { get }
public var kVK_ANSI_Keypad0: Int { get }
public var kVK_ANSI_Keypad1: Int { get }
public var kVK_ANSI_Keypad2: Int { get }
public var kVK_ANSI_Keypad3: Int { get }
public var kVK_ANSI_Keypad4: Int { get }
public var kVK_ANSI_Keypad5: Int { get }
public var kVK_ANSI_Keypad6: Int { get }
public var kVK_ANSI_Keypad7: Int { get }
public var kVK_ANSI_Keypad8: Int { get }
public var kVK_ANSI_Keypad9: Int { get }

/* keycodes for keys that are independent of keyboard layout*/

public var kVK_Return: Int { get }
public var kVK_Tab: Int { get }
public var kVK_Space: Int { get }
public var kVK_Delete: Int { get }
public var kVK_Escape: Int { get }
public var kVK_Command: Int { get }
public var kVK_Shift: Int { get }
public var kVK_CapsLock: Int { get }
public var kVK_Option: Int { get }
public var kVK_Control: Int { get }
public var kVK_RightCommand: Int { get }
public var kVK_RightShift: Int { get }
public var kVK_RightOption: Int { get }
public var kVK_RightControl: Int { get }
public var kVK_Function: Int { get }
public var kVK_F17: Int { get }
public var kVK_VolumeUp: Int { get }
public var kVK_VolumeDown: Int { get }
public var kVK_Mute: Int { get }
public var kVK_F18: Int { get }
public var kVK_F19: Int { get }
public var kVK_F20: Int { get }
public var kVK_F5: Int { get }
public var kVK_F6: Int { get }
public var kVK_F7: Int { get }
public var kVK_F3: Int { get }
public var kVK_F8: Int { get }
public var kVK_F9: Int { get }
public var kVK_F11: Int { get }
public var kVK_F13: Int { get }
public var kVK_F16: Int { get }
public var kVK_F14: Int { get }
public var kVK_F10: Int { get }
public var kVK_F12: Int { get }
public var kVK_F15: Int { get }
public var kVK_Help: Int { get }
public var kVK_Home: Int { get }
public var kVK_PageUp: Int { get }
public var kVK_ForwardDelete: Int { get }
public var kVK_F4: Int { get }
public var kVK_End: Int { get }
public var kVK_F2: Int { get }
public var kVK_PageDown: Int { get }
public var kVK_F1: Int { get }
public var kVK_LeftArrow: Int { get }
public var kVK_RightArrow: Int { get }
public var kVK_DownArrow: Int { get }
public var kVK_UpArrow: Int { get }
EOF
     )

while read in; do
    echo "${in}" \
        | perl -ne '/(kVK_([^: ]+)):/ && print "print(\"(hashq-set! keycode->sym \\($1) (quote $2))\")\n";'

done <<< "${data}"
