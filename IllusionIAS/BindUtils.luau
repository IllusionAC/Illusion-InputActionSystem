--!strict
--BindUtils.luau
--[[
  //////////////////////
 //   Bind Utility   //
//////////////////////
]]

local BindUtils = {}

local IAS = require("./TypeDefinition")

local REMOVED: IAS.Bind = {
	KeyCode = Enum.KeyCode.Unknown,
	Modifier = {}
}

@native local function isKeyCode(value: any): boolean
	return typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode
end

@native local function normalizeModifiers(modifiers: {Enum.KeyCode?}): {Enum.KeyCode?}
	local seen: { [Enum.KeyCode]: boolean } = {}
	local result: { Enum.KeyCode? } = {}

	for _, key in modifiers do
		if not key then continue end
		if isKeyCode(key) and not seen[key] then
			seen[key] = true
			table.insert(result, key)
		end
	end

	return result
end

local function getBind(binds: IAS.Binds, name: string): IAS.Bind?
	return binds[name]
end

@native local function modifierSetEqual(a: {Enum.KeyCode?}, b: {Enum.KeyCode?}): boolean
	if #a ~= #b then return false end

	local lookup: { [Enum.KeyCode]: boolean } = {}
	for _, key in a do
		if not key then continue end
		lookup[key] = true
	end

	for _, key in b do
		if not key then continue end
		if not lookup[key] then
			return false
		end
	end

	return true
end

function BindUtils.AddBind(binds: IAS.Binds, name: string, keyCode: Enum.KeyCode?, modifiers: {Enum.KeyCode?}): boolean

	if binds[name] ~= nil then return false end

	binds[name] = {
		KeyCode = if isKeyCode(keyCode) and keyCode then keyCode else Enum.KeyCode.Unknown,
		Modifier = normalizeModifiers(modifiers),
	}

	return true
end

function BindUtils.RemoveBind(binds: IAS.Binds, name: string): boolean
	if binds[name] == nil then return false end
	binds[name] = nil
	return true
end

local function setKeyCode(binds: IAS.Binds, name: string, keyCode: Enum.KeyCode): boolean
	local bind = getBind(binds, name)
	if not bind then return false end
	bind.KeyCode = keyCode
	return true
end

local function setModifiers(binds: IAS.Binds, name: string, modifiers: { Enum.KeyCode? }): boolean
	local bind = getBind(binds, name)
	if not bind then return false end
	bind.Modifier = modifiers
	return true
end

function BindUtils.SetKeyCode(binds, name, keyCode)
	return setKeyCode(binds, name, keyCode)
end

function BindUtils.ResetKeyCode(binds, name)
	return setKeyCode(binds, name, Enum.KeyCode.Unknown)
end

function BindUtils.AddModifier(binds: IAS.Binds, name: string, modifier: Enum.KeyCode): boolean
	local bind = getBind(binds, name)
	if not bind then return false end

	for _, existing in bind.Modifier do
		if existing == modifier then return true end
	end

	table.insert(bind.Modifier, modifier)
	return true
end

function BindUtils.RemoveModifier(binds: IAS.Binds, name: string, modifier: Enum.KeyCode): boolean
	local bind = getBind(binds, name)
	if not bind then
		return false
	end

	for i = #bind.Modifier, 1, -1 do
		if bind.Modifier[i] == modifier then
			table.remove(bind.Modifier, i)
			return true
		end
	end

	return false
end

function BindUtils.ClearModifiers(binds, name)
	return setModifiers(binds, name, {})
end

function BindUtils.ResetBinds(binds: IAS.Binds): boolean
	for name in binds do
		binds[name] = nil
	end

	binds.MainAction = {
		KeyCode = Enum.KeyCode.Unknown,
		Modifier = {},
	}
	
	binds.UIButton = {
		KeyCode = Enum.KeyCode.Unknown,
		Modifier = {},
	}

	return true
end


function BindUtils.SetModifiers(binds, name, modifiers)
	return setModifiers(binds, name, normalizeModifiers(modifiers))
end

function BindUtils.HasBind(binds: IAS.Binds, name: string): boolean
	return binds[name] ~= nil
end

function BindUtils.GetKeyCode(binds: IAS.Binds, name: string): Enum.KeyCode?
	local bind = getBind(binds, name)
	return bind and bind.KeyCode or nil
end

function BindUtils.GetModifiers(binds: IAS.Binds, name: string): { Enum.KeyCode }?
	local bind = getBind(binds, name)
	if not bind then return nil end

	local result = table.create(#bind.Modifier) :: {Enum.KeyCode}
	for i, v in bind.Modifier do 
		if not v then continue end
		result[i] = v 
	end
	return result
end

function BindUtils.HasModifier(binds: IAS.Binds, name: string, modifier: Enum.KeyCode): boolean
	local bind = getBind(binds, name)
	if not bind then return false end

	for _, key in bind.Modifier do
		if key == modifier then
			return true
		end
	end

	return false
end

@native function BindUtils.Clone(binds: IAS.Binds): IAS.Binds
	local clone: IAS.Binds = {}

	for name, bind in binds do
		local modifiersCopy = table.create(#bind.Modifier) :: {Enum.KeyCode?}
		for i, key in bind.Modifier do modifiersCopy[i] = key end

		clone[name] = {
			KeyCode = bind.KeyCode,
			Modifier = modifiersCopy,
		}
	end

	return clone
end

@native function BindUtils.CheckDifferences(base: IAS.Binds, compare: IAS.Binds): (boolean, IAS.Binds?)
	local differences: IAS.Binds = {}
	local hasDifferences = false

	for name, compareBind in compare do
		local baseBind = base[name]

		if not baseBind then
			hasDifferences = true
			differences[name] = {
				KeyCode = compareBind.KeyCode,
				Modifier = table.clone(compareBind.Modifier),
			}
			continue
		end

		local entryDiff = {}

		if baseBind.KeyCode ~= compareBind.KeyCode then
			entryDiff.KeyCode = compareBind.KeyCode
		end

		if not modifierSetEqual(baseBind.Modifier, compareBind.Modifier) then
			entryDiff.Modifier = table.clone(compareBind.Modifier)
		end

		if next(entryDiff) ~= nil then
			hasDifferences = true
			differences[name] = entryDiff
		end
	end

	for name in base do
		if compare[name] == nil then
			hasDifferences = true
			differences[name] = REMOVED
		end
	end

	if not hasDifferences then
		return true, nil
	end

	return false, differences
end

@native function BindUtils.ApplyDifferences(target: IAS.Binds, differences: IAS.Binds): boolean
	local changed = false

	for name, diff in differences do
		if diff == REMOVED then
			if target[name] ~= nil then
				target[name] = nil
				changed = true
			end
			continue
		end

		local bind = target[name]
		if not bind then
			bind = {
				KeyCode = Enum.KeyCode.Unknown,
				Modifier = {},
			}
			target[name] = bind
			changed = true
		end

		if diff.KeyCode ~= nil and bind.KeyCode ~= diff.KeyCode then
			bind.KeyCode = diff.KeyCode
			changed = true
		end

		if diff.Modifier ~= nil then
			local mods: {Enum.KeyCode?} = table.create(#diff.Modifier):: {Enum.KeyCode?}
			for i, key in diff.Modifier do
				mods[i] = key
			end
			bind.Modifier = mods
			changed = true
		end
	end

	return changed
end

@native local function cloneModifiers(mods: {Enum.KeyCode?}): {Enum.KeyCode}
	local copy = table.create(#mods) :: {Enum.KeyCode}
	for i, k in mods do
		if not k then continue end
		copy[i] = k
	end
	return copy
end

@native function BindUtils.GetDifference(base: IAS.Binds, differences: IAS.Binds)
	local results: {IAS.DiffList} = {}

	for name, diff in differences do
		local baseBind = base[name]
		
		if diff == REMOVED then
			if baseBind then
				table.insert(results, {
					BindName = name,
					ChangeType = "Removed",

					OldKeyCode = baseBind.KeyCode,
					NewKeyCode = nil,

					OldModifiers = cloneModifiers(baseBind.Modifier),
					NewModifiers = cloneModifiers({}),

					AddedModifiers = cloneModifiers({}),
					RemovedModifiers = cloneModifiers(baseBind.Modifier),
				})
			end
			continue
		end

		if not baseBind then
			table.insert(results, {
				BindName = name,
				ChangeType = "Added",

				OldKeyCode = nil,
				NewKeyCode = diff.KeyCode,

				OldModifiers = cloneModifiers({}),
				NewModifiers = cloneModifiers(diff.Modifier),

				AddedModifiers = cloneModifiers(diff.Modifier),
				RemovedModifiers = cloneModifiers({}),
			})
			continue
		end

		local oldMods = baseBind.Modifier
		local newMods = diff.Modifier or oldMods

		local oldLookup: {[Enum.KeyCode]: boolean} = {}
		for _, k in oldMods do
			if not k then continue end
			oldLookup[k] = true
		end

		local newLookup: {[Enum.KeyCode]: boolean} = {}
		for _, k in newMods do
			if not k then continue end
			newLookup[k] = true
		end

		local added = {}
		local removed = {}

		for k in newLookup do
			if not oldLookup[k] then
				table.insert(added, k)
			end
		end

		for k in oldLookup do
			if not newLookup[k] then
				table.insert(removed, k)
			end
		end

		table.insert(results, {
			BindName = name,
			ChangeType = "Modified",

			OldKeyCode = baseBind.KeyCode,
			NewKeyCode = diff.KeyCode or baseBind.KeyCode,

			OldModifiers = cloneModifiers(oldMods),
			NewModifiers = cloneModifiers(newMods),

			AddedModifiers = added,
			RemovedModifiers = removed,
		})
	end

	return results
end

return BindUtils
