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
	PrimaryModifier = Enum.KeyCode.Unknown,
	SecondaryModifier = Enum.KeyCode.Unknown
}

@native local function isKeyCode(value: any): boolean
	return typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode
end

local function getBind(binds: IAS.Binds, name: string): IAS.Bind?
	return binds[name]
end

function BindUtils.AddBind(binds: IAS.Binds, name: string, keyCode: Enum.KeyCode?, PrimaryModifier: Enum.KeyCode?, SecondaryModifier: Enum.KeyCode?): boolean

	if binds[name] ~= nil then return false end

	binds[name] = {
		KeyCode = if isKeyCode(keyCode) and keyCode then keyCode else Enum.KeyCode.Unknown,
		PrimaryModifier = if isKeyCode(PrimaryModifier) and PrimaryModifier then PrimaryModifier else Enum.KeyCode.Unknown,
		SecondaryModifier = if isKeyCode(SecondaryModifier) and SecondaryModifier then SecondaryModifier else Enum.KeyCode.Unknown
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

local function setModifiers(binds: IAS.Binds, name: string, PrimaryModifier: Enum.KeyCode?, SecondaryModifier: Enum.KeyCode?): boolean
	local bind = getBind(binds, name)
	if not bind then return false end
	bind.PrimaryModifier = PrimaryModifier or Enum.KeyCode.Unknown
	bind.SecondaryModifier = SecondaryModifier or Enum.KeyCode.Unknown
	return true
end

function BindUtils.SetKeyCode(binds, name, keyCode)
	return setKeyCode(binds, name, keyCode)
end

function BindUtils.ResetKeyCode(binds, name)
	return setKeyCode(binds, name, Enum.KeyCode.Unknown)
end

function BindUtils.ClearModifiers(binds, name)
	return setModifiers(binds, name)
end

function BindUtils.ResetBinds(binds: IAS.Binds): boolean
	for name in binds do
		binds[name] = nil
	end

	binds.MainAction = {
		KeyCode = Enum.KeyCode.Unknown,
		PrimaryModifier = Enum.KeyCode.Unknown,
		SecondaryModifier = Enum.KeyCode.Unknown
	}

	return true
end


function BindUtils.SetModifiers(binds, name, PrimaryModifier, SecondaryModifier)
	return setModifiers(binds, name, PrimaryModifier, SecondaryModifier)
end

@native function BindUtils.Clone(binds: IAS.Binds): IAS.Binds
	local clone: IAS.Binds = {}

	for name, bind in binds do
		clone[name] = {
			KeyCode = bind.KeyCode,
			PrimaryModifier = bind.PrimaryModifier,
			SecondaryModifier = bind.SecondaryModifier
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
				PrimaryModifier = compareBind.PrimaryModifier,
				SecondaryModifier = compareBind.SecondaryModifier
			}
			continue
		end

		local entryDiff = {}

		if baseBind.KeyCode ~= compareBind.KeyCode then
			entryDiff.KeyCode = compareBind.KeyCode
		end

		if baseBind.PrimaryModifier ~= compareBind.PrimaryModifier then
			entryDiff.PrimaryModifier = compareBind.PrimaryModifier
		end

		if baseBind.SecondaryModifier ~= compareBind.SecondaryModifier then
			entryDiff.SecondaryModifier = compareBind.SecondaryModifier
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
				PrimaryModifier = Enum.KeyCode.Unknown,
				SecondaryModifier = Enum.KeyCode.Unknown,
			}
			target[name] = bind
			changed = true
		end

		if diff.KeyCode ~= nil and bind.KeyCode ~= diff.KeyCode then
			bind.KeyCode = diff.KeyCode
			changed = true
		end

		if diff.PrimaryModifier ~= nil and bind.PrimaryModifier ~= diff.PrimaryModifier then
			bind.PrimaryModifier = diff.PrimaryModifier
			changed = true
		end

		if diff.SecondaryModifier ~= nil and bind.SecondaryModifier ~= diff.SecondaryModifier then
			bind.SecondaryModifier = diff.SecondaryModifier
			changed = true
		end

	end

	return changed
end

@native function BindUtils.GetDifference(base: IAS.Binds, differences: IAS.Binds)
	local results: { IAS.DiffList } = {}

	for bindName, diff in differences do
		local baseBind = base[bindName]

		if diff == REMOVED then
			if baseBind then
				table.insert(results, {
					BindName = bindName,
					ChangeType = "Removed",

					OldKeyCode = baseBind.KeyCode,
					NewKeyCode = nil,

					OldModifiers = {
						PrimaryModifier = baseBind.PrimaryModifier,
						SecondaryModifier = baseBind.SecondaryModifier,
					},

					NewModifiers = {
						PrimaryModifier = Enum.KeyCode.Unknown,
						SecondaryModifier = Enum.KeyCode.Unknown,
					},

					AddedModifiers = {
						PrimaryModifier = Enum.KeyCode.Unknown,
						SecondaryModifier = Enum.KeyCode.Unknown,
					},

					RemovedModifiers = {
						PrimaryModifier = baseBind.PrimaryModifier,
						SecondaryModifier = baseBind.SecondaryModifier,
					},
				})
			end
			continue
		end

		if not baseBind then
			table.insert(results, {
				BindName = bindName,
				ChangeType = "Added",

				OldKeyCode = nil,
				NewKeyCode = diff.KeyCode,

				OldModifiers = {
					PrimaryModifier = Enum.KeyCode.Unknown,
					SecondaryModifier = Enum.KeyCode.Unknown,
				},

				NewModifiers = {
					PrimaryModifier = diff.PrimaryModifier,
					SecondaryModifier = diff.SecondaryModifier,
				},

				AddedModifiers = {
					PrimaryModifier = diff.PrimaryModifier,
					SecondaryModifier = diff.SecondaryModifier,
				},

				RemovedModifiers = {
					PrimaryModifier = Enum.KeyCode.Unknown,
					SecondaryModifier = Enum.KeyCode.Unknown,
				},
			})
			continue
		end

		local oldPM = baseBind.PrimaryModifier
		local oldSM = baseBind.SecondaryModifier
		local newPM = diff.PrimaryModifier or oldPM
		local newSM = diff.SecondaryModifier or oldSM

		local addedPM = Enum.KeyCode.Unknown
		local addedSM = Enum.KeyCode.Unknown
		local removedPM = Enum.KeyCode.Unknown
		local removedSM = Enum.KeyCode.Unknown

		if oldPM ~= newPM then
			if newPM ~= Enum.KeyCode.Unknown then
				addedPM = newPM
			end
			if oldPM ~= Enum.KeyCode.Unknown then
				removedPM = oldPM
			end
		end

		if oldSM ~= newSM then
			if newSM ~= Enum.KeyCode.Unknown then
				addedSM = newSM
			end
			if oldSM ~= Enum.KeyCode.Unknown then
				removedSM = oldSM
			end
		end

		table.insert(results, {
			BindName = bindName,
			ChangeType = "Modified",

			OldKeyCode = baseBind.KeyCode,
			NewKeyCode = diff.KeyCode or baseBind.KeyCode,

			OldModifiers = {
				PrimaryModifier = oldPM,
				SecondaryModifier = oldSM,
			},

			NewModifiers = {
				PrimaryModifier = newPM,
				SecondaryModifier = newSM,
			},

			AddedModifiers = {
				PrimaryModifier = addedPM,
				SecondaryModifier = addedSM,
			},

			RemovedModifiers = {
				PrimaryModifier = removedPM,
				SecondaryModifier = removedSM,
			},
		})
	end

	return results
end

return BindUtils
