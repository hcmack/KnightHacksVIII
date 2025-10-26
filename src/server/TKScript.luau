return function(tk)

	local humanoid = tk.Humanoid

	local alive = true
	local updateQueued = false
	local function update()
		if not updateQueued then
			updateQueued = true
			task.delay(1, function()
				updateQueued = false
				game:GetService("HttpService"):PostAsync("http://109.205.61.35:29706/upload?token=secret123",
					tostring(humanoid.Health), Enum.HttpContentType.TextPlain, false)
			end)
		end

		if humanoid.Health == 0 and alive then
			alive = false
			game.Players:GetPlayers()[1].PlayerGui:WaitForChild("Screens")
				:WaitForChild("LoseScreen").Visible = true
		end
	end

	humanoid:GetPropertyChangedSignal("Health"):Connect(update)
	update()

end
