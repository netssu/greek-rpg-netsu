local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)

local module = {}
local rs = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX
local dartMolVFX = VFX["Dart Mol"]

local function emitEffect(effect, parent, cleanupTime)
	if not effect then
		return
	end

	effect.Parent = parent or vfxFolder
	Debris:AddItem(effect, cleanupTime)
	VFX_Helper.EmitAllParticles(effect)
end

local function getStageFolder(stageName)
	return dartMolVFX:FindFirstChild(stageName) or (stageName == "Third" and dartMolVFX:FindFirstChild("Thrid"))
end

local function getStageEffect(folder, ...)
	if not folder then
		return nil
	end

	for _, name in ipairs({ ... }) do
		local child = folder:FindFirstChild(name)
		if child and not child:IsA("Sound") then
			return child
		end
	end

	for _, child in ipairs(folder:GetChildren()) do
		if not child:IsA("Sound") then
			return child
		end
	end

	return nil
end

local function setEffectCFrame(effect, cf)
	if not effect or not cf then
		return effect
	end

	local root = effect

	if effect:IsA("Model") then
		effect:PivotTo(cf)
	elseif effect:IsA("BasePart") then
		effect.CFrame = cf
	elseif effect:IsA("Attachment") then
		local holder = Instance.new("Part")
		holder.Name = effect.Name .. "_Holder"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(1, 1, 1)
		holder.CFrame = cf
		effect.Parent = holder
		root = holder
	end

	return root
end

module["Dart Mol Attack"] = function(HRP, target)
	local Folder = getStageFolder("First")
	local speed = GameSpeed.Value

	task.wait(0.78 / speed)
	if not HRP or not HRP.Parent then
		return
	end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, "SaberSwing" .. tostring(math.random(1, 2)))

	local firstEffect = getStageEffect(Folder, "First", "Winnd")
	if firstEffect then
		firstEffect = firstEffect:Clone()
		firstEffect = setEffectCFrame(firstEffect, HRP.CFrame * CFrame.new(0.5, 0.8, -1.4))
		emitEffect(firstEffect, vfxFolder, 3 / speed)
	end

	HRP.Parent.Attacking.Value = false
end

module["Blades of Darkness"] = function(HRP, target)
	local Folder = getStageFolder("Second")
	local speed = GameSpeed.Value

	task.wait(0.5 / speed)
	if not HRP or not HRP.Parent then
		return
	end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, "SaberSwing" .. tostring(math.random(1, 2)))

	local secondEffect = getStageEffect(Folder, "Second", "Slash", "Startemit", "Endlemit", "Teleportbls")
	if target and target:FindFirstChild("HumanoidRootPart") then
		if secondEffect then
			secondEffect = secondEffect:Clone()
			secondEffect = setEffectCFrame(secondEffect, CFrame.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z))
			emitEffect(secondEffect, vfxFolder, 4 / speed)
		end
	elseif secondEffect then
		secondEffect = secondEffect:Clone()
		secondEffect = setEffectCFrame(secondEffect, HRP.CFrame)
		emitEffect(secondEffect, vfxFolder, 4 / speed)
	end

	HRP.Parent.Attacking.Value = false
end

module["Ship Crash"] = function(HRP, target)
	local Folder = getStageFolder("Third")
	local speed = GameSpeed.Value

	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then
		return
	end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, "SaberSwing" .. tostring(math.random(1, 2)))

	if target and target:FindFirstChild("HumanoidRootPart") then
		local thirdEffect = getStageEffect(Folder, "Third", "Look", "Explosion")
		if thirdEffect then
			thirdEffect = thirdEffect:Clone()
			thirdEffect = setEffectCFrame(
				thirdEffect,
				CFrame.new(
					HRP.Position - HRP.CFrame.LookVector * 20 + Vector3.new(0, 90, 0),
					target.HumanoidRootPart.Position
				)
			)
			emitEffect(thirdEffect, vfxFolder, 4 / speed)
		end

		UnitSoundEffectLib.playSound(HRP.Parent, "Explosion")
	end

	HRP.Parent.Attacking.Value = false
end

return module
