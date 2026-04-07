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
	Fire: (self: IAScriptSignal, active: variant, pressed: boolean?) -> (),
	Wait: (self: IAScriptSignal) -> variant,
	DisconnectAll: (self: IAScriptSignal) -> (),
}

export type Node = {
	fn: func?,
	next: Node?,
}

export type supposedKeyCode = Enum.KeyCode | string

export type Bind = {
	KeyCode: Enum.KeyCode,
	PrimaryModifier: Enum.KeyCode,
	SecondaryModifier: Enum.KeyCode
}

export type Binds = {
	[string]: Bind
}

export type DiffList = {
	BindName: string,
	ChangeType: string,
	OldKeyCode: Enum.KeyCode?,
	NewKeyCode: Enum.KeyCode?,
	OldModifiers: {	PrimaryModifier: Enum.KeyCode, SecondaryModifier: Enum.KeyCode },
	NewModifiers: {	PrimaryModifier: Enum.KeyCode, SecondaryModifier: Enum.KeyCode },
	AddedModifiers: { PrimaryModifier: Enum.KeyCode, SecondaryModifier: Enum.KeyCode },
	RemovedModifiers: {	PrimaryModifier: Enum.KeyCode, SecondaryModifier: Enum.KeyCode },
}

export type BindingObject = {
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

	PointerIndex: number,
	ClampMagnitudeToOne : boolean,

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

	Fire: (self: BindingObject, active: variant, pressed: boolean) -> (),

	SetHold: (self: BindingObject, bool: boolean) -> (),
	SetUIButton: (self: BindingObject, button: GuiButton?) -> (),
	SetTapActivation: (self: BindingObject, requiredTaps: number, tapWindow: number) -> (),
	SetCooldown: (self: BindingObject, cooldown: number) -> (),
	ResetCooldown: (self: BindingObject) -> (),

	SetEnabled: (self: BindingObject, bool: boolean) -> (),
	IsEnabled: (self: BindingObject) -> boolean,

	SetPriority: (self: BindingObject, number: number) -> (),
	GetPriority: (self: BindingObject) -> (number),

	SetSink: (self: BindingObject, bool: boolean) -> (),
	GetSink: (self: BindingObject) -> (boolean),

	SetScale: (self: BindingObject, scale: number) -> (),
	GetScale: (self: BindingObject) -> (number),

	SetVectorScale: (self: BindingObject, vector: Vector2 | Vector3) -> (),
	GetVectorScale: (self: BindingObject) -> (Vector2 | Vector3),

	SetResponseCurve: (self: BindingObject, curve: number) -> (),
	GetResponseCurve: (self: BindingObject) -> (number),

	SetPressedThreshold: (self: BindingObject, threshold: number) -> (),
	GetPressedThreshold: (self: BindingObject) -> (number),

	SetReleasedThreshold: (self: BindingObject, threshold: number) -> (),
	GetReleasedThreshold: (self: BindingObject) -> (number),

	SetPointerIndex: (self: BindingObject, index: number) -> (),
	GetPointerIndex: (self: BindingObject) -> (number),

	SetClampMagnitudeToOne: (self: BindingObject, bool: boolean) -> (),
	GetClampMagnitudeToOne: (self: BindingObject) -> (boolean),

	GetState: (self: BindingObject) -> (variant),

	SetInputBufferEnabled: (self: BindingObject, bool: boolean) -> (),
	SetInputBufferTime: (self: BindingObject, t: number) -> (),

	GetBinds: (self: BindingObject) -> (Binds),

	GetCooldownRemaining: (self: BindingObject) -> (number),
	IsBuffered: (self: BindingObject) -> (boolean),
	ResetBuffer: (self: BindingObject) -> (),
	GetBufferedVariant: (self: BindingObject) -> (variant?),
	GetBufferedKey: (self: BindingObject) -> (Enum.KeyCode?),
	GetActiveBindCount: (self: BindingObject) -> (number),
	GetToggleState: (self: BindingObject) -> (boolean),
	GetActiveMainKey: (self: BindingObject) -> (Enum.KeyCode?),

	AddBind: (self: BindingObject, mainKey: supposedKeyCode, PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode?) -> (),
	SetBind: (self: BindingObject, mainKey: supposedKeyCode, PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode?) -> (),
	RemoveBind: (self: BindingObject, mainKey: supposedKeyCode, PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode?) -> (),
	EditBind: (self: BindingObject, oldMain: supposedKeyCode, oldMods: {PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode? }, newMain: supposedKeyCode, newMods: {	PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode? }) -> (),
	SetDisplayName: (self: BindingObject, mainKey: supposedKeyCode, displayName: string) -> (boolean),
	GetDisplayName: (self: BindingObject, mainKey: supposedKeyCode) -> (string?),
	ClearBinds: (self: BindingObject) -> (),

	SetCompositeDirections: (self: BindingObject, up: supposedKeyCode?, down: supposedKeyCode?, left: supposedKeyCode?, right: supposedKeyCode?, forward: supposedKeyCode?, backward: supposedKeyCode?) -> (),
	SetCompositeModifiers: (self: BindingObject, PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode?) -> (),

	Destroy: (self: BindingObject) -> (boolean),
}

export type Context = { Enabled: boolean, Members: {[string]: boolean}}

export type Contexts = { [string]: Context }

export type IllusionIAS = {
	contextedBinds: Contexts,
	enableControlHints: (module: Instance | string, parent: Instance | PlayerGui?) -> ScreenGui,
	new: (name: string, inputType: Enum.InputActionType?) -> BindingObject,
	get: (name: string) -> BindingObject?,
	getAll: () -> {[string]: BindingObject},
	newContext: (name: string) -> (),
	getContext: (name: string) -> (Context),
	addContext: (name: string, ...BindingObject) -> (),
	enableContext: (name: string, enabled: boolean) -> (), 
	isContextEnabled: (name: string) -> boolean,
	removeContext: (name: string) -> (),
	removeFromContext: (name: string, bind: BindingObject) -> (),
	removeAllFromContext: (name: string) -> (),
	clearContexts: () -> (),
}

local InputTypeByKey: {[Enum.KeyCode]: "Keyboard" | "Gamepad" | "Mobile"} = {
	[Enum.KeyCode.MouseLeftButton] = "Keyboard",
	[Enum.KeyCode.MouseRightButton] = "Keyboard",
	[Enum.KeyCode.MouseMiddleButton] = "Keyboard",
	[Enum.KeyCode.A] = "Keyboard",
	[Enum.KeyCode.B] = "Keyboard",
	[Enum.KeyCode.C] = "Keyboard",
	[Enum.KeyCode.D] = "Keyboard",
	[Enum.KeyCode.E] = "Keyboard",
	[Enum.KeyCode.F] = "Keyboard",
	[Enum.KeyCode.G] = "Keyboard",
	[Enum.KeyCode.H] = "Keyboard",
	[Enum.KeyCode.I] = "Keyboard",
	[Enum.KeyCode.J] = "Keyboard",
	[Enum.KeyCode.K] = "Keyboard",
	[Enum.KeyCode.L] = "Keyboard",
	[Enum.KeyCode.M] = "Keyboard",
	[Enum.KeyCode.N] = "Keyboard",
	[Enum.KeyCode.O] = "Keyboard",
	[Enum.KeyCode.P] = "Keyboard",
	[Enum.KeyCode.Q] = "Keyboard",
	[Enum.KeyCode.R] = "Keyboard",
	[Enum.KeyCode.S] = "Keyboard",
	[Enum.KeyCode.T] = "Keyboard",
	[Enum.KeyCode.U] = "Keyboard",
	[Enum.KeyCode.V] = "Keyboard",
	[Enum.KeyCode.W] = "Keyboard",
	[Enum.KeyCode.X] = "Keyboard",
	[Enum.KeyCode.Y] = "Keyboard",
	[Enum.KeyCode.Z] = "Keyboard",
	[Enum.KeyCode.Zero] = "Keyboard",
	[Enum.KeyCode.One] = "Keyboard",
	[Enum.KeyCode.Two] = "Keyboard",
	[Enum.KeyCode.Three] = "Keyboard",
	[Enum.KeyCode.Four] = "Keyboard",
	[Enum.KeyCode.Five] = "Keyboard",
	[Enum.KeyCode.Six] = "Keyboard",
	[Enum.KeyCode.Seven] = "Keyboard",
	[Enum.KeyCode.Eight] = "Keyboard",
	[Enum.KeyCode.Nine] = "Keyboard",
	[Enum.KeyCode.Up] = "Keyboard",
	[Enum.KeyCode.Down] = "Keyboard",
	[Enum.KeyCode.Left] = "Keyboard",
	[Enum.KeyCode.Right] = "Keyboard",
	[Enum.KeyCode.LeftShift] = "Keyboard",
	[Enum.KeyCode.RightShift] = "Keyboard",
	[Enum.KeyCode.LeftControl] = "Keyboard",
	[Enum.KeyCode.RightControl] = "Keyboard",
	[Enum.KeyCode.LeftAlt] = "Keyboard",
	[Enum.KeyCode.RightAlt] = "Keyboard",
	[Enum.KeyCode.Space] = "Keyboard",
	[Enum.KeyCode.Tab] = "Keyboard",
	[Enum.KeyCode.Return] = "Keyboard",
	[Enum.KeyCode.Backspace] = "Keyboard",
	[Enum.KeyCode.Escape] = "Keyboard",
	[Enum.KeyCode.Comma] = "Keyboard",
	[Enum.KeyCode.Period] = "Keyboard",
	[Enum.KeyCode.Slash] = "Keyboard",
	[Enum.KeyCode.Semicolon] = "Keyboard",
	[Enum.KeyCode.Quote] = "Keyboard",
	[Enum.KeyCode.LeftBracket] = "Keyboard",
	[Enum.KeyCode.RightBracket] = "Keyboard",
	[Enum.KeyCode.BackSlash] = "Keyboard",
	[Enum.KeyCode.Minus] = "Keyboard",
	[Enum.KeyCode.Equals] = "Keyboard",

	[Enum.KeyCode.ButtonA] = "Gamepad",
	[Enum.KeyCode.ButtonB] = "Gamepad",
	[Enum.KeyCode.ButtonX] = "Gamepad",
	[Enum.KeyCode.ButtonY] = "Gamepad",
	[Enum.KeyCode.ButtonL1] = "Gamepad",
	[Enum.KeyCode.ButtonR1] = "Gamepad",
	[Enum.KeyCode.ButtonL2] = "Gamepad",
	[Enum.KeyCode.ButtonR2] = "Gamepad",
	[Enum.KeyCode.ButtonL3] = "Gamepad",
	[Enum.KeyCode.ButtonR3] = "Gamepad",
	[Enum.KeyCode.DPadUp] = "Gamepad",
	[Enum.KeyCode.DPadDown] = "Gamepad",
	[Enum.KeyCode.DPadLeft] = "Gamepad",
	[Enum.KeyCode.DPadRight] = "Gamepad",
	[Enum.KeyCode.ButtonStart] = "Gamepad",
	[Enum.KeyCode.ButtonSelect] = "Gamepad",

	[Enum.KeyCode.Touch] = "Mobile",
}

return {
	InputTypeByKey = InputTypeByKey
}
