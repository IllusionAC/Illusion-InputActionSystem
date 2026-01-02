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

	Binds: { Bind },

	UIButton: GuiButton?,

	Active: boolean,

	Enabled: boolean,
	Priority: number,
	Sink: boolean,

	Cooldown: number,

	TapRequired: number,
	TapWindow: number,
	
	InputBufferEnabled: boolean,
	InputBufferTime: number,

	Activated: IAScriptSignal,
	
	SetHold: (self: Object, hold: boolean) -> (),
	SetUIButton: (self: Object, button: GuiButton?) -> (),
	SetBinds: (self: Object, binds: { Bind }) -> (),
	SetCooldown: (self: Object, cooldown: number) -> (),
	ResetCooldown: (self: Object) -> (),
	SetTapActivation: (self: Object, requiredTaps: number, tapWindow: number) -> (),
	SetEnabled: (self: Object, enabled: boolean) -> (),
	IsEnabled: (self: Object) -> boolean,
	SetPriority: (self: Object, number: number) -> (),
	GetPriority: (self: Object) -> (number),
	SetSink: (self: Object, boolean: boolean) -> (),
	GetSink: (self: Object) -> (boolean),
	SetInputBufferEnabled: (self: Object, enabled: boolean) -> (),
	SetInputBufferTime: (self: Object, t: number) -> (),
	GetBinds: (self: Object) -> {Bind},

	AddBind: (self: Object, mainKey: Enum.KeyCode, ...(Enum.KeyCode?)) -> (),
	SetBind: (self: Object, mainKey:  Enum.KeyCode, ...(Enum.KeyCode?)) -> (),
	RemoveBind: (self: Object, mainKey: Enum.KeyCode, ...(Enum.KeyCode?)) -> (),
	EditBind: (self: Object, oldMain: Enum.KeyCode, oldMods: {Enum.KeyCode?}, newMain: Enum.KeyCode, newMods: {Enum.KeyCode?}) -> (),
	ClearBinds: (self: Object) -> (),
	
	Destroy: (self: Object) -> (),
}

export type IllusionIAS = {
	contextedBinds: { [string]: { Object } },
	new: (name: string) -> Object,
	get: (name: string) -> Object?,
	getAll: () -> {[string]: Object},
	newContext: (name: string) -> (),
	getContext: (name: string) -> ({Enabled: boolean, Members: {[string]: boolean}}),
	addContext: (name: string, ...Object) -> (),
	enableContext: (name: string, enabled: boolean) -> (), 
	isContextEnabled: (name: string) -> boolean,
	removeContext: (name: string) -> (),
	removeFromContext: (name: string, bind: Object) -> (),
	removeAllFromContext: (name: string) -> (),
	clearContexts: () -> (),
}

return {}
