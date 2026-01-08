--!strict
--TypeDefinition.luau
--[[
  //////////////////////
 // Type Declaration //
//////////////////////
]]

export type variant = boolean | number | Vector2 | Vector3

export type func = (active: variant, pressed: boolean?) -> ()

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

export type Binds = {
	[string]: Bind
}

export type DiffList = {
	BindName: string,
	ChangeType: string,
	OldKeyCode: Enum.KeyCode?,
	NewKeyCode: Enum.KeyCode?,
	OldModifiers: {Enum.KeyCode?},
	NewModifiers: {Enum.KeyCode?},
	AddedModifiers: {Enum.KeyCode?},
	RemovedModifiers: {Enum.KeyCode?},
}

export type Object = {
	Name: string,
	
	Hold: boolean,

	Binds: Binds,
	
	UIButton: GuiButton?,
	
	Active: variant,

	Enabled: boolean,
	Priority: number,
	Sink: boolean,
	
	Scale: number,
	VectorScale: Vector2 | Vector3,
	ResponseCurve: number,
	
	PressedThreshold: number,
	ReleasedThreshold: number,

	Cooldown: number,

	TapRequired: number,
	TapWindow: number,
	
	InputBufferEnabled: boolean,
	InputBufferTime: number,

	Activated: IAScriptSignal,
	Started: IAScriptSignal,
	Ended: IAScriptSignal,

	
	SetHold: (self: Object, bool: boolean) -> (),
	SetUIButton: (self: Object, button: GuiButton?) -> (),
	SetTapActivation: (self: Object, requiredTaps: number, tapWindow: number) -> (),
	SetCooldown: (self: Object, cooldown: number) -> (),
	ResetCooldown: (self: Object) -> (),
	
	SetEnabled: (self: Object, bool: boolean) -> (),
	IsEnabled: (self: Object) -> boolean,
	
	SetPriority: (self: Object, number: number) -> (),
	GetPriority: (self: Object) -> (number),
	
	SetSink: (self: Object, bool: boolean) -> (),
	GetSink: (self: Object) -> (boolean),
	
	SetScale: (self: Object, scale: number) -> (),
	GetScale: (self: Object) -> (number),

	SetVectorScale: (self: Object, vector: Vector2 | Vector3) -> (),
	GetVectorScale: (self: Object) -> (Vector2 | Vector3),

	SetResponseCurve: (self: Object, curve: number) -> (),
	GetResponseCurve: (self: Object) -> (number),
	
	SetPressedThreshold: (self: Object, threshold: number) -> (),
	GetPressedThreshold: (self: Object) -> (number),
	
	SetReleasedThreshold: (self: Object, threshold: number) -> (),
	GetReleasedThreshold: (self: Object) -> (number),
	
	GetState: (self: Object) -> (variant),
	
	SetInputBufferEnabled: (self: Object, bool: boolean) -> (),
	SetInputBufferTime: (self: Object, t: number) -> (),

	GetBinds: (self: Object) -> {Binds},
	AddBind: (self: Object, mainKey: Enum.KeyCode, ...(Enum.KeyCode?)) -> (),
	SetBind: (self: Object, mainKey:  Enum.KeyCode, ...(Enum.KeyCode?)) -> (),
	RemoveBind: (self: Object, mainKey: Enum.KeyCode, ...(Enum.KeyCode?)) -> (),
	EditBind: (self: Object, oldMain: Enum.KeyCode, oldMods: {Enum.KeyCode?}, newMain: Enum.KeyCode, newMods: {Enum.KeyCode?}) -> (),
	ClearBinds: (self: Object) -> (),
	
	SetCompositeDirections: (self: Object, up: Enum.KeyCode?, down: Enum.KeyCode?, left: Enum.KeyCode?, right: Enum.KeyCode?, forward: Enum.KeyCode?, backward: Enum.KeyCode?) -> (),
	
	Destroy: (self: Object) -> (boolean),
}

export type IllusionIAS = {
	contextedBinds: { [string]: { Object } },
	new: (name: string, inputType: Enum.InputActionType?) -> Object,
	get: (name: string) -> Object?,
	getAll: () -> {[string]: Object},
	newContext: (name: string) -> (),
	getContext: (name: string) -> ({Enabled: boolean, Members: {[string]: boolean}}),
	addContext: (name: string, ...Object) -> (),
	enableContext: (name: string, enabled: boolean) -> (), 
	isContextEnabled: (name: string) -> boolean,
	removeContext: (name: string) -> (),
	removeFromContext: (name: string) -> (),
	removeAllFromContext: (name: string) -> (),
	clearContexts: () -> (),
}

return {}
