-- // replicate first

local LoadingScreen = require(script.Parent.ReplicateFirst:WaitForChild("LoadingScreen", 5))

-- // setup modules

for _, Module in ipairs(script.Parent.Modules:GetDescendants()) do
	if Module:IsA("ModuleScript") and not Module.Parent:IsA("ModuleScript") then
		local success, err = pcall(function()
			require(Module)
		end)

		if not success then
			warn("⚠️ Failed to load module:", Module.Name, "-", err)
		end
	end
end

print("✅ | Client loaded all modules.")
LoadingScreen.Hide()