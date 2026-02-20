local Scroller = script.Parent.Parent.Parent:WaitForChild("ScrollingFrame")

script.Parent.Changed:Connect(function()
	local text = string.lower(script.Parent.Text)

	if text == "" then
		for _, frame in ipairs(Scroller:GetChildren()) do
			if frame:IsA("Frame") then
				frame.Visible = true
			end
		end
	else
		for _, frame in ipairs(Scroller:GetChildren()) do
			if frame:IsA("Frame") then
				local name = string.lower(frame.Name)
				frame.Visible = string.find(name, text) ~= nil
			end
		end
	end
end)