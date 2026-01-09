# <div align="center"> Illusion's InputActionSystem </div>

<div align="center">

![IIASLogo|256x256, 75%](./IIASLogo.png) 
</div>

Hey developers! I'm excited to share the latest version of my **InputActionSystem** library - a complete rewrite of my [previous keybind system](https://devforum.roblox.com/t/illusions-inputactionsystem-an-easy-way-of-adding-keybinds-and-other/4061839) that's now fully modular and can be integrated anywhere in your LocalScripts.

If you're working with Roblox's new InputActionSystem or just need robust keybind management, this library will save you hours of development time.

---

## Key Features

- **Flexible Input Types**: Define actions as Hold or Toggle buttons
- **Multi-Key Support**: Assign multiple keys per action for full gamepad compatibility
- **Key Combinations**: Create complex actions using modifier keys (e.g., Shift + F)
- **UI Integration**: Connect keybinds to GuiButtons for seamless mobile support
- **Cooldown System**: Prevent action spam with customizable cooldowns
- **Input Buffering**: Capture inputs even during busy frames
- **Tap Detection**: Trigger actions with double-tap or multi-tap sequences
- **Priority & Sinking**: Fine control over input processing order
- **(NEW) Choose between five different InputActionType**: respecting original usage of IAS

---

## Installation
### Non Server Authority version:

**Option 1:** [Download from Creator Store](https://create.roblox.com/store/asset/92059655869452/Illusions-InputActionSystem-Module)

**Option 2:** [Clone from GitHub](https://github.com/IllusionAC/Illusion-InputActionSystem)

Place the module in `ReplicatedStorage` and require it in any LocalScript:

```lua
local IAS = require(game.ReplicatedStorage.IllusionIAS)
```

### Server Authority version:

Do the same steps as for normal version, but require the module from a Server Script.

Future updates will allow the developer to send proper data to client so he can edit their binds properly.

> **Note:** When updates are released, re-download from the Creator Store or pull from GitHub.
---

##  API Reference

### Create, Manage and give contexts to Binds

```lua
IIAS.new(name: string, InputType: Enum.InputActionType?) -- Create a new keybind, set a InputActionType (default to Bool)
IIAS.Get(name: string?)                                  -- Retrieve a specific bind
IIAS.GetAll()                                            -- Get all registered binds

-- IMPORTANT: Context here doesn't stand for InputContext
-- but rather a way to organize your binds.

IIAS.addContext(name: string, ...Object)           -- add a Bind to a context
IIAS.getContext(name: string)                      -- returns a context
IIAS.newContext(name: string)                      -- create a new context
IIAS.enableContext(name: string, enabled: boolean) -- enable or disables all the binds from the context
IIAS.isContextEnabled(name: string)                -- returns the context's action state
IIAS.clearContexts()                               -- clear all contexts
IIAS.removeContext(name: string)                   -- remove a context
IIAS.removeFromContext(name: string, bind: Object) -- remove a bind from a context
IIAS.removeAllFromContext(name: string): empty a context without deleting it

```

### Configuration Methods

```lua
:SetHold(hold: boolean)                         -- true = hold to activate, false = toggle
:SetUIButton(button: GuiButton?)                -- Link a GUI button as alternate input
:SetCooldown(cooldown: number)                  -- Set cooldown in seconds (default: 0)
:ResetCooldown()                                -- Manually reset cooldown
:SetEnabled(enabled: boolean)                   -- Enable/disable the bind
:IsEnabled()                                    -- Check if bind is enabled
:SetTapActivation(taps: number, window: number) -- Require N taps within time window
```

### Input Context Control

```lua
:SetPriority(priority: number)           -- Set processing priority
:GetPriority()                           -- Get current priority
:SetSink(sink: boolean)                  -- Set if input should sink
:GetSink()                               -- Get sink state
```

### Input Buffering

```lua
:SetInputBufferEnabled(enabled: boolean) -- Enable input buffering (default: false)
:SetInputBufferTime(time: number)        -- Buffer window in seconds (default: 0.15)
```

### Keybind Management

```lua
:AddBind(mainKey: KeyCode, ...modifiers: KeyCode)        -- Add a keybind with optional modifiers
:SetBind(mainKey: KeyCode, ...modifiers: KeyCode)        -- Replace all binds with one
:GetBinds()                                              -- Get all current keybinds
:RemoveBind(mainKey: KeyCode, ...modifiers: KeyCode)     -- Remove specific bind
:EditBind(oldMain, oldMods, newMain, newMods)            -- Replace a bind
:ClearBinds()                                            -- Remove all keybinds
:Destroy()                                               -- Delete the bind entirely
:SetCompositeDirections(up, down, left, right, forward, backward) -- Sets composite directions for Directions
```

### InputActionType management

```lua
:Fire(active, pressed)           -- Fire the bind manually
:GetState()                      -- Returns active state
:SetScale(scale)                 -- Set Scale for Directions
:GetScale()                      -- Get Scale for Directions
:SetVectorScale(vector)          -- Set VectorScale for Directions
:GetVectorScale()                -- Get VectorScale for Directions
:SetResponseCurve(curve)         -- Set ReesponseCurve for Directions
:GetResponseCurve()              -- Get ResponseCurve for Directions
:SetPressedThreshold(threshold)  -- Set Pressed Threshold for Bool
:GetPressedThreshold()           -- Get Pressed Threshold for Bool
:SetReleasedThreshold(threshold) -- Set Released Threshold for Bool
:GetReleasedThreshold()          -- Get Released Threshold for Bool
```

### Properties

```lua
Keybind.Name         -- The bind's name
Keybind.Active       -- Current activation state
Keybind.Enabled      -- Whether bind is enabled
Keybind.Priority     -- InputContext priority
Keybind.Sink         -- InputContext sinkability
Keybind.Hold         -- Hold mode state
Keybind.Cooldown     -- Cooldown duration
Keybind.Activated    -- IAScriptSignal event
Keybind.Started      -- IAScriptSignal event, equivalent to input began
Keybind.Ended        -- IAScriptSignal event, equivalent to input ended
Keybind.Scale        -- InputBinding Scale, for Directions
Keybind.VectorScale  -- InputBinding VectorScale, for Direction2D and 3D
Keybind.ResponseCurve -- InputBinding ResponseCurve, for Directions
Keybind.PressedThreshold -- InputBinding PressedThreshold, for Bool
Keybind.ReleasedThreshold -- InputBinding ReleasedThreshold, for Bool
```

The `Activated`, `Started`  and `Ended` events works like standard Roblox signals with `:Connect()`, `:Once()`, `:Wait()`, and `:Fire()` methods. This library uses [IllusionSignal](https://github.com/IllusionAC/IllusionSignal) module.

---

## Example: Sprint & Walk System

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

-- Configure as hold buttons
sprint:SetHold(true)
walk:SetHold(true)

-- Set keybinds
sprint:AddBind(Enum.KeyCode.LeftShift)
walk:AddBind(Enum.KeyCode.LeftControl)

-- Connect to humanoid
sprint.Activated:Connect(function(active, pressed)
    humanoid.WalkSpeed = active and 24 or 16
end)

walk.Activated:Connect(function(active, pressed)
    humanoid.WalkSpeed = active and 8 or 16
end)
```

---

## Example: Advanced Keybind with Cooldown

```lua
local IIAS = require(game.ReplicatedStorage.IllusionIAS)

local bind = IIAS.new("Bind")

-- Shift + F to activate
bind:AddBind(Enum.KeyCode.F, Enum.KeyCode.LeftShift)

-- Toggle mode
bind:SetHold(false)

-- 2 second cooldown
bind:SetCooldown(2)

-- Double-tap within 0.5s to activate
bind:SetTapActivation(2, 0.5)

bind.Activated:Connect(function(active, pressed)
    print("Bind state:", active, "| Key pressed:", pressed)
    -- The binds logic
end)
```

---

## Feedback & Support

I'd love to hear your thoughts! Please share:
- Feature requests
- Bug reports
- Use cases from your projects
- Suggestions for improvements

Thanks for checking out IllusionIAS - happy scripting!

*- Illusion* | discord: @illuusion
