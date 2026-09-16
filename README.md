# <div align="center"> Illusion's InputActionSystem (IIAS) </div>

<div align="center">

![IIASLogo|256x256, 75%](./IIASLogo.png)
</div>

[![Wally Version](https://img.shields.io/badge/wally-v1.2.0-blue.svg)](https://wally.run/package/illusionac/illusion-inputactionsystem)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Illusion's InputActionSystem (IIAS)** is a powerful, production-ready input and keybind management library built for Roblox's modern **InputActionSystem (IAS)** engine architecture. It provides an intuitive, high-level API over native `InputContext`, `InputAction`, and `InputBinding` instances while adding game-ready mechanics like dynamic cooldowns, input buffering, double-tap activation, context groups, mobile GUI integration, and lifecycle signals.

---

## 📑 Table of Contents

- [Key Features](#-key-features)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Core Concepts](#-core-concepts)
  - [Hold vs Toggle Modes](#1-hold-vs-toggle-modes)
  - [Cooldown System & Lifecycle Signals](#2-cooldown-system--lifecycle-signals)
  - [Context Groups](#3-context-groups)
  - [Input Buffering](#4-input-buffering)
  - [Multi-Tap Activation](#5-multi-tap-activation)
  - [GUI Button Integration (Mobile Support)](#6-gui-button-integration-mobile-support)
  - [Directional & Composite Vector Actions](#7-directional--composite-vector-actions)
- [API Reference](#-api-reference)
  - [IIAS Static Functions](#iias-static-functions)
  - [BindingObject Methods](#bindingobject-methods)
  - [BindingObject Properties](#bindingobject-properties)
  - [Signals & Event Payloads](#signals--event-payloads)
- [Practical Examples](#-practical-examples)
- [License & Support](#-license--support)

---

## ✨ Key Features

- **Roblox IAS Engine Integration**: Automatically manages underlying `InputContext`, `InputAction`, and `InputBinding` instances.
- **Flexible InputActionTypes**: Full support for `Bool`, `Direction1D`, `Direction2D`, `Direction3D`, and `ViewportPosition`.
- **Flexible Key Representations**: Pass either `Enum.KeyCode` items or string names (`"E"`, `"MouseButton1"`, `"MouseButton2"`, `"Touch"`).
- **Hold & Toggle Modes**: Seamlessly switch between hold-to-activate and state-toggling inputs.
- **Multi-Binding & Modifiers**: Bind primary keys, alternate keys, and key combinations with primary & secondary modifiers (e.g., `Shift + F`, `Ctrl + Alt + E`).
- **Dynamic & Timed Cooldowns**: Configure fixed numeric cooldowns or control cooldowns manually via booleans with `.Began` and `.Completed` lifecycle signals.
- **Input Buffering**: Capture inputs during active cooldowns or busy frames and consume them automatically when available.
- **Tap Sequences**: Trigger actions only after sequences like double-tapping within a configurable time window.
- **Context Groups**: Group related keybinds into contexts (e.g., `"Combat"`, `"Vehicle"`, `"Menu"`) to enable/disable them simultaneously.
- **GUI Mobile Integration**: Connect Roblox `GuiButton` instances directly as alternate inputs or modifiers for touch/mobile platforms.
- **ControlHints Support**: Integrated helper for displaying ZurichBT's ControlHints UI.

---

## 📦 Installation

> [!NOTE]
> IIAS is designed to run on the client (`LocalScript` or client Actors) where player inputs and Roblox `InputContext` instances are processed.

### Option 1: Wally (Recommended)

Add IIAS to your `wally.toml`:

```toml
[dependencies]
IllusionIAS = "illusionac/illusion-inputactionsystem@^1.2.0"
```

Then install with `wally install`.

### Option 2: Roblox Creator Store

Download the pre-packaged Roblox model from the [Creator Store](https://create.roblox.com/store/asset/92059655869452/Illusions-InputActionSystem-Module).

### Option 3: GitHub & Rojo

Clone the repository directly into your project:

```bash
git clone https://github.com/IllusionAC/Illusion-InputActionSystem.git
```

Require the module in a `LocalScript`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IIAS = require(ReplicatedStorage.IllusionIAS)
-- Or if using Wally:
-- local IIAS = require(ReplicatedStorage.Packages.IllusionIAS)
```

---

## 🚀 Quick Start

Here is a simple example creating an interaction bind in under 10 lines of code:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IIAS = require(ReplicatedStorage.IllusionIAS)

-- 1. Create a new Bool action bind
local interact = IIAS.new("Interact", Enum.InputActionType.Bool)

-- 2. Add keyboard and gamepad binds
interact:AddBind(Enum.KeyCode.E)
interact:AddBind(Enum.KeyCode.ButtonX)

-- 3. Configure mode (Hold to interact)
interact:SetHold(true)

-- 4. Listen for activation
interact.Activated:Connect(function(active: boolean, pressed: boolean)
    print("Interact state:", active, "| Pressed:", pressed)
end)
```

---

## 🧠 Core Concepts

### 1. Hold vs Toggle Modes

Actions behave in one of two modes:
- **Hold Mode (`:SetHold(true)`)**: The action is active as long as the input is held down. When pressed, `Activated` fires with `(activeValue, true)` and `Started` fires. When released, `Activated` fires with `(inactiveValue, false)` and `Ended` fires.
- **Toggle Mode (`:SetHold(false)`)**: Each press toggles the internal state between active and inactive.

```lua
local flashlight = IIAS.new("Flashlight")
flashlight:AddBind(Enum.KeyCode.F)
flashlight:SetHold(false) -- Toggle mode

flashlight.Activated:Connect(function(active: boolean)
    print("Flashlight is now:", active and "ON" or "OFF")
end)
```

---

### 2. Cooldown System & Lifecycle Signals

IIAS supports both **timed (automatic)** and **manual (dynamic)** cooldowns. Cooldown state is fully observable via lifecycle signals:

#### Timed Cooldowns
Set a numeric duration in seconds. When the action is triggered, it automatically enters cooldown and expires after the duration:

```lua
local dash = IIAS.new("Dash")
dash:AddBind(Enum.KeyCode.Q)
dash:SetCooldown(3) -- 3-second cooldown on activation

-- Observe cooldown lifecycle
dash.Cooldown.Began:Connect(function()
    print("Dash on cooldown! Updating UI...")
end)

dash.Cooldown.Completed:Connect(function()
    print("Dash ready! Re-enabling UI...")
end)
```

#### Manual / Dynamic Cooldowns
Control cooldowns manually via boolean flags (e.g., during animations, casting sequences, or server responses):

```lua
local castSpell = IIAS.new("CastSpell")
castSpell:AddBind(Enum.KeyCode.R)

-- Lock input immediately:
castSpell:SetCooldown(true)

-- Later, unlock input when the animation or cast completes:
castSpell:SetCooldown(false) -- Fires Cooldown.Completed
```

#### Cooldown Query & Utility Methods
- `bind:IsInCooldown()`: Returns `true` if currently on cooldown (timed or manual).
- `bind:GetCooldownRemaining()`: Returns remaining seconds, or `math.huge` during manual cooldown (`0` if not on cooldown).
- `bind:StartCooldown(duration?)`: Programmatically trigger a timed cooldown immediately.
- `bind:ResetCooldown()`: Clears active cooldowns and fires `Cooldown.Completed`.

---

### 3. Context Groups

Organize keybinds into logical groups (e.g., `"Combat"`, `"Inventory"`, `"Driving"`). Binds can belong to multiple contexts: if **any** context containing a bind is disabled, the bind is automatically disabled.

```lua
local attack = IIAS.new("Attack")
local block = IIAS.new("Block")

-- Add binds to a "Combat" context group
IIAS.addContext("Combat", attack, block)

-- Disable all combat actions when opening a menu:
IIAS.enableContext("Combat", false)

-- Check context status:
print("Combat enabled:", IIAS.isContextEnabled("Combat"))

-- Re-enable when closing the menu:
IIAS.enableContext("Combat", true)
```

---

### 4. Input Buffering

Input buffering prevents lost inputs when a player presses a button shortly before a cooldown expires:

```lua
local comboAttack = IIAS.new("ComboAttack")
comboAttack:AddBind(Enum.KeyCode.F)
comboAttack:SetCooldown(1.5)

-- Enable buffering with a 0.25-second window
comboAttack:SetInputBufferEnabled(true)
comboAttack:SetInputBufferTime(0.25)
```

If the player presses `F` within the last `0.25s` of the cooldown, the input is buffered and automatically executes the instant the cooldown ends!

---

### 5. Multi-Tap Activation

Require multiple taps within a time window (e.g., double-tap to sprint or dodge):

```lua
local dodge = IIAS.new("Dodge")
dodge:AddBind(Enum.KeyCode.W)

-- Require 2 taps of 'W' within 0.35 seconds
dodge:SetTapActivation(2, 0.35)

dodge.Activated:Connect(function(active, pressed)
    print("Dodge triggered by double-tap!")
end)
```

---

### 6. GUI Button Integration (Mobile Support)

Connect on-screen `GuiButton` instances to keybinds. The button will automatically behave like a physical keybind, including hold/toggle behavior and modifier combinations:

```lua
local mobileButton = playerGui.HUD.SkillButton

local skill = IIAS.new("Skill")
skill:AddBind(Enum.KeyCode.E)
skill:SetUIButton(mobileButton) -- Seamless cross-platform support!
```

---

### 7. Directional & Composite Vector Actions

IIAS natively supports Roblox IAS directional action types:
- `Enum.InputActionType.Direction1D` (Number: `-1` to `1`)
- `Enum.InputActionType.Direction2D` (Vector2: e.g. Thumbsticks, WASD)
- `Enum.InputActionType.Direction3D` (Vector3)
- `Enum.InputActionType.ViewportPosition` (Vector2 screen coordinates)

For directional actions, you can configure composite bindings (e.g. WASD composite for a Vector2 action):

```lua
local move = IIAS.new("Movement", Enum.InputActionType.Direction2D)

-- Assign directional composite keys
move:SetCompositeDirections(
    Enum.KeyCode.W, -- Up
    Enum.KeyCode.S, -- Down
    Enum.KeyCode.A, -- Left
    Enum.KeyCode.D  -- Right
)

move.Activated:Connect(function(direction: Vector2)
    print("Movement vector:", direction)
end)
```

---

## 📚 API Reference

### IIAS Static Functions

| Function | Signature | Description |
|---|---|---|
| `IIAS.new` | `(name: string, inputType?: Enum.InputActionType) -> BindingObject` | Creates a new keybind action (defaults to `Bool`). |
| `IIAS.get` | `(name: string) -> BindingObject?` | Retrieves a registered binding by name. |
| `IIAS.getAll` | `() -> { [string]: BindingObject }` | Returns a dictionary of all active registered bindings. |
| `IIAS.newContext` | `(name: string) -> ()` | Creates a new context group. |
| `IIAS.getContext` | `(name: string) -> Context?` | Returns a copy of the context group data `{ Enabled: boolean, Members: { [string]: boolean } }`. |
| `IIAS.addContext` | `(name: string, ...: BindingObject) -> ()` | Adds one or more bindings to a context group. |
| `IIAS.enableContext` | `(name: string, enabled: boolean) -> ()` | Enables or disables all actions belonging to the context group. |
| `IIAS.isContextEnabled` | `(name: string) -> boolean` | Returns whether the context group is currently enabled. |
| `IIAS.removeContext` | `(name: string) -> ()` | Removes a context group. |
| `IIAS.removeFromContext` | `(name: string, bind: BindingObject) -> ()` | Removes a specific binding from a context group. |
| `IIAS.removeAllFromContext` | `(name: string) -> ()` | Empties all bindings from a context group without deleting the group. |
| `IIAS.clearContexts` | `() -> ()` | Clears all context groups and recalculates action states. |
| `IIAS.enableControlHints` | `(module: Instance \| string, parent?: Instance \| PlayerGui) -> ScreenGui` | Integrates with ZurichBT's ControlHints module. |

---

### BindingObject Methods

> [!TIP]
> In the signatures below, `Key` represents `Enum.KeyCode | string` (e.g. `Enum.KeyCode.E` or `"E"`, `"MouseButton1"`, `"Touch"`), and `Content` represents a Roblox content string or asset URL (`"rbxassetid://..."`).

#### Keybind Configuration
```lua
:AddBind(mainKey: Key, primaryMod?: Key, secondaryMod?: Key, uiButton?: GuiButton, uiModifier?: GuiButton, displayName?: string, displayImage?: Content, bindingType?: Enum.InputBindingType)
-- Adds a new key binding. Keys accept Enum.KeyCode or string names ("E", "MouseButton1", "Touch").

:SetBind(mainKey: Key, primaryMod?: Key, secondaryMod?: Key, uiButton?: GuiButton, uiModifier?: GuiButton, displayName?: string, displayImage?: Content, bindingType?: Enum.InputBindingType)
-- Clears existing keybinds and sets a single binding.

:SetAllBinds(binds: Binds)
-- Replaces all binds with a cloned binds table.

:RemoveBind(mainKey: Key, primaryMod?: Key, secondaryMod?: Key)
-- Removes a specific keybind matching key and modifiers.

:EditBind(oldMain: Key, oldMods: { PrimaryModifier: Key?, SecondaryModifier: Key? }, newMain: Key, newMods: { PrimaryModifier: Key?, SecondaryModifier: Key? })
-- Modifies an existing binding in-place.

:GetBinds() -> Binds
-- Returns a deep clone of the binds table.

:ClearBinds()
-- Clears all configured keybinds on the action.

:Destroy() -> boolean
-- Disconnects all signals, cancels timers, and destroys underlying Roblox instances.
```

#### Mode & Activation Settings
```lua
:SetHold(hold: boolean)
-- true = hold to activate; false = toggle mode.

:SetTapActivation(requiredTaps: number, tapWindow: number)
-- Requires N taps within tapWindow seconds to activate (e.g. 2 taps in 0.3s).

:Fire(active: variant, pressed: boolean)
-- Manually fires the binding object with the specified active payload and pressed state.

:GetState() -> variant
-- Returns the current active variant value (boolean, number, Vector2, or Vector3).

:GetToggleState() -> boolean
-- Returns the current toggle state for toggle-mode binds.

:GetActiveMainKey() -> Enum.KeyCode
-- Returns the primary KeyCode currently driving the action, if active.

:GetActiveBindCount() -> number
-- Returns 1 if currently active, 0 otherwise.
```

#### Cooldown Management
```lua
:SetCooldown(cooldown: number | boolean, startImmediately?: boolean)
-- Passing a number sets timed duration (seconds). Passing true/false sets manual cooldown. Optional boolean starts timed cooldown immediately.

:StartCooldown(duration?: number)
-- Programmatically starts a timed cooldown immediately (uses duration or configured Cooldown.Value).

:ResetCooldown()
-- Clears active timed & manual cooldowns, cancels running timer, and fires Cooldown.Completed.

:IsInCooldown() -> boolean
-- Returns true if the action is currently on cooldown (timed or manual).

:GetCooldownRemaining() -> number
-- Returns remaining seconds on timed cooldown, math.huge if manual, or 0 if inactive.
```

#### Input Buffering
```lua
:SetInputBufferEnabled(enabled: boolean)
-- Enables or disables input buffering.

:SetInputBufferTime(time: number)
-- Sets buffer window duration in seconds (default: 0.15).

:IsBuffered() -> boolean
-- Returns whether an input is currently waiting in the buffer.

:ResetBuffer()
-- Clears any currently buffered input.

:GetBufferedVariant() -> variant?
-- Returns the buffered value payload, if present.

:GetBufferedKey() -> Enum.KeyCode
-- Returns the buffered KeyCode, if present.
```

#### State & Priority Control
```lua
:SetEnabled(enabled: boolean)
-- Enables or disables the action.

:IsEnabled() -> boolean
-- Returns whether the action is enabled.

:SetPriority(priority: number)
-- Sets input processing priority on the underlying InputContext.

:GetPriority() -> number
-- Returns current priority.

:SetSink(sink: boolean)
-- Sets whether the action sinks inputs, preventing lower-priority actions from receiving them.

:GetSink() -> boolean
-- Returns current sink state.
```

#### GUI Integration
```lua
:SetUIButton(button: GuiButton?)
-- Links a GuiButton as an alternate input. Automatically handles cleanup when button is destroyed.

:SetUIModifier(button: GuiButton?)
-- Links a GuiButton as an input modifier.

:GetUIModifier() -> GuiButton?
-- Returns the linked modifier GuiButton.

:CreateActionLabel(parent?: Instance) -> GuiObject?
-- Creates a native Roblox InputActionLabel bound to this action.
```

#### Directional & Analog Settings
```lua
:SetScale(scale: number) / :GetScale() -> number
:SetVectorScale(vector: Vector2 | Vector3) / :GetVectorScale() -> Vector2 | Vector3
:SetResponseCurve(curve: number) / :GetResponseCurve() -> number
:SetPressedThreshold(threshold: number) / :GetPressedThreshold() -> number
:SetReleasedThreshold(threshold: number) / :GetReleasedThreshold() -> number
:SetPointerIndex(index: number) / :GetPointerIndex() -> number
:SetClampMagnitudeToOne(bool: boolean) / :GetClampMagnitudeToOne() -> boolean
:SetCompositeDirections(up?: Key, down?: Key, left?: Key, right?: Key, forward?: Key, backward?: Key)
:GetCompositeDirections() -> { Up: Enum.KeyCode, Down: Enum.KeyCode, Left: Enum.KeyCode, Right: Enum.KeyCode, Forward: Enum.KeyCode, Backward: Enum.KeyCode }
:SetCompositeModifiers(primaryModifier?: Key, secondaryModifier?: Key)
:GetCompositeModifiers() -> { PrimaryModifier: Enum.KeyCode, SecondaryModifier: Enum.KeyCode }
```

#### Engine Instance Access
```lua
:GetInputAction() -> InputAction?
-- Returns underlying Roblox InputAction instance.

:GetInputContext() -> InputContext?
-- Returns underlying Roblox InputContext instance.

:GetInputBinding(keyOrName?: string | Key) -> InputBinding?
-- Returns specific child InputBinding instance.

:GetPreferredBinding() -> InputBinding?
-- Returns the active InputBinding currently driving the action.
```

#### Display Metadata
```lua
:SetDisplayName(mainKey: Key, displayName: string) -> boolean
:GetDisplayName(mainKey: Key) -> string?
:SetDisplayImage(mainKey: Key, displayImage: Content) -> boolean
:GetDisplayImage(mainKey: Key) -> Content?
:SetBindingType(mainKey: Key, bindingType: Enum.InputBindingType) -> boolean
:GetBindingType(mainKey: Key) -> Enum.InputBindingType?
```

---

### BindingObject Properties

```lua
bind.Name               -- string: Name of the action
bind.Active             -- variant: Current active value (boolean, number, Vector2, Vector3)
bind.Hold               -- boolean: Whether hold mode is active
bind.Enabled            -- boolean: Whether action is enabled
bind.Priority           -- number: InputContext priority
bind.Sink               -- boolean: InputContext sinkability
bind.Binds              -- Binds: Internal dictionary of configured keybinds
bind.UIButton           -- GuiButton?: Linked alternate GUI button
bind.UIModifier         -- GuiButton?: Linked modifier GUI button

bind.Cooldown           -- Table grouping cooldown duration and lifecycle signals:
bind.Cooldown.Value     -- number: Cooldown duration in seconds (default: 0)
bind.Cooldown.Began     -- IAScriptSignal: Fires when cooldown becomes active
bind.Cooldown.Completed -- IAScriptSignal: Fires when cooldown completes/inactivates

bind.Activated          -- IAScriptSignal<T, boolean>: Fires on input change (active, pressed)
bind.Started            -- IAScriptSignal<T>: Fires on input start (active)
bind.Ended              -- IAScriptSignal<T>: Fires on input end (active)

bind.Scale              -- number: Scale for directional inputs
bind.VectorScale        -- Vector2 | Vector3: Vector scale for 2D/3D inputs
bind.ResponseCurve      -- number: Response curve
bind.PressedThreshold   -- number: Threshold for button press
bind.ReleasedThreshold  -- number: Threshold for button release
bind.PointerIndex       -- number: Pointer index
bind.ClampMagnitudeToOne -- boolean: Clamps vector magnitude to 1
bind.TapRequired        -- number: Required taps for activation
bind.TapWindow          -- number: Tap sequence time window
bind.InputBufferEnabled -- boolean: Whether input buffer is enabled
bind.InputBufferTime    -- number: Input buffer window in seconds
```

---

### Signals & Event Payloads

All signals in IIAS implement standard signal methods: `:Connect()`, `:Once()`, `:Wait()`, and `:Fire()`.

| Signal | Signature | Description |
|---|---|---|
| `bind.Activated` | `(active: T, pressed: boolean) -> ()` | Primary action event. Fires when an input changes state. |
| `bind.Started` | `(active: T) -> ()` | Fires when an input transition starts (`pressed == true`). |
| `bind.Ended` | `(active: T) -> ()` | Fires when an input transition ends (`pressed == false`). |
| `bind.Cooldown.Began` | `() -> ()` | Fires when the action enters cooldown (timed or manual). |
| `bind.Cooldown.Completed` | `() -> ()` | Fires when the action transitions back from cooldown to ready. |

---

## 🛠️ Practical Examples

### Example 1: Sprint & Walk System

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local IIAS = require(ReplicatedStorage.IllusionIAS)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- Create binds
local sprint = IIAS.new("Sprint")
local walk = IIAS.new("Walk")

-- Configure as hold actions
sprint:SetHold(true)
walk:SetHold(true)

-- Add keybinds (Keyboard and Gamepad)
sprint:AddBind(Enum.KeyCode.LeftShift)
sprint:AddBind(Enum.KeyCode.ButtonL3)

walk:AddBind(Enum.KeyCode.LeftControl)

-- Connect to humanoid WalkSpeed
sprint.Activated:Connect(function(active: boolean)
    humanoid.WalkSpeed = active and 24 or 16
end)

walk.Activated:Connect(function(active: boolean)
    humanoid.WalkSpeed = active and 10 or 16
end)
```

---

### Example 2: Ability with Cooldown, Input Buffering & UI

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IIAS = require(ReplicatedStorage.IllusionIAS)

local spell = IIAS.new("CastSpell")
spell:AddBind(Enum.KeyCode.Q)
spell:AddBind(Enum.KeyCode.ButtonX)

-- 4-second cooldown with a 0.3s input buffer
spell:SetCooldown(4)
spell:SetInputBufferEnabled(true)
spell:SetInputBufferTime(0.3)

-- Observe cooldown lifecycle to update ability icon UI
spell.Cooldown.Began:Connect(function()
    print("[UI] Spell on cooldown! Greying out icon...")
end)

spell.Cooldown.Completed:Connect(function()
    print("[UI] Spell ready! Enabling icon...")
end)

spell.Activated:Connect(function(active: boolean, pressed: boolean)
    if not pressed then return end
    print("Spell cast successfully!")
end)
```

---

### Example 3: Key Combinations with Modifiers

```lua
local specialMove = IIAS.new("SpecialMove")

-- Shift + F to activate
specialMove:AddBind(Enum.KeyCode.F, Enum.KeyCode.LeftShift)

-- Or string syntax:
-- specialMove:AddBind("F", "LeftShift")

specialMove.Activated:Connect(function(active: boolean, pressed: boolean)
    if pressed then
        print("Special move executed!")
    end
end)
```

---

### Example 4: Mobile On-Screen Button Integration

```lua
local Players = game:GetService("Players")
local IIAS = require(game:GetService("ReplicatedStorage").IllusionIAS)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local attackButton = playerGui:WaitForChild("HUD"):WaitForChild("AttackButton")

local attack = IIAS.new("Attack")
attack:AddBind(Enum.KeyCode.F) -- PC
attack:SetUIButton(attackButton) -- Mobile / Touch

attack.Activated:Connect(function(active: boolean, pressed: boolean)
    if pressed then
        print("Attack triggered from keyboard or mobile button!")
    end
end)
```

---

## 💬 License & Support

- **License**: [MIT](LICENSE)
- **Creator**: Illusion (*discord: @illuusion*)
- **DevForum Discussion**: [Illusion's InputActionSystem DevForum Thread](https://devforum.roblox.com/t/illusions-inputactionsystem-the-best-inputmanager-ever/4071242/)

Feel free to open issues or pull requests on GitHub for bug reports and feature suggestions!
