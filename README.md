# **Illusion's InputActionSystem**
---
#### Welcome to the GitHub repository of my IAS Library, you may find more informations in the [Roblox Devforum post](https://devforum.roblox.com/t/illusions-inputactionsystem-v2-currently-the-best-way-of-making-keybinds/4071242).
---
### Installation
- Download the content of the IllusionIAS folder
- Place IllusionIAS.luau in ReplicatedStorage, and ScriptSignal.luau and TypeDefinition.luau in IllusionIAS.luau.
- Then simply call it from any LocalScript using `require(ReplicatedStorage.IllusionIAS)` 
- When the library gets updated, the only thing you have to do is replace the previous luau files.
#
---
### DOCUMENTATION: Current available methods and attributes:
#
>Methods:
```luau
IAS.new(name: string) -- create and name a new bind.
IAS.Get(name: string?) -- returns the bind's table
IAS.GetAll() -- returns the entire IAS table

SetHold(hold: boolean) -- true by default, turns the bind as button or a switch

SetUIButton(button: GuiButton?) -- nil by default, set a GuiButton as a secondary source of activation 
-- There's currently a bug which prevents UIButton to trigger the InputAction if any keybinds has a Modifier option.

SetCooldown(cooldown: number) -- 0 by default, set a cooldown between each activation

ResetCooldown() -- resets current cooldown for the bind

SetEnabled(boolean) -- Enable or disable the bind

IsEnable() -- returns bind’s enable state

GetBinds() -- returns a list of all the keybinds of the bind

SetTapActivation(requiredTaps: number, tapWindow: number) -- 1, 0 by default, allows the bind to be activated by tapping a selected number of time. Cancels after a selected time

AddBind(mainKey: Enum.KeyCode, ...Enum.KeyCode?) -- Add one keybind; allows one or more modifiers

SetBinds(binds: { Bind }) -- Hard code your keybinds, and their modifiers. Check Code snippet under for usage

SetBind(mainKey:  Enum.KeyCode, ...Enum.KeyCode?) -- Replace all currently set keybinds by one keybind, same usage as AddBind()

RemoveBind(mainKey: Enum.KeyCode, ...Enum.KeyCode?) -- Remove a keybind. If that keybind has modifiers, consider deleting them too

EditBind(oldMain: Enum.KeyCode, oldMods: { Enum.KeyCode }?, newMain: Enum.KeyCode, newMods: { Enum.KeyCode }?)  -- Replace a keybind and its modifiers by a new one, if the previous keybind had modifiers, consider replacing them too (the new modifier can be blank)

ClearBinds() -- Removes all keybinds

Destroy() -- delete the bind

```
---
>Attributes:
```luau
Keybind.Name -- Name defined in .new() attribute

Keybind.Active -- State of the Keybind (activated or deactivated)

Keybind.Enabled --  Bind is enabled or disabled (not to confound with Active)

Keybind.Hold -- Holding state defined in :SetHold() method

Keybind.Cooldown -- Returns Keybind's cooldown in seconds

Keybind.Activated -- For now, no purpose of using this alone, consider adding it an IAScriptSignal Method

```
Available IAScriptSignal methods are the same ones as Roblox (Connect, ConnectParallel, Once, Wait)
Although they were custom made, they share Roblox's conventional usage, Check [RBXScriptSignal](https://create.roblox.com/docs/reference/engine/datatypes/RBXScriptSignal)

IIAS uses an other module of mine, [IllusionSignal](https://github.com/IllusionAC/IllusionSignal)
#
---
Exemple code: two keybinds changing Humanoid walkspeed
```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local I2AS = require(ReplicatedStorage.IllusionIAS)

local Player = Players.LocalPlayer
if not Player then return end
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
if not Humanoid then return end

local sprint = I2AS.new("Sprint")
local walk = I2AS.new("Walk")

sprint:SetHold(true)
walk:SetHold(true)

sprint:SetBinds({{KeyCode = Enum.KeyCode.LeftShift, Modifier = {}}})
walk:SetBinds({{KeyCode = Enum.KeyCode.LeftControl, Modifier = {}}})

sprint.Activated:Connect(function(active, pressed)
	Humanoid.WalkSpeed = active and 24 or 16
end)

walk.Activated:Connect(function(active, pressed) 
	Humanoid.WalkSpeed = active and 8 or 16
end)

```
#
Exemple code: easiest way to add a bind with other settings
```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local I2AS = require(ReplicatedStorage.IllusionIAS)

local Bind = I2AS.new("Bind")
Bind:AddBind(Enum.KeyCode.F, Enum.KeyCode.LeftShift) -- you have to press leftshift and F to activate the bind (F is the main key)
Bind:SetHold(false) -- when releasing, activation remains, you'll have to press the combination again
Bind:SetCooldown(2) -- cooldown between each activation
Bind:SetTapActivation(2,0.5) -- press twice the keys to activate (if it takes more than 0.5 seconds to press the second time, sink it

Bind.Activated:Connect(function(active, pressed) 
	print(active, pressed) -- will print the current activation and pressed state
end) 

```
#
---
Thanks for reading all of that, consider giving me feedbacks, suggestions, report the bugs etc...
#
Have fun scripting !
Illusion.
