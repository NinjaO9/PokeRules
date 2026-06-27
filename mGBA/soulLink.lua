console:log("Soul Link script loaded.")

-- Pokemon Fire Red EN version 1 exclusive right now

-- Memory addresses
PARTY_POKEMON_1 = 0x02024284
PARTY_POKEMON_2 = 0x020242E8
PARTY_POKEMON_3 = 0x0202434C
PARTY_POKEMON_4 = 0x020243B0
PARTY_POKEMON_5 = 0x02024414
PARTY_POKEMON_6 = 0x02024478

PARTY_POKEMON_STARTADDR = {
    PARTY_POKEMON_1,
    PARTY_POKEMON_2,
    PARTY_POKEMON_3,
    PARTY_POKEMON_4,
    PARTY_POKEMON_5,
    PARTY_POKEMON_6
}

-- Offsets within a pkmn block
NICKNAME_OFFSET = 0x08
CURRENT_HEALTH_OFFSET = 0x56
MAX_HEALTH_OFFSET = 0x58

-- Other constants
PROBE_INTERVAL = 60 -- frames

-- Global variables
local frame_count = 0
local iterations = 0

-- Mapping for decoding pkmn characters
local decode_map = {
    [0xBB] = "A",[0xBC] = "B",[0xBD] = "C",[0xBE] = "D",[0xBF] = "E",
    [0xC0] = "F",[0xC1] = "G",[0xC2] = "H",[0xC3] = "I",[0xC4] = "J",
    [0xC5] = "K",[0xC6] = "L",[0xC7] = "M",[0xC8] = "N",[0xC9] = "O",
    [0xCA] = "P",[0xCB] = "Q",[0xCC] = "R",[0xCD] = "S",[0xCE] = "T",
    [0xCF] = "U",[0xD0] = "V",[0xD1] = "W",[0xD2] = "X",[0xD3] = "Y",
    [0xD4] = "Z",
    [0xD5] = "a",[0xD6] = "b",[0xD7] = "c",[0xD8] = "d",[0xD9] = "e",
    [0xDA] = "f",[0xDB] = "g",[0xDC] = "h",[0xDD] = "i",[0xDE] = "j",
    [0xDF] = "k",[0xE0] = "l",[0xE1] = "m",[0xE2] = "n",[0xE3] = "o",
    [0xE4] = "p",[0xE5] = "q",[0xE6] = "r",[0xE7] = "s",[0xE8] = "t",
    [0xE9] = "u",[0xEA] = "v",[0xEB] = "w",[0xEC] = "x",[0xED] = "y",
    [0xEE] = "z",
}

local trainerParty = {
    pokemon = {}
}

local pokemonInfo = {
    nickname = "",
    current_health = 0,
    max_health = 0
}


local function getPokemonCurHealth(pkmn)
    return emu:read16(PARTY_POKEMON_STARTADDR[pkmn] + CURRENT_HEALTH_OFFSET)
end

local function getPokemonMaxHealth(pkmn)
    return emu:read16(PARTY_POKEMON_STARTADDR[pkmn] + MAX_HEALTH_OFFSET)
end

local function getPokemonNickname(pkmn)
    local nickname = ""
    for i = 0, 9 do
        local char = emu:read8(PARTY_POKEMON_STARTADDR[pkmn] + NICKNAME_OFFSET + i)
        if char == 0xFF then -- End of string character
            break
        end
        nickname = nickname .. (decode_map[char] or "?")
    end
    return nickname
end

local function displayPkmnTeam()
    local pkmn = 0
    console:log(string.format("TEAM LAYOUT:"))
    while trainerParty.pokemon[pkmn] ~= nil and pkmn ~= 6 do
        console:log(string.format("[Slot %d]: %s: %d/%d HP", pkmn, trainerParty.pokemon[pkmn].nickname, trainerParty.pokemon[pkmn].current_health, trainerParty.pokemon[pkmn].max_health))
        pkmn = pkmn + 1
    end
end

local function readPokemonInfo(pkmn)
    local nickname = getPokemonNickname(pkmn)
    local cur_hp = getPokemonCurHealth(pkmn)
    local max_hp = getPokemonMaxHealth(pkmn)
    return {
        nickname = nickname,
        current_health = cur_hp,
        max_health = max_hp
    }
end

local function updateReadPokemonInfo(pkmn, newInfo)
    local oldInfo = trainerParty.pokemon[pkmn]
    if not oldInfo then
        trainerParty.pokemon[pkmn] = newInfo
        console:log(string.format("[Slot %d][ADDED]: %s: %d/%d HP", pkmn, newInfo.nickname, newInfo.current_health, newInfo.max_health))
        return
    end
    if oldInfo.nickname ~= newInfo.nickname then
        console:log(string.format("[Slot %d][SWAPPED]: %s replaced by %s", pkmn, oldInfo.nickname, newInfo.nickname))
    end
    if oldInfo.current_health ~= newInfo.current_health and oldInfo.nickname == newInfo.nickname then
        console:log(string.format("[Slot %d][HP CHANGE]: %s: %d -> %d HP", pkmn, newInfo.nickname, oldInfo.current_health, newInfo.current_health))
    end
    trainerParty.pokemon[pkmn] = newInfo
end

local function movePkmnUp(pkmn, party)
    while pkmn ~= 6 do
        local exists = emu:read8(PARTY_POKEMON_STARTADDR[pkmn + 1]) ~= 0x00
        if exists and party[pkmn] == nil then
            party[pkmn] = party[pkmn + 1]
            party[pkmn + 1] = nil
        end
        pkmn = pkmn + 1
    end
end

local function update()
    console:log(string.format("Size: %d", emu:read8(PARTY_POKEMON_1 - 0x25B))) -- 0x02024029
    for pkmn = 1, 6 do
        local exists = emu:read8(PARTY_POKEMON_STARTADDR[pkmn]) ~= 0x00
        if not exists then
            if trainerParty.pokemon[pkmn] then
                console:log(string.format("[Slot %d][REMOVED]: %s", pkmn, trainerParty.pokemon[pkmn].nickname))
            end
            trainerParty.pokemon[pkmn] = nil
            movePkmnUp(pkmn, trainerParty)
            break
        end
        updateReadPokemonInfo(pkmn, readPokemonInfo(pkmn))
    end
end

local function run()
    if PROBE_INTERVAL - frame_count > 0 then
        frame_count = frame_count + 1
        iterations = iterations + 1
        return
    else
        frame_count = 0
        update()
    end
    if iterations == 3 then
        iterations = 0
        displayPkmnTeam()
    end
end

callbacks:add("frame", run)