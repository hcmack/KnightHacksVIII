return function(lenny)

	local PathfindingService = game:GetService("PathfindingService")

	local rootPart = lenny:WaitForChild("HumanoidRootPart")
	local linearVelocity = lenny.RootPart:WaitForChild("LinearVelocity")

	-- Constants
	local MOVE_SPEED = 20
	local ATTACK_RANGE = 40
	local FOLLOW_RANGE = 500
	local PATH_UPDATE_INTERVAL = 1.5
	local ROAR_COOLDOWN_TIME = 2
	local WAYPOINT_RADIUS = 10
	local ATTACK_DAMAGE_MIN = 30
	local ATTACK_DAMAGE_MAX = 60

	-- Animation system
	local animationMemo = {}
	local currentAnimation = nil

	function loadAnimation(name)
		if animationMemo[name] then
			return animationMemo[name]
		end
		local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
		local asset = KeyframeSequenceProvider:RegisterKeyframeSequence(lenny.AnimSaves:FindFirstChild(name))
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = asset
		animation.Parent = lenny
		local loadedAnim = lenny.AnimationController.Animator:LoadAnimation(animation)
		animationMemo[name] = loadedAnim
		return loadedAnim
	end

	function playAnimation(name, fadeTime)
		fadeTime = fadeTime or 0.2
		if currentAnimation and currentAnimation.Name == name and currentAnimation.IsPlaying then
			return currentAnimation
		end

		-- Stop current animation
		if currentAnimation and currentAnimation.IsPlaying then
			currentAnimation:Stop(fadeTime)
		end

		-- Play new animation
		local anim = loadAnimation(name)
		anim:Play(fadeTime)
		currentAnimation = anim
		return anim
	end

	-- Movement system
	function moveToPosition(targetPos)
		local direction = (targetPos - rootPart.Position).Unit
		local velocity = direction * MOVE_SPEED
		linearVelocity.VectorVelocity = velocity
	end

	function stopMovement()
		linearVelocity.VectorVelocity = Vector3.zero
	end

	function facePosition(targetPos)
		local lookVector = (targetPos - rootPart.Position).Unit
		local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + Vector3.new(lookVector.X, 0, lookVector.Z))
		rootPart.CFrame = targetCFrame
	end

	-- AI State
	local target = workspace:WaitForChild("TK")
	local targetRootPart = target:WaitForChild("HumanoidRootPart")

	local currentState = "idle" -- idle, following, attacking
	local roarCooldown = 0

	-- Pathfinding
	function createPath()
		return PathfindingService:CreatePath({
			AgentRadius = 8,
			AgentHeight = 25,
			AgentCanJump = true,
			AgentCanClimb = false,
			WaypointSpacing = 6,
			Costs = {
				Water = math.huge,
			}
		})
	end

	function computePath(startPos, endPos)
		local path = createPath()
		local success, errorMsg = pcall(function()
			path:ComputeAsync(startPos, endPos)
		end)

		if success and path.Status == Enum.PathStatus.Success then
			return path
		else
			warn("Pathfinding failed:", errorMsg or path.Status)
			return nil
		end
	end

	-- AI Behaviors
	function dealDamage()
		local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
		if targetHumanoid then
			targetHumanoid:TakeDamage(math.random(
				ATTACK_DAMAGE_MIN,
				ATTACK_DAMAGE_MAX
				))
		end
	end

	function performAttack()
		if roarCooldown > 0 then return end

		currentState = "attacking"
		stopMovement()
		facePosition(targetRootPart.Position)

		-- Random attack choice
		local rand = math.random()

		if rand < 0.4 then
			-- Roar attack
			playAnimation("roar", 0.1)
			task.wait(0.5)
			dealDamage()
			task.wait(1)
		elseif rand < 0.7 then
			-- Atomic breath
			playAnimation("atomic breath", 0.1)
			task.wait(0.8)
			dealDamage()
			task.wait(1.5)
		else
			-- Nuclear pulse
			playAnimation("nuclear pulse", 0.1)
			task.wait(0.6)
			dealDamage()
			task.wait(1.2)
		end

		roarCooldown = ROAR_COOLDOWN_TIME
	end

	function followTarget()
		-- Continuously update path and follow
		task.spawn(function()
			while currentState == "following" do
				local path = computePath(rootPart.Position, targetRootPart.Position)

				if path then
					local waypoints = path:GetWaypoints()

					for i, waypoint in ipairs(waypoints) do
						if i == 1 then continue end -- Skip first waypoint
						if currentState ~= "following" then break end

						-- Check if in attack range
						local distanceToTarget = (rootPart.Position - targetRootPart.Position).Magnitude
						if distanceToTarget <= ATTACK_RANGE then
							return
						end

						-- Move to waypoint
						moveToPosition(waypoint.Position)
						facePosition(waypoint.Position)

						-- Wait to reach waypoint or timeout
						local startTime = tick()
						while (rootPart.Position - waypoint.Position).Magnitude > WAYPOINT_RADIUS do
							if currentState ~= "following" then break end
							if tick() - startTime > 5 then break end -- Timeout
							task.wait(0.05)
						end
					end
				else
					-- Direct movement if pathfinding fails
					moveToPosition(targetRootPart.Position)
					facePosition(targetRootPart.Position)
				end

				task.wait(PATH_UPDATE_INTERVAL)
			end
		end)
	end

	-- Main AI Loop
	task.spawn(function()
		playAnimation("idle")

		while task.wait(0.05) do
			-- Update cooldowns
			if roarCooldown > 0 then
				roarCooldown = math.max(0, roarCooldown - 0.05)
			end

			if not target or not targetRootPart then continue end

			local distance = (rootPart.Position - targetRootPart.Position).Magnitude

			-- Simple aggressive state machine
			if distance <= ATTACK_RANGE then
				-- ATTACK - Stop and attack
				if currentState ~= "attacking" then
					currentState = "attacking"
					stopMovement()
					task.spawn(function()
						performAttack()
						currentState = "idle"
					end)
				end

			elseif distance <= FOLLOW_RANGE then
				-- CHASE - Aggressively chase the player
				if currentState == "idle" then
					currentState = "following"
					playAnimation("run")
					followTarget()
				end

				-- Keep moving towards target even without pathfinding
				if currentState == "following" then
					local directPath = (targetRootPart.Position - rootPart.Position).Unit
					moveToPosition(rootPart.Position + directPath * 10)
					facePosition(targetRootPart.Position)
					playAnimation("run")
				end

			else
				-- IDLE - Too far away
				if currentState ~= "idle" and currentState ~= "attacking" then
					currentState = "idle"
					stopMovement()
					playAnimation("idle")
				end
			end
		end
	end)

end
