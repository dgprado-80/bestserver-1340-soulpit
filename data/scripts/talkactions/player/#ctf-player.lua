-- Player talkactions: !ctf join / !ctf leave

local SETTINGS = {
	Min_Join_Level = 100,
}

local POS = {
	Wait_Place = Position(32252, 33106, 7),
}

local STORAGE = {
	joined = 2023,
}

local function sendInfo(player)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("CTF: use '!ctf join' to enter (min level %d), '!ctf leave' to exit.", SETTINGS.Min_Join_Level))
end

local function join(player)
	if player:getLevel() < SETTINGS.Min_Join_Level then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("CTF: minimum level is %d.", SETTINGS.Min_Join_Level))
		return true
	end
	if player:getStorageValue(STORAGE.joined) == 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF: you are already registered.")
		return true
	end
	player:setStorageValue(STORAGE.joined, 1)
	player:teleportTo(POS.Wait_Place, false)
	POS.Wait_Place:sendMagicEffect(CONST_ME_TELEPORT)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF: registered successfully. Wait for the start.")
	return true
end

local function leave(player)
	if player:getStorageValue(STORAGE.joined) ~= 1 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF: you are not in the queue.")
		return true
	end
	player:setStorageValue(STORAGE.joined, -1)
	player:teleportTo(player:getTown():getTemplePosition(), false)
	player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "CTF: you left the event queue.")
	return true
end

local talk = TalkAction("!ctf")
function talk.onSay(player, words, param)
	param = (param or ""):lower():trim()
	if param == "join" then
		return join(player)
	elseif param == "leave" then
		return leave(player)
	else
		sendInfo(player)
		return true
	end
end

talk:separator(" ")
ctfTalk:groupType("normal")
talk:register()


