# <div align="center"> Illusion's InputActionSystem </div>

<div align="center">

![IIASLogo|256x256, 75%](./IIASLogo.png) 
</div>

Hey developers! I'm really excited to share you my **InputActionSystem** library.  If you're working with Roblox's new InputActionSystem or just need robust keybind management, this library will save you hours of development time.

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
- **Full Roblox IAS Synchronization**: Support for `PreferredBinding`, `InputActionLabel`, `InputBindingType`, and all 5 `InputActionType` modes (`Bool`, `Direction1D`, `Direction2D`, `Direction3D`, `ViewportPosition`)

---

## Installation
### Non Server Authority version:

**Option 1:** [Download from Creator Store](https://create.roblox.com/store/asset/92059655869452/Illusions-InputActionSystem-Module)

**Option 2:** [Clone from GitHub](https://github.com/IllusionAC/Illusion-InputActionSystem)

**Option 3:** Wally Package Manager
Add to your `wally.toml`:
```toml
[dependencies]
IllusionIAS = "illusionac/illusion-inputactionsystem@^1.0.0"
```

Place the module in `ReplicatedStorage` (or via Wally `Packages`) and require it in any LocalScript:

```lua
local IAS = require(game.ReplicatedStorage.IllusionIAS)
-- Or if using Wally:
-- local IAS = require(game.ReplicatedStorage.Packages.IllusionIAS)
```

### Server Authority version:

(NOT RECOMMENDED)
Do the same steps as for normal version, but require the module from a Server Script.

(The current state of the module doesn't really allow Server Authority usage. I'm currently trying to find a way to implement it, which may require entire rework of the module. Feel free to propose solutions)

---

## API Reference

### Create, Manage and Give Contexts to Binds

```lua
IIAS.new(name: string, InputType: Enum.InputActionType?) -- Create a new keybind, set an InputActionType (default: Bool)
IIAS.Get(name: string)                                   -- Retrieve a specific bind (alias of .get)
IIAS.GetAll()                                            -- Get all registered binds (alias of .getAll)
IIAS.enableControlHints(module: Instance | string, parent: Instance | PlayerGui?)
                                                         -- Enable ControlHints - By ZurichBT

-- IMPORTANT: Context here organizes your binds logically.
IIAS.addContext(name: string, ...Object)           -- Add Binds to a context group
IIAS.getContext(name: string)                      -- Returns a context group table
IIAS.newContext(name: string)                      -- Create a new context group
IIAS.enableContext(name: string, enabled: boolean) -- Enable or disable all binds in the context group
IIAS.isContextEnabled(name: string)                -- Returns the context group enabled state
IIAS.clearContexts()                               -- Clear all context groups
IIAS.removeContext(name: string)                   -- Remove a context group
IIAS.removeFromContext(name: string, bind: Object) -- Remove a bind from a context group
IIAS.removeAllFromContext(name: string)            -- Empty a context group without deleting it
```

### Configuration Methods

```lua
:SetHold(hold: boolean)                         -- true = hold to activate, false = toggle
:SetUIButton(button: GuiButton?)                -- Link a GUI button as alternate input
:SetUIModifier(button: GuiButton?)              -- Link a GUI button as modifier
:GetUIModifier()                                -- Get linked modifier GUI button
:SetCooldown(cooldown: number)                  -- Set cooldown in seconds (default: 0)
:ResetCooldown()                                -- Manually reset cooldown
:CooldownEnded()                                -- boolean: true when cooldown is not active
:SetEnabled(enabled: boolean)                   -- Enable/disable the bind
:IsEnabled()                                    -- Check if bind is enabled (:IsEnable is an alias)
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
:AddBind(mainKey, primaryMod?, secondaryMod?, uiButton?, uiModifier?, displayName?, displayImage?, bindingType?)
                                                         -- Add a keybind with optional modifiers and configuration
:SetBind(mainKey, primaryMod?, secondaryMod?, uiButton?, uiModifier?, displayName?, displayImage?, bindingType?)
                                                         -- Replace all binds with a single bind
:GetBinds()                                              -- Get all current keybinds table
:RemoveBind(mainKey, primaryMod?, secondaryMod?)         -- Remove a specific keybind
:EditBind(oldMain, oldMods, newMain, newMods)            -- Edit an existing keybind
:ClearBinds()                                            -- Remove all keybinds
:Destroy()                                               -- Delete the bind and its Roblox instances entirely
:SetCompositeDirections(up, down, left, right, forward, backward) -- Sets composite directions for directional actions
:GetCompositeDirections()                                -- Returns table with Up, Down, Left, Right, Forward, Backward
:SetCompositeModifiers(primaryModifier, secondaryModifier) -- Sets composite modifiers
:GetCompositeModifiers()                                 -- Returns table with PrimaryModifier, SecondaryModifier
```

### Display & Label Helpers

```lua
:SetDisplayName(mainKey, displayName: string)   -- Set custom display text on InputBinding
:GetDisplayName(mainKey)                        -- Get display text of binding
:SetDisplayImage(mainKey, displayImage: any)    -- Set custom image content on InputBinding
:GetDisplayImage(mainKey)                       -- Get image content of binding
:SetBindingType(mainKey, bindingType: Enum.InputBindingType) -- Set Automatic or Scriptable
:GetBindingType(mainKey)                        -- Get binding type
:CreateActionLabel(parent?: Instance)           -- Creates a native Roblox InputActionLabel bound to this action
```

### Engine Instance Access

```lua
:GetInputAction()      -- Returns underlying Roblox InputAction instance
:GetInputContext()      -- Returns underlying Roblox InputContext instance
:GetInputBinding(key?) -- Returns specific child InputBinding instance
:GetPreferredBinding() -- Returns the active InputBinding currently driving the action
```

### InputActionType Management

```lua
:Fire(active, pressed)           -- Fire the bind manually
:GetState()                      -- Returns active state matching action type
:SetScale(scale)                 -- Set Scale for Directions
:GetScale()                      -- Get Scale for Directions
:SetVectorScale(vector)          -- Set VectorScale for Direction2D / Direction3D
:GetVectorScale()                -- Get VectorScale for Direction2D / Direction3D
:SetResponseCurve(curve)         -- Set ResponseCurve for Directions
:GetResponseCurve()              -- Get ResponseCurve for Directions
:SetPressedThreshold(threshold)  -- Set Pressed Threshold for Bool
:GetPressedThreshold()           -- Get Pressed Threshold for Bool
:SetReleasedThreshold(threshold) -- Set Released Threshold for Bool
:GetReleasedThreshold()          -- Get Released Threshold for Bool
:SetPointerIndex(index)          -- Set PointerIndex
:GetPointerIndex()               -- Get PointerIndex
:SetClampMagnitudeToOne(bool)    -- Set ClampMagnitudeToOne
:GetClampMagnitudeToOne()        -- Get ClampMagnitudeToOne
```

---

## Utilities / Introspection

```lua
:GetCooldownRemaining() -- number: seconds remaining on the current cooldown (0 if none)
:CooldownEnded()        -- boolean: true when cooldown is inactive, false while active
:IsBuffered()           -- boolean: whether an input is currently buffered
:ResetBuffer()          -- void: clears any buffered input
:GetBufferedVariant()   -- variant?: the buffered value, if present
:GetBufferedKey()       -- Enum.KeyCode?: the buffered key code, if present
:GetActiveBindCount()   -- number: how many binds are currently active
:GetToggleState()       -- boolean: current toggle state for toggle-mode binds
:GetActiveMainKey()     -- Enum.KeyCode?: which main key is currently active, if any
```

### Properties

```lua
Keybind.Name              -- The bind's name
Keybind.Active            -- Current activation state
Keybind.Enabled           -- Whether bind is enabled
Keybind.Priority          -- InputContext priority
Keybind.Sink              -- InputContext sinkability
Keybind.Hold              -- Hold mode state
Keybind.Cooldown          -- Cooldown duration
Keybind.Activated         -- IAScriptSignal event (active, pressed)
Keybind.Started           -- IAScriptSignal event, fired on input start
Keybind.Ended             -- IAScriptSignal event, fired on input end
Keybind.Scale             -- InputBinding Scale
Keybind.VectorScale       -- InputBinding VectorScale
Keybind.ResponseCurve     -- InputBinding ResponseCurve
Keybind.PressedThreshold  -- InputBinding PressedThreshold
Keybind.ReleasedThreshold -- InputBinding ReleasedThreshold
Keybind.PointerIndex      -- InputBinding PointerIndex
Keybind.ClampMagnitudeToOne -- InputBinding ClampMagnitudeToOne
```

The `Activated`, `Started`, and `Ended` events work like standard Roblox signals with `:Connect()`, `:Once()`, `:Wait()`, and `:Fire()` methods.

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
    if not bind:CooldownEnded() then return end
    print("Bind state:", active, "| Key pressed:", pressed)
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
