--!strict
--TypeDefinition.luau
--[[
  //////////////////////
 // Type Declaration //
//////////////////////
]]

export type func = (active: boolean, pressed: boolean) -> ()

export type IAScriptConnection = {
	Connected: boolean,
	Disconnect: (self: IAScriptConnection) -> (),
}

export type IAScriptSignal = {
	Connect: (self: IAScriptSignal, fn: func) -> IAScriptConnection,
	Once: (self: IAScriptSignal, fn: func) -> IAScriptConnection,
	Fire: (self: IAScriptSignal, ...any) -> (),
	Wait: (self: IAScriptSignal) -> ...any,
	DisconnectAll: (self: IAScriptSignal) -> (),
}

export type Node = {
	fn: func,
	next: Node?,
}

export type Bind = {
	KeyCode: Enum.KeyCode,
	Modifier: { Enum.KeyCode? },
}

export type Object = {
	Name: string,
	
	Hold: boolean,
	_PrevHold: boolean,

	Binds: { Bind },
	_PrevBinds: { Bind },

	UIButton: GuiButton?,
	_PrevUIButton: GuiButton?,
	
	Active: boolean,
	_ToggleState: boolean,

	Enabled: boolean,

	Cooldown: number,
	_PrevCooldown: number,
	_CooldownUntil: number,

	TapRequired: number,
	TapWindow: number,
	_PrevTapRequired: number,
	_PrevTapWindow: number,

	_LastTapTime: number,
	_TapCount: number,

	Activated: IAScriptSignal,
	
	SetHold: (self: Object, hold: boolean) -> (),
	SetUIButton: (self: Object, button: GuiButton?) -> (),
	SetBinds: (self: Object, binds: { Bind }) -> (),
	SetCooldown: (self: Object, cooldown: number) -> (),
	SetTapActivation: (self: Object, requiredTaps: number, tapWindow: number) -> (),
	SetEnabled: (self: Object, enabled: boolean) -> (),
	IsEnabled: (self: Object) -> boolean,
	GetBinds: (self: Object) -> {},

	AddBind: (self: Object, mainKey: Enum.KeyCode, ...(Enum.KeyCode?)) -> (),
	SetBind: (self: Object, mainKey:  Enum.KeyCode, ...(Enum.KeyCode?)) -> (),
	RemoveBind: (self: Object, mainKey: Enum.KeyCode, ...(Enum.KeyCode?)) -> (),
	EditBind: (self: Object, oldMain: Enum.KeyCode, oldMods: {Enum.KeyCode?}, newMain: Enum.KeyCode, newMods: {Enum.KeyCode?}) -> (),
	ClearBinds: (self: Object) -> (),
	
	Destroy: (self: Object) -> (),
}

return {}
