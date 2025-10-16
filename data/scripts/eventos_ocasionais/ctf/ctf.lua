-- CTF Event (converted from XML mod by Doggynub)
-- Faithful conversion to modern Lua syntax

--=============================
-- Config
--=============================
local STORAGE = {
	Owner = 1900,
	FLAG2_INn = 4000,
	FLAG_IN = 4001,
	TEAM1_FLAGS = 3030,
	TEAM2_FLAGS = 3031,
	Event_Start = 3032,
	Event_timeend = 3033,
	Event_Tile_Close = 3039,
	joined = 2023,
	Timer = 1010,
}

local POS = {
	BLUE_FLAG = Position(32243, 33079, 7),
	RED_FLAG = Position(32308, 33137, 7),
	Wait_Place = Position(32252, 33106, 7),
	frompos = Position(32217, 33058, 7),
	topos = Position(32352, 33195, 7),
	Red_Position = Position(32308, 33141, 7),
	Blue_Position = Position(32243, 33084, 7),
}

local SETTINGS = {
	Event_WaitTime = 5, -- minutes
	Event_MaxTime = 20, -- minutes
	Players_Speed = 500,
	Flag_Holder_Speed = 500,
	TEAM2_NAME = "Red",
	TEAM1_NAME = "Green",
	FLAG_SCORE = 2,
	Teleport_On_Score = true,
	Players_Least_Number = 2,
	Min_Join_Level = 100,
}

local REWARDS = {
	-- Format: { {itemId, minQuantity, maxQuantity}, ... }
	-- If minQuantity == maxQuantity, always gives that exact amount
	-- Roll chances: 10% for tier 10, 30% for tier 30, 60% for tier 60
	
	[60] = { -- 60% chance - Common rewards
		items = { 
			{3043, 50, 150},   -- crystal coin x50-150
			{3387, 1, 1},      -- demon helmet x1
			{3420, 1, 1},      -- demon shield x1
			{3366, 1, 1},      -- magic plate armor x1
			{3414, 1, 1},      -- mastermind shield x1
			{3364, 1, 1},      -- golden legs x1
			{3392, 1, 1},      -- royal helmet x1
			{3554, 1, 1},      -- steel boots x1
		} 
	},
	[30] = { -- 30% chance - Uncommon rewards
		items = { 
			{3043, 150, 300},  -- crystal coin x150-300
			{3360, 1, 1},      -- golden armor x1
			{3386, 1, 1},      -- dragon scale mail x1
			{3382, 1, 1},      -- crown legs x1
			{3381, 1, 1},      -- crown armor x1
			{3391, 1, 1},      -- crusader helmet x1
			{3385, 1, 1},      -- crown helmet x1
		} 
	},
	[10] = { -- 10% chance - Rare rewards
		items = { 
			{3043, 300, 700},  -- crystal coin x300-700
			{3423, 1, 2},      -- blessed shield x1-2
			{3419, 1, 2},      -- crown shield x1-2
			{3357, 1, 1},      -- plate armor x1
			{3370, 1, 1},      -- knight armor x1
			{3428, 1, 1},      -- tower shield x1
		} 
	},
}

local corpse_ids = {
	[0] = 4248, -- female
	[1] = 4240  -- male
}

--=============================
-- Global storage helpers
--=============================
local function gget(key)
	return Game.getStorageValue(key)
end

local function gset(key, value)
	return Game.setStorageValue(key, value)
end

--=============================
-- Helper functions
--=============================
local function isTeamTwo(player)
	return player and player:getStorageValue(5054) > -1
end

local function isTeamOne(player)
	return player and player:getStorageValue(5055) > -1
end

local function resetTheTeams(player)
	if not player then return false end
	player:setStorageValue(5054, -1)
	player:setStorageValue(5055, -1)
	return true
end

local function setflagOwner(player)
	return player:setStorageValue(STORAGE.Owner, 1)
end

local function flagOwner(player)
	return player and player:getStorageValue(STORAGE.Owner) > 0
end

local function releaseBF(player)
	gset(STORAGE.FLAG_IN, -1)
	player:setStorageValue(103, 0)
	player:setStorageValue(STORAGE.Owner, -1)
	return true
end

local function releaseRF(player)
	gset(STORAGE.FLAG2_INn, -1)
	player:setStorageValue(103, 0)
	player:setStorageValue(STORAGE.Owner, -1)
	return true
end

local function setFirstTeam(player)
	player:setStorageValue(5055, 1)
end

local function setSecondTeam(player)
	player:setStorageValue(5054, 2)
end

local function addToRed()
	return gset(STORAGE.TEAM2_FLAGS, gget(STORAGE.TEAM2_FLAGS) + 1)
end

local function addToBlue()
	return gset(STORAGE.TEAM1_FLAGS, gget(STORAGE.TEAM1_FLAGS) + 1)
end

local function getBlueScore()
	return gget(STORAGE.TEAM1_FLAGS)
end

local function getRedScore()
	return gget(STORAGE.TEAM2_FLAGS)
end

local function getTheSpeed(level)
	return 220 + (2 * (level - 1))
end

local function resetTheStorage()
	gset(STORAGE.Event_Start, -1)
	gset(STORAGE.Event_timeend, -1)
	gset(STORAGE.TEAM1_FLAGS, 0)
	gset(STORAGE.FLAG2_INn, -1)
	gset(STORAGE.FLAG_IN, -1)
	gset(STORAGE.TEAM2_FLAGS, 0)
	return true
end

local function blueStolen()
	return gget(STORAGE.FLAG_IN)
end

local function redStolen()
	return gget(STORAGE.FLAG2_INn)
end

local function giveReward(player)
	local t = math.random(1, 100)
	local roll
	if t <= 10 then
		roll = 10
	elseif t <= 40 then
		roll = 30
	else
		roll = 60
	end
	
	local pool = REWARDS[roll].items
	local rewardData = pool[math.random(1, #pool)]
	local itemId = rewardData[1]
	local minQty = rewardData[2]
	local maxQty = rewardData[3]
	
	-- Roll random quantity between min and max
	local quantity = math.random(minQty, maxQty)
	
	player:addItem(itemId, quantity)
	
	if quantity > 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Reward: you won %dx %s.", quantity, ItemType(itemId):getName()))
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Reward: you won %s.", ItemType(itemId):getName()))
	end
end

local function applyFixedSpeed(player, targetSpeed)
	local currentSpeed = player:getSpeed()
	local delta = targetSpeed - currentSpeed
	if delta ~= 0 then
		player:changeSpeed(delta)
	end
end

local function resetSpeed(player)
	-- Remove all speed conditions first
	player:removeCondition(CONDITION_HASTE)
	player:removeCondition(CONDITION_PARALYZE)
	
	-- Reset to base speed by reversing any changeSpeed
	local currentSpeed = player:getSpeed()
	local baseSpeed = player:getBaseSpeed()
	local delta = baseSpeed - currentSpeed
	if delta ~= 0 then
		player:changeSpeed(delta)
	end
end

--=============================
-- CreatureEvents
--=============================
local ctfLogin = CreatureEvent("CTFLogin")
function ctfLogin.onLogin(player)
	if gget(STORAGE.Event_Start) < 1 then
		if isTeamOne(player) or isTeamTwo(player) then
			resetTheTeams(player)
		end
	end
	player:registerEvent("CTFPrepareDeath")
	return true
end
ctfLogin:register()

local ctfPrepareDeath = CreatureEvent("CTFPrepareDeath")
function ctfPrepareDeath.onPrepareDeath(player, killer)
	if gget(STORAGE.Event_Start) <= 0 then
		return true
	end
	
	if not (isTeamOne(player) or isTeamTwo(player)) then
		return true
	end
	
	-- Save info
	local corpseId = corpse_ids[player:getSex()]
	local currentPos = player:getPosition()
	local attackerName = killer and killer:isPlayer() and killer:getName() or (killer and killer:isMonster() and "a " .. killer:getName():lower() or "a field item")
	local hasFlag = flagOwner(player)
	local teamOne = isTeamOne(player)
	local teamTwo = isTeamTwo(player)
	
	-- Create corpse first
	local corpse = Game.createItem(corpseId, 1, currentPos)
	if corpse then
		if hasFlag then
			corpse:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, string.format("You recognize %s. He was killed by %s [Flag Holder].", player:getName(), attackerName))
		else
			corpse:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, string.format("You recognize %s. He was killed by %s [Normal kill].", player:getName(), attackerName))
		end
	end
	
	-- Schedule respawn (needs delay to work properly)
	addEvent(function()
		if not player then return end
		
		-- Restore health/mana
		player:addHealth(player:getMaxHealth())
		player:addMana(player:getMaxMana())
		
		-- Teleport
		if hasFlag then
			if teamOne then
				player:teleportTo(POS.Blue_Position, false)
				POS.Blue_Position:sendMagicEffect(CONST_ME_MAGIC_BLUE)
				releaseRF(player)
				for _, p in ipairs(Game.getPlayers()) do
					if isTeamOne(p) or isTeamTwo(p) then
						p:sendTextMessage(MESSAGE_EVENT_ADVANCE, player:getName() .. " has died with the " .. SETTINGS.TEAM2_NAME .. " team flag. The flag is returned back to the " .. SETTINGS.TEAM2_NAME .. " team.")
					end
				end
			elseif teamTwo then
				player:teleportTo(POS.Red_Position, false)
				POS.Red_Position:sendMagicEffect(CONST_ME_MAGIC_RED)
				releaseBF(player)
				for _, p in ipairs(Game.getPlayers()) do
					if isTeamOne(p) or isTeamTwo(p) then
						p:sendTextMessage(MESSAGE_EVENT_ADVANCE, player:getName() .. " has died with the " .. SETTINGS.TEAM1_NAME .. " team flag. The flag is returned back to the " .. SETTINGS.TEAM1_NAME .. " team.")
					end
				end
			end
		else
			local pos = teamTwo and POS.Red_Position or POS.Blue_Position
			player:teleportTo(pos, false)
			pos:sendMagicEffect(CONST_ME_TELEPORT)
		end
	end, 1000)
	
	-- Prevent death
	return false
end
ctfPrepareDeath:register()

-- EventCallback for combat and damage
local ctfCallback = EventCallback
ctfCallback.onTargetCombat = function(creature, target)
	local player = creature:getPlayer()
	local targetPlayer = target:getPlayer()
	if not player or not targetPlayer then
		return RETURNVALUE_NOERROR
	end

	if isTeamOne(player) and isTeamOne(targetPlayer) then
		return RETURNVALUE_YOUCANNOTATTACKTHISPLAYER
	end
	if isTeamTwo(player) and isTeamTwo(targetPlayer) then
		return RETURNVALUE_YOUCANNOTATTACKTHISPLAYER
	end
	return RETURNVALUE_NOERROR
end

-- Removed onHealthChange - using onPrepareDeath instead for better death handling
ctfCallback:register()

--=============================
-- MoveEvents (Flags)
--=============================

-- RED FLAG (AID 6000)
local redFlagStep = MoveEvent()
function redFlagStep.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then return true end
	if gget(STORAGE.Event_Start) <= 0 or gget(STORAGE.Event_timeend) <= 0 then return true end

	-- Red team capturing blue flag (CHECK THIS FIRST!)
	if isTeamTwo(player) and flagOwner(player) and blueStolen() > 0 and redStolen() < 0 then
		if getRedScore() == SETTINGS.FLAG_SCORE - 1 then
			-- Game over - Red wins
			addToRed()
			releaseBF(player)
			player:teleportTo(fromPosition, true)
			applyFixedSpeed(player, getTheSpeed(SETTINGS.Players_Speed))
			for _, p in ipairs(Game.getPlayers()) do
				if isTeamOne(p) or isTeamTwo(p) then
					p:sendTextMessage(MESSAGE_EVENT_ADVANCE, player:getName() .. " have captured the last flag and earned match win to the " .. SETTINGS.TEAM2_NAME .. " team!")
				end
			end
			addEvent(function()
				Game.broadcastMessage('CTF-Event : The ' .. SETTINGS.TEAM2_NAME .. ' team won and reciaved their reward.')
				for _, p in ipairs(Game.getPlayers()) do
					if isTeamTwo(p) then
						p:teleportTo(p:getTown():getTemplePosition(), false)
						p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
						p:removeCondition(CONDITION_OUTFIT)
						p:removeCondition(CONDITION_INFIGHT)
					resetTheTeams(p)
					resetSpeed(p)
						giveReward(p)
					elseif isTeamOne(p) then
						p:teleportTo(p:getTown():getTemplePosition(), false)
						p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
						p:removeCondition(CONDITION_OUTFIT)
						p:removeCondition(CONDITION_INFIGHT)
						p:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'Your team have lost.')
					resetTheTeams(p)
					resetSpeed(p)
					end
				end
				resetTheStorage()
			end, 1000)
		else
			-- Score point
			releaseBF(player)
			addToRed()
			player:teleportTo(fromPosition, true)
			applyFixedSpeed(player, getTheSpeed(SETTINGS.Players_Speed))
			for _, p in ipairs(Game.getPlayers()) do
				if isTeamOne(p) or isTeamTwo(p) then
					p:sendTextMessage(MESSAGE_EVENT_ADVANCE, player:getName() .. " have captured the flag and earned 1 point to the " .. SETTINGS.TEAM2_NAME .. " team!")
					if SETTINGS.Teleport_On_Score then
						p:teleportTo(isTeamTwo(p) and POS.Red_Position or POS.Blue_Position, false)
						p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
					end
				end
			end
		end
		return true
	end

	-- Red team stepping on their own flag (prevent taking own flag)
	if isTeamTwo(player) and redStolen() < 0 then
		if not flagOwner(player) then
			player:teleportTo(fromPosition, true)
			position:sendMagicEffect(CONST_ME_BLOCKHIT)
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This is your team flag, you cant take it!")
		end
		return true
	elseif isTeamTwo(player) and redStolen() > 0 and blueStolen() < 0 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your team's Flag has been stolen, go get it back!")
		player:teleportTo(fromPosition, true)
		position:sendMagicEffect(CONST_ME_BLOCKHIT)
		return true
	end

	-- Blue team stealing red flag
	if isTeamOne(player) then
		if blueStolen() < 0 and redStolen() > 0 then
			if flagOwner(player) then
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already holding the flag!")
				player:teleportTo(fromPosition, true)
				position:sendMagicEffect(CONST_ME_BLOCKHIT)
			elseif not flagOwner(player) then
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your Team mates already stole the oponent flag, defend him!")
				player:teleportTo(fromPosition, true)
				position:sendMagicEffect(CONST_ME_BLOCKHIT)
			end
		elseif blueStolen() > 0 and redStolen() < 0 then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your team's flag is taken you can't capture or steel a flag!")
			player:teleportTo(fromPosition, true)
			position:sendMagicEffect(CONST_ME_BLOCKHIT)
		end

		if redStolen() < 0 and blueStolen() < 0 then
			gset(STORAGE.FLAG2_INn, 1)
			setflagOwner(player)
			player:setStorageValue(103, os.time() + 300)
			player:teleportTo(fromPosition, true)
			applyFixedSpeed(player, getTheSpeed(SETTINGS.Flag_Holder_Speed))
			for _, p in ipairs(Game.getPlayers()) do
				if isTeamOne(p) or isTeamTwo(p) then
					p:sendTextMessage(MESSAGE_EVENT_ADVANCE, player:getName() .. " stolen the " .. SETTINGS.TEAM2_NAME .. " team flag!")
				end
			end
		end
	end
	return true
end
redFlagStep:aid(6000)
redFlagStep:type("stepin")
redFlagStep:register()

-- BLUE FLAG (AID 6001)
local blueFlagStep = MoveEvent()
function blueFlagStep.onStepIn(creature, item, position, fromPosition)
	local player = creature:getPlayer()
	if not player then return true end
	if gget(STORAGE.Event_Start) <= 0 or gget(STORAGE.Event_timeend) <= 0 then return true end

	-- Blue team capturing red flag (CHECK THIS FIRST!)
	if isTeamOne(player) and flagOwner(player) and redStolen() > 0 and blueStolen() < 0 then
		if getBlueScore() == SETTINGS.FLAG_SCORE - 1 then
			-- Game over - Blue wins
			addToBlue()
			releaseRF(player)
			player:teleportTo(fromPosition, true)
			applyFixedSpeed(player, getTheSpeed(SETTINGS.Players_Speed))
			for _, p in ipairs(Game.getPlayers()) do
				if isTeamOne(p) or isTeamTwo(p) then
					p:sendTextMessage(MESSAGE_EVENT_ADVANCE, player:getName() .. " have captured the last flag and earned match win to the " .. SETTINGS.TEAM1_NAME .. " team!")
				end
			end
			addEvent(function()
				Game.broadcastMessage('CTF-Event : The ' .. SETTINGS.TEAM1_NAME .. ' team won and reciaved their reward.')
				for _, p in ipairs(Game.getPlayers()) do
					if isTeamOne(p) then
						p:teleportTo(p:getTown():getTemplePosition(), false)
						p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
						p:removeCondition(CONDITION_OUTFIT)
						p:removeCondition(CONDITION_INFIGHT)
					resetTheTeams(p)
					resetSpeed(p)
						giveReward(p)
					elseif isTeamTwo(p) then
						p:teleportTo(p:getTown():getTemplePosition(), false)
						p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
						p:removeCondition(CONDITION_OUTFIT)
						p:removeCondition(CONDITION_INFIGHT)
						p:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'Your team have lost.')
					resetTheTeams(p)
					resetSpeed(p)
					end
				end
				resetTheStorage()
			end, 1000)
		else
			-- Score point
			releaseRF(player)
			addToBlue()
			player:teleportTo(fromPosition, true)
			applyFixedSpeed(player, getTheSpeed(SETTINGS.Players_Speed))
			for _, p in ipairs(Game.getPlayers()) do
				if isTeamOne(p) or isTeamTwo(p) then
					p:sendTextMessage(MESSAGE_EVENT_ADVANCE, player:getName() .. " have captured the flag and earned 1 point to the " .. SETTINGS.TEAM1_NAME .. " team!")
					if SETTINGS.Teleport_On_Score then
						p:teleportTo(isTeamTwo(p) and POS.Red_Position or POS.Blue_Position, false)
						p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
					end
				end
			end
		end
		return true
	end

	-- Blue team stepping on their own flag (prevent taking own flag)
	if isTeamOne(player) and blueStolen() < 0 then
		if not flagOwner(player) then
			player:teleportTo(fromPosition, true)
			position:sendMagicEffect(CONST_ME_BLOCKHIT)
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This is your team flag, you cant take it!")
		end
		return true
	elseif isTeamOne(player) and blueStolen() > 0 and redStolen() < 0 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your team's Flag has been stolen, go get it back!")
		player:teleportTo(fromPosition, true)
		position:sendMagicEffect(CONST_ME_BLOCKHIT)
		return true
	end

	-- Red team stealing blue flag
	if isTeamTwo(player) then
		if blueStolen() > 0 and redStolen() < 0 then
			if flagOwner(player) then
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You already holding the flag!")
				player:teleportTo(fromPosition, true)
				position:sendMagicEffect(CONST_ME_BLOCKHIT)
			elseif not flagOwner(player) then
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your Team mates already stole the oponent flag, defend him!")
				player:teleportTo(fromPosition, true)
				position:sendMagicEffect(CONST_ME_BLOCKHIT)
			end
		elseif redStolen() > 0 and blueStolen() < 0 then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your team's flag is taken you can't capture or steel a flag!")
			player:teleportTo(fromPosition, true)
			position:sendMagicEffect(CONST_ME_BLOCKHIT)
		end

		if blueStolen() < 0 and redStolen() < 0 then
			gset(STORAGE.FLAG_IN, 1)
			setflagOwner(player)
			player:setStorageValue(103, os.time() + 300)
			player:teleportTo(fromPosition, true)
			applyFixedSpeed(player, getTheSpeed(SETTINGS.Flag_Holder_Speed))
			for _, p in ipairs(Game.getPlayers()) do
				if isTeamOne(p) or isTeamTwo(p) then
					p:sendTextMessage(MESSAGE_EVENT_ADVANCE, player:getName() .. " stolen the " .. SETTINGS.TEAM1_NAME .. " team flag!")
				end
			end
		end
	end
	return true
end
blueFlagStep:aid(6001)
blueFlagStep:type("stepin")
blueFlagStep:register()

--=============================
-- GlobalEvents
--=============================

-- Event Start Time
local ctfOnTime = GlobalEvent("CTF.OnTime")
function ctfOnTime.onTime(interval)
	if gget(STORAGE.Event_Start) >= 0 then
		return true
	end

	gset(STORAGE.Event_Start, 1)
	gset(STORAGE.Event_Tile_Close, 1)
	Game.broadcastMessage("CTF event is opened! Use '!ctf join' to participate. It will start in " .. SETTINGS.Event_WaitTime .. " minutes.")

	-- Countdown messages
	for i = 1, SETTINGS.Event_WaitTime - 1 do
		addEvent(function()
			Game.broadcastMessage("CTF event is open! Use '!ctf join'. It will start in " .. (SETTINGS.Event_WaitTime - i) .. " minutes.")
		end, i * 60 * 1000)
	end

	-- Start event after wait time
	addEvent(function()
		-- Collect all players in waiting room
		local players = {}
		for x = POS.frompos.x, POS.topos.x do
			for y = POS.frompos.y, POS.topos.y do
				local tile = Tile(Position(x, y, POS.frompos.z))
				if tile then
					local creatures = tile:getCreatures()
					if creatures then
						for _, creature in ipairs(creatures) do
							local p = creature:getPlayer()
							if p then
								table.insert(players, p)
							end
						end
					end
				end
			end
		end

		-- Balance teams
		if #players % 2 ~= 0 then
			local removed = table.remove(players)
			if removed then
				removed:teleportTo(removed:getTown():getTemplePosition(), false)
				removed:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
				removed:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Sorry, you have been kicked from event to balance teams.")
			end
		end

		-- Check minimum players
		if #players < SETTINGS.Players_Least_Number then
			Game.broadcastMessage("CTF event was cancelled because less than " .. SETTINGS.Players_Least_Number .. " players joined. [joined : " .. #players .. " players]")
			resetTheStorage()
			for _, p in ipairs(players) do
				p:teleportTo(p:getTown():getTemplePosition(), false)
				p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
			end
			return
		end

		-- Create teams
		local half = math.floor(#players / 2)
		for i = 1, half do
			setFirstTeam(players[i])
		end
		for i = half + 1, #players do
			setSecondTeam(players[i])
		end

		-- Create outfits
		local bmale = Condition(CONDITION_OUTFIT)
		bmale:setTicks(-1)
		bmale:setOutfit({lookType = math.random(128, 134), lookHead = 115, lookBody = 114, lookLegs = 81, lookFeet = 81, lookAddons = 3})

		local bfemale = Condition(CONDITION_OUTFIT)
		bfemale:setTicks(-1)
		bfemale:setOutfit({lookType = math.random(136, 142), lookHead = 115, lookBody = 114, lookLegs = 81, lookFeet = 81, lookAddons = 3})

		local rmale = Condition(CONDITION_OUTFIT)
		rmale:setTicks(-1)
		rmale:setOutfit({lookType = math.random(128, 134), lookHead = 94, lookBody = 94, lookLegs = 94, lookFeet = 94, lookAddons = 3})

		local rfemale = Condition(CONDITION_OUTFIT)
		rfemale:setTicks(-1)
		rfemale:setOutfit({lookType = math.random(136, 142), lookHead = 94, lookBody = 94, lookLegs = 94, lookFeet = 94, lookAddons = 3})

		local fight = Condition(CONDITION_INFIGHT)
		fight:setTicks(-1)

		-- Teleport and setup teams
		for _, p in ipairs(Game.getPlayers()) do
			if isTeamOne(p) then
				if p:getSex() == PLAYERSEX_MALE then
					p:addCondition(bmale)
				else
					p:addCondition(bfemale)
				end
				p:addCondition(fight)
				p:teleportTo(POS.Blue_Position, false)
				POS.Blue_Position:sendMagicEffect(CONST_ME_TELEPORT)
				applyFixedSpeed(p, getTheSpeed(SETTINGS.Players_Speed))
			elseif isTeamTwo(p) then
				if p:getSex() == PLAYERSEX_MALE then
					p:addCondition(rmale)
				else
					p:addCondition(rfemale)
				end
				p:addCondition(fight)
				p:teleportTo(POS.Red_Position, false)
				POS.Red_Position:sendMagicEffect(CONST_ME_TELEPORT)
				applyFixedSpeed(p, getTheSpeed(SETTINGS.Players_Speed))
			end
		end

		-- Start event
		gset(STORAGE.Event_Tile_Close, -1)
		gset(STORAGE.Event_timeend, 1)
		gset(STORAGE.Timer, os.time() + SETTINGS.Event_MaxTime * 60)
		Game.broadcastMessage("CTF started!")

		-- Schedule event end
		addEvent(function()
			if gget(STORAGE.Event_Start) > 0 and gget(STORAGE.Event_timeend) > 0 then
				local redScore = getRedScore()
				local blueScore = getBlueScore()

				if redScore > blueScore then
					Game.broadcastMessage('CTF-Event : The ' .. SETTINGS.TEAM2_NAME .. ' team won and recieved their reward.')
					for _, p in ipairs(Game.getPlayers()) do
						if isTeamTwo(p) then
							p:teleportTo(p:getTown():getTemplePosition(), false)
							p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
							p:removeCondition(CONDITION_OUTFIT)
							p:removeCondition(CONDITION_INFIGHT)
					resetTheTeams(p)
					resetSpeed(p)
							giveReward(p)
						elseif isTeamOne(p) then
							p:teleportTo(p:getTown():getTemplePosition(), false)
							p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
							p:removeCondition(CONDITION_OUTFIT)
							p:removeCondition(CONDITION_INFIGHT)
							p:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'Your team have lost.')
					resetTheTeams(p)
					resetSpeed(p)
						end
					end
				elseif redScore < blueScore then
					Game.broadcastMessage('CTF-Event : The ' .. SETTINGS.TEAM1_NAME .. ' team won and recieved their reward.')
					for _, p in ipairs(Game.getPlayers()) do
						if isTeamOne(p) then
							p:teleportTo(p:getTown():getTemplePosition(), false)
							p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
							p:removeCondition(CONDITION_OUTFIT)
							p:removeCondition(CONDITION_INFIGHT)
					resetTheTeams(p)
					resetSpeed(p)
							giveReward(p)
						elseif isTeamTwo(p) then
							p:teleportTo(p:getTown():getTemplePosition(), false)
							p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
							p:removeCondition(CONDITION_OUTFIT)
							p:removeCondition(CONDITION_INFIGHT)
							p:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'Your team have lost.')
					resetTheTeams(p)
					resetSpeed(p)
						end
					end
				else
					Game.broadcastMessage('CTF-Event : The Event ended with a draw between both teams.')
					for _, p in ipairs(Game.getPlayers()) do
						if isTeamTwo(p) or isTeamOne(p) then
							p:teleportTo(p:getTown():getTemplePosition(), false)
							p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
							p:removeCondition(CONDITION_OUTFIT)
							p:removeCondition(CONDITION_INFIGHT)
							p:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'It was a draw between both teams.')
					resetTheTeams(p)
					resetSpeed(p)
						end
					end
				end
				resetTheStorage()
			end
		end, SETTINGS.Event_MaxTime * 60 * 1000)
	end, SETTINGS.Event_WaitTime * 60 * 1000)

	return true
end
ctfOnTime:time("22:19:00")
ctfOnTime:register()

-- Flag effects and timer
local ctfTick = GlobalEvent("CTF.Tick")
function ctfTick.onThink(interval)
	if gget(STORAGE.Event_Start) > 0 and gget(STORAGE.Event_timeend) > 0 then
		if redStolen() < 0 then
			POS.RED_FLAG:sendMagicEffect(CONST_ME_SOUND_RED)
		end
		if blueStolen() < 0 then
			POS.BLUE_FLAG:sendMagicEffect(CONST_ME_SOUND_GREEN)
		end

		for _, p in ipairs(Game.getPlayers()) do
			if isTeamOne(p) or isTeamTwo(p) then
				if p:hasCondition(CONDITION_HASTE) then
					p:removeCondition(CONDITION_HASTE)
				end
			end

			if flagOwner(p) then
				if isTeamTwo(p) then
					if p:getStorageValue(103) < os.time() then
						releaseBF(p)
						Game.broadcastMessage(p:getName() .. " wasted 5 minutes with FLAG. " .. SETTINGS.TEAM2_NAME .. " flag is again on spawn!")
					else
						p:getPosition():sendMagicEffect(CONST_ME_SOUND_GREEN)
					end
				elseif isTeamOne(p) then
					if p:getStorageValue(103) < os.time() then
						releaseRF(p)
						Game.broadcastMessage(p:getName() .. " wasted 5 minutes with FLAG. " .. SETTINGS.TEAM1_NAME .. " flag is again on spawn!")
					else
						p:getPosition():sendMagicEffect(CONST_ME_SOUND_RED)
					end
				end
			end
		end
	end
	return true
end
ctfTick:interval(500)
ctfTick:register()

-- Timer display
local ctfTimer = GlobalEvent("CTF.Timer")
function ctfTimer.onThink(interval)
	for _, p in ipairs(Game.getPlayers()) do
		if isTeamOne(p) or isTeamTwo(p) then
			if gget(STORAGE.Event_Start) > 0 and gget(STORAGE.Event_timeend) > 0 then
				local left = gget(STORAGE.Timer) - os.time()
				if left >= 0 then
					p:sendCancelMessage(string.format("Time -> %s  |  %s Score : %d/%d captures  |  %s Score : %d/%d captures",
						os.date("%M:%S", left), SETTINGS.TEAM1_NAME, getBlueScore(), SETTINGS.FLAG_SCORE, SETTINGS.TEAM2_NAME, getRedScore(), SETTINGS.FLAG_SCORE))
				end
			end
		end
	end
	return true
end
ctfTimer:interval(400)
ctfTimer:register()

-- Startup
local ctfStartup = GlobalEvent("CTF.Startup")
function ctfStartup.onStartup()
	resetTheStorage()
	return true
end
ctfStartup:type("startup")
ctfStartup:register()

--=============================
-- Talkactions
--=============================

-- Unified CTF TalkAction
-- GM Commands: /ctfe
local ctfGodTalk = TalkAction("/ctfe")
function ctfGodTalk.onSay(player, words, param)
	param = (param or ""):lower():trim()
	
	if param == "open" then
		if gget(STORAGE.Event_Start) > 0 then
			player:sendCancelMessage("Event is already open or running!")
			return true
		end
		
		resetTheStorage()
		gset(STORAGE.Event_Start, 1)
		gset(STORAGE.Event_Tile_Close, 1)
		
		Game.broadcastMessage("CTF event has been opened! Use '!ctf join' to participate. Event starts in " .. SETTINGS.Event_WaitTime .. " minutes.")
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF event opened successfully! Event will auto-start in " .. SETTINGS.Event_WaitTime .. " minutes, or use '/ctfe start' to begin immediately.")
		
		-- Countdown messages
		for i = 1, SETTINGS.Event_WaitTime - 1 do
			addEvent(function()
				if gget(STORAGE.Event_Start) > 0 and gget(STORAGE.Event_timeend) < 1 then
					Game.broadcastMessage("CTF event starting in " .. (SETTINGS.Event_WaitTime - i) .. " minutes! Use '!ctf join' to participate.")
				end
			end, i * 60 * 1000)
		end
		
		-- Auto-start after wait time
		addEvent(function()
			-- Only start if event is still open and hasn't been manually started
			if gget(STORAGE.Event_Start) > 0 and gget(STORAGE.Event_timeend) < 1 then
				-- Use the same start logic
				local players = {}
				for x = POS.frompos.x, POS.topos.x do
					for y = POS.frompos.y, POS.topos.y do
						local tile = Tile(Position(x, y, POS.frompos.z))
						if tile then
							local creatures = tile:getCreatures()
							if creatures then
								for _, creature in ipairs(creatures) do
									local p = creature:getPlayer()
									-- Exclude GMs from being added to event
									if p and p:getGroup():getId() < GROUP_TYPE_GAMEMASTER then
										table.insert(players, p)
									end
								end
							end
						end
					end
				end

				if #players % 2 ~= 0 then
					local removed = table.remove(players)
					if removed then
						removed:teleportTo(removed:getTown():getTemplePosition(), false)
						removed:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
						removed:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Sorry, you have been kicked from event to balance teams.")
					end
				end

				if #players < SETTINGS.Players_Least_Number then
					Game.broadcastMessage("CTF event was cancelled because less than " .. SETTINGS.Players_Least_Number .. " players joined. [joined : " .. #players .. " players]")
					resetTheStorage()
					for _, p in ipairs(players) do
						p:teleportTo(p:getTown():getTemplePosition(), false)
						p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
					end
					return
				end

				-- Start event (same logic as manual start)
				local half = math.floor(#players / 2)
				for i = 1, half do
					setFirstTeam(players[i])
					players[i]:setStorageValue(STORAGE.joined, -1)
				end
				for i = half + 1, #players do
					setSecondTeam(players[i])
					players[i]:setStorageValue(STORAGE.joined, -1)
				end

				local bmale = Condition(CONDITION_OUTFIT)
				bmale:setTicks(-1)
				bmale:setOutfit({lookType = math.random(128, 134), lookHead = 115, lookBody = 114, lookLegs = 81, lookFeet = 81, lookAddons = 3})

				local bfemale = Condition(CONDITION_OUTFIT)
				bfemale:setTicks(-1)
				bfemale:setOutfit({lookType = math.random(136, 142), lookHead = 115, lookBody = 114, lookLegs = 81, lookFeet = 81, lookAddons = 3})

				local rmale = Condition(CONDITION_OUTFIT)
				rmale:setTicks(-1)
				rmale:setOutfit({lookType = math.random(128, 134), lookHead = 94, lookBody = 94, lookLegs = 94, lookFeet = 94, lookAddons = 3})

				local rfemale = Condition(CONDITION_OUTFIT)
				rfemale:setTicks(-1)
				rfemale:setOutfit({lookType = math.random(136, 142), lookHead = 94, lookBody = 94, lookLegs = 94, lookFeet = 94, lookAddons = 3})

				local fight = Condition(CONDITION_INFIGHT)
				fight:setTicks(-1)

				for _, p in ipairs(Game.getPlayers()) do
					if isTeamOne(p) then
						if p:getSex() == PLAYERSEX_MALE then
							p:addCondition(bmale)
						else
							p:addCondition(bfemale)
						end
						p:addCondition(fight)
						p:teleportTo(POS.Blue_Position, false)
						POS.Blue_Position:sendMagicEffect(CONST_ME_TELEPORT)
						applyFixedSpeed(p, getTheSpeed(SETTINGS.Players_Speed))
					elseif isTeamTwo(p) then
						if p:getSex() == PLAYERSEX_MALE then
							p:addCondition(rmale)
						else
							p:addCondition(rfemale)
						end
						p:addCondition(fight)
						p:teleportTo(POS.Red_Position, false)
						POS.Red_Position:sendMagicEffect(CONST_ME_TELEPORT)
						applyFixedSpeed(p, getTheSpeed(SETTINGS.Players_Speed))
					end
				end

				gset(STORAGE.Event_Tile_Close, -1)
				gset(STORAGE.Event_timeend, 1)
				gset(STORAGE.Timer, os.time() + SETTINGS.Event_MaxTime * 60)
				Game.broadcastMessage("CTF started! First team to capture " .. SETTINGS.FLAG_SCORE .. " flags wins!")

				-- Schedule event end
				addEvent(function()
					if gget(STORAGE.Event_Start) > 0 and gget(STORAGE.Event_timeend) > 0 then
						local redScore = getRedScore()
						local blueScore = getBlueScore()

						if redScore > blueScore then
							Game.broadcastMessage('CTF-Event : The ' .. SETTINGS.TEAM2_NAME .. ' team won and recieved their reward.')
							for _, p in ipairs(Game.getPlayers()) do
								if isTeamTwo(p) then
									p:teleportTo(p:getTown():getTemplePosition(), false)
									p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
									p:removeCondition(CONDITION_OUTFIT)
									p:removeCondition(CONDITION_INFIGHT)
					resetTheTeams(p)
					resetSpeed(p)
									giveReward(p)
								elseif isTeamOne(p) then
									p:teleportTo(p:getTown():getTemplePosition(), false)
									p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
									p:removeCondition(CONDITION_OUTFIT)
									p:removeCondition(CONDITION_INFIGHT)
									p:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'Your team have lost.')
					resetTheTeams(p)
					resetSpeed(p)
								end
							end
						elseif redScore < blueScore then
							Game.broadcastMessage('CTF-Event : The ' .. SETTINGS.TEAM1_NAME .. ' team won and recieved their reward.')
							for _, p in ipairs(Game.getPlayers()) do
								if isTeamOne(p) then
									p:teleportTo(p:getTown():getTemplePosition(), false)
									p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
									p:removeCondition(CONDITION_OUTFIT)
									p:removeCondition(CONDITION_INFIGHT)
					resetTheTeams(p)
					resetSpeed(p)
									giveReward(p)
								elseif isTeamTwo(p) then
									p:teleportTo(p:getTown():getTemplePosition(), false)
									p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
									p:removeCondition(CONDITION_OUTFIT)
									p:removeCondition(CONDITION_INFIGHT)
									p:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'Your team have lost.')
					resetTheTeams(p)
					resetSpeed(p)
								end
							end
						else
							Game.broadcastMessage('CTF-Event : The Event ended with a draw between both teams.')
							for _, p in ipairs(Game.getPlayers()) do
								if isTeamTwo(p) or isTeamOne(p) then
									p:teleportTo(p:getTown():getTemplePosition(), false)
									p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
									p:removeCondition(CONDITION_OUTFIT)
									p:removeCondition(CONDITION_INFIGHT)
									p:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'It was a draw between both teams.')
					resetTheTeams(p)
					resetSpeed(p)
								end
							end
						end
						resetTheStorage()
					end
				end, SETTINGS.Event_MaxTime * 60 * 1000)
			end
		end, SETTINGS.Event_WaitTime * 60 * 1000)
		
		return true
		
	elseif param == "start" then
		if gget(STORAGE.Event_Start) < 0 then
			player:sendCancelMessage("Event is not open! Use /ctfe open first.")
			return true
		end
		if gget(STORAGE.Event_timeend) > 0 then
			player:sendCancelMessage("Event has already started!")
			return true
		end
		
		-- Collect all players in waiting room
		local players = {}
		for x = POS.frompos.x, POS.topos.x do
			for y = POS.frompos.y, POS.topos.y do
				local tile = Tile(Position(x, y, POS.frompos.z))
				if tile then
					local creatures = tile:getCreatures()
					if creatures then
						for _, creature in ipairs(creatures) do
							local p = creature:getPlayer()
							-- Exclude GMs from being added to event
							if p and p:getGroup():getId() < GROUP_TYPE_GAMEMASTER then
								table.insert(players, p)
							end
						end
					end
				end
			end
		end

		-- Balance teams
		if #players % 2 ~= 0 then
			local removed = table.remove(players)
			if removed then
				removed:teleportTo(removed:getTown():getTemplePosition(), false)
				removed:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
				removed:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Sorry, you have been kicked from event to balance teams.")
			end
		end

		-- Check minimum players
		if #players < SETTINGS.Players_Least_Number then
			Game.broadcastMessage("CTF event was cancelled because less than " .. SETTINGS.Players_Least_Number .. " players joined. [joined : " .. #players .. " players]")
			resetTheStorage()
			for _, p in ipairs(players) do
				p:teleportTo(p:getTown():getTemplePosition(), false)
				p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
			end
			return true
		end

		-- Create teams
		local half = math.floor(#players / 2)
		for i = 1, half do
			setFirstTeam(players[i])
			players[i]:setStorageValue(STORAGE.joined, -1)
		end
		for i = half + 1, #players do
			setSecondTeam(players[i])
			players[i]:setStorageValue(STORAGE.joined, -1)
		end

		-- Create outfits
		local bmale = Condition(CONDITION_OUTFIT)
		bmale:setTicks(-1)
		bmale:setOutfit({lookType = math.random(128, 134), lookHead = 115, lookBody = 114, lookLegs = 81, lookFeet = 81, lookAddons = 3})

		local bfemale = Condition(CONDITION_OUTFIT)
		bfemale:setTicks(-1)
		bfemale:setOutfit({lookType = math.random(136, 142), lookHead = 115, lookBody = 114, lookLegs = 81, lookFeet = 81, lookAddons = 3})

		local rmale = Condition(CONDITION_OUTFIT)
		rmale:setTicks(-1)
		rmale:setOutfit({lookType = math.random(128, 134), lookHead = 94, lookBody = 94, lookLegs = 94, lookFeet = 94, lookAddons = 3})

		local rfemale = Condition(CONDITION_OUTFIT)
		rfemale:setTicks(-1)
		rfemale:setOutfit({lookType = math.random(136, 142), lookHead = 94, lookBody = 94, lookLegs = 94, lookFeet = 94, lookAddons = 3})

		local fight = Condition(CONDITION_INFIGHT)
		fight:setTicks(-1)

		-- Teleport and setup teams
		for _, p in ipairs(Game.getPlayers()) do
			if isTeamOne(p) then
				if p:getSex() == PLAYERSEX_MALE then
					p:addCondition(bmale)
				else
					p:addCondition(bfemale)
				end
				p:addCondition(fight)
				p:teleportTo(POS.Blue_Position, false)
				POS.Blue_Position:sendMagicEffect(CONST_ME_TELEPORT)
				applyFixedSpeed(p, getTheSpeed(SETTINGS.Players_Speed))
			elseif isTeamTwo(p) then
				if p:getSex() == PLAYERSEX_MALE then
					p:addCondition(rmale)
				else
					p:addCondition(rfemale)
				end
				p:addCondition(fight)
				p:teleportTo(POS.Red_Position, false)
				POS.Red_Position:sendMagicEffect(CONST_ME_TELEPORT)
				applyFixedSpeed(p, getTheSpeed(SETTINGS.Players_Speed))
			end
		end

		-- Start event
		gset(STORAGE.Event_Tile_Close, -1)
		gset(STORAGE.Event_timeend, 1)
		gset(STORAGE.Timer, os.time() + SETTINGS.Event_MaxTime * 60)
		Game.broadcastMessage("CTF started! First team to capture " .. SETTINGS.FLAG_SCORE .. " flags wins!")

		-- Schedule event end
		addEvent(function()
			if gget(STORAGE.Event_Start) > 0 and gget(STORAGE.Event_timeend) > 0 then
				local redScore = getRedScore()
				local blueScore = getBlueScore()

				if redScore > blueScore then
					Game.broadcastMessage('CTF-Event : The ' .. SETTINGS.TEAM2_NAME .. ' team won and recieved their reward.')
					for _, p in ipairs(Game.getPlayers()) do
						if isTeamTwo(p) then
							p:teleportTo(p:getTown():getTemplePosition(), false)
							p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
							p:removeCondition(CONDITION_OUTFIT)
							p:removeCondition(CONDITION_INFIGHT)
					resetTheTeams(p)
					resetSpeed(p)
							giveReward(p)
						elseif isTeamOne(p) then
							p:teleportTo(p:getTown():getTemplePosition(), false)
							p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
							p:removeCondition(CONDITION_OUTFIT)
							p:removeCondition(CONDITION_INFIGHT)
							p:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'Your team have lost.')
					resetTheTeams(p)
					resetSpeed(p)
						end
					end
				elseif redScore < blueScore then
					Game.broadcastMessage('CTF-Event : The ' .. SETTINGS.TEAM1_NAME .. ' team won and recieved their reward.')
					for _, p in ipairs(Game.getPlayers()) do
						if isTeamOne(p) then
							p:teleportTo(p:getTown():getTemplePosition(), false)
							p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
							p:removeCondition(CONDITION_OUTFIT)
							p:removeCondition(CONDITION_INFIGHT)
					resetTheTeams(p)
					resetSpeed(p)
							giveReward(p)
						elseif isTeamTwo(p) then
							p:teleportTo(p:getTown():getTemplePosition(), false)
							p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
							p:removeCondition(CONDITION_OUTFIT)
							p:removeCondition(CONDITION_INFIGHT)
							p:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'Your team have lost.')
					resetTheTeams(p)
					resetSpeed(p)
						end
					end
				else
					Game.broadcastMessage('CTF-Event : The Event ended with a draw between both teams.')
					for _, p in ipairs(Game.getPlayers()) do
						if isTeamTwo(p) or isTeamOne(p) then
							p:teleportTo(p:getTown():getTemplePosition(), false)
							p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
							p:removeCondition(CONDITION_OUTFIT)
							p:removeCondition(CONDITION_INFIGHT)
							p:sendTextMessage(MESSAGE_EVENT_ADVANCE, 'It was a draw between both teams.')
					resetTheTeams(p)
					resetSpeed(p)
						end
					end
				end
				resetTheStorage()
			end
		end, SETTINGS.Event_MaxTime * 60 * 1000)
		
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF event started with " .. #players .. " players!")
		return true
		
	elseif param == "close" then
		if gget(STORAGE.Event_Start) < 1 then
			player:sendCancelMessage("No event is currently open!")
			return true
		end
		
		-- Teleport all players in event area back to temple
		for _, p in ipairs(Game.getPlayers()) do
			if isTeamOne(p) or isTeamTwo(p) or p:getStorageValue(STORAGE.joined) == 1 then
				p:teleportTo(p:getTown():getTemplePosition(), false)
				p:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
				p:removeCondition(CONDITION_OUTFIT)
				p:removeCondition(CONDITION_INFIGHT)
					resetTheTeams(p)
					resetSpeed(p)
				p:setStorageValue(STORAGE.joined, -1)
			end
		end
		
		resetTheStorage()
		Game.broadcastMessage("CTF event has been cancelled by " .. player:getName() .. ".")
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF event closed successfully!")
		return true
		
	else
		player:sendCancelMessage("Use: /ctfe open | /ctfe start | /ctfe close")
		return true
	end
end

ctfGodTalk:separator(" ")
ctfGodTalk:groupType("god")
ctfGodTalk:register()

-- Player Commands: !ctf
local ctfTalk = TalkAction("!ctf")
function ctfTalk.onSay(player, words, param)
	param = (param or ""):lower():trim()
	
	if param == "join" then
		
		if player:getLevel() < SETTINGS.Min_Join_Level then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("CTF: minimum level is %d.", SETTINGS.Min_Join_Level))
			return true
		end
		
		if gget(STORAGE.Event_Start) < 1 or gget(STORAGE.Event_Tile_Close) < 1 then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF: Come back later, event is closed now.")
			return true
		end
		if gget(STORAGE.Event_timeend) > 0 then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF: The event has already started!")
			return true
		end
		
		-- Check if already joined
		if player:getStorageValue(STORAGE.joined) == 1 or isTeamOne(player) or isTeamTwo(player) then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF: You are already registered for the event!")
			return true
		end
		
		-- Mark as joined
		player:setStorageValue(STORAGE.joined, 1)
		
		player:teleportTo(POS.Wait_Place, false)
		POS.Wait_Place:sendMagicEffect(CONST_ME_TELEPORT)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF: You joined the event. Wait for it to start.")
		return true
		
	elseif param == "leave" then
		-- Can only leave before event starts
		if gget(STORAGE.Event_timeend) > 0 then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF: You cannot leave after the event has started!")
			return true
		end
		
		-- Only teleport if in event
		if isTeamOne(player) or isTeamTwo(player) or player:getStorageValue(STORAGE.joined) == 1 then
			resetTheTeams(player)
			player:setStorageValue(STORAGE.joined, -1)
			player:teleportTo(player:getTown():getTemplePosition(), false)
			player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF: You left the event queue.")
		else
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF: You are not in the event.")
		end
		return true
		
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("CTF: use '!ctf join' to enter (min level %d), '!ctf leave' to exit.", SETTINGS.Min_Join_Level))
		return true
	end
end

ctfTalk:separator(" ")
ctfTalk:groupType("normal")
ctfTalk:register()
