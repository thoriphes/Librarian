-- Localisation. Keys are the English strings (enUS is the key itself); a locale table only lists
-- what it translates, anything missing falls back to English. Names that come from the game
-- (book titles, zones, quest titles, factions) are read from the client instead - see
-- ns:BookName / ns:QuestTitle / ns:SideName. Site-sourced notes (locations, hints) stay English.
-- ASCII only in this file: accented letters are written as UTF-8 byte escapes (\195\169 = e-acute).
local _, ns = ...

local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

local locale = GetLocale()

if locale == "esES" or locale == "esMX" then
    local T = {
        -- states + groups
        ["Missing"] = "Falta",
        ["In bags"] = "En la bolsa",
        ["Delivered"] = "Entregado",
        ["Contested"] = "En disputa",
        -- journal
        ["You are here"] = "Est\195\161s aqu\195\173",
        ["%s at %s"] = "%s en %s",
        ["Also: %s  %.1f, %.1f"] = "Tambi\195\169n: %s  %.1f, %.1f",
        ["(trainer turn-in)"] = "(se entrega al instructor)",
        ["(marked)"] = "(marcado)",
        ["Add marker"] = "A\195\177adir marcador",
        ["Show on Map"] = "Ver en el mapa",
        ["Click: show this book"] = "Clic: ver este libro",
        ["Other books in %s"] = "Otros libros en %s",
        -- rewards page
        ["Click to see all possible rewards"] = "Clic para ver todas las recompensas posibles",
        ["For casters"] = "Para lanzadores de hechizos",
        ["For physical fighters"] = "Para luchadores f\195\173sicos",
        ["For any spec"] = "Para cualquier especializaci\195\179n",
        ["Classes: %s"] = "Clases: %s",
        ["Your pick"] = "Tu elecci\195\179n",
        ["Click to pick"] = "Clic para elegir",
        ["Not for your class or spec"] = "No es para tu clase o especializaci\195\179n",
        ["< Books"] = "< Libros",
        ["Clear mark"] = "Quitar marca",
        ["Mark in bags"] = "Marcar en bolsa",
        ["Mark delivered"] = "Marcar entregado",
        ["Manual mark (this character)"] = "Marca manual (este personaje)",
        ["Use it when the game does not report the book: a book whose turn-in does not exist on Forever, or a detection miss."] =
            "\195\154sala cuando el juego no informa del libro: un libro cuya misi\195\179n de entrega no existe en Forever, o un fallo de detecci\195\179n.",
        ["%d/%d delivered, %d in bags"] = "%d/%d entregados, %d en la bolsa",
        ["Turned in to a mage trainer (Jennea Cannon / Oran Snakewrithe), not a librarian; whether it counts toward the library rewards is not known."] =
            "Se entrega a un instructor de magos (Jennea Cannon / Oran Snakewrithe), no a un bibliotecario; no se sabe si cuenta para las recompensas de la biblioteca.",
        ["In %s territory: expect guards."] = "En territorio de la %s: habr\195\161 guardias.",
        ["Its turn-in quest is missing from Forever's database: mark it by hand."] =
            "Su misi\195\179n de entrega no est\195\161 en la base de datos de Forever: m\195\161rcalo a mano.",
        ["Also found elsewhere; the same book counts once."] = "Tambi\195\169n est\195\161 en otro sitio; el mismo libro cuenta una vez.",
        ["%d books delivered."] = "%d libros entregados.",
        ["done"] = "hecho",
        ["ready"] = "listo",
        -- summary cards
        ["Recommended next"] = "Siguiente recomendado",
        ["Current zone"] = "Zona actual",
        ["Next reward"] = "Siguiente recompensa",
        ["Every missing book is found. Congratulations!"] = "Has encontrado todos los libros que faltaban. \194\161Enhorabuena!",
        ["Nothing left to find in this zone. Congratulations!"] = "No queda nada por encontrar en esta zona. \194\161Enhorabuena!",
        ["Every reward earned. Congratulations!"] = "Has conseguido todas las recompensas. \194\161Enhorabuena!",
        ["%d / %d books delivered"] = "%d / %d libros entregados",
        ["Your pick: %s (%d/%d)"] = "Tu elecci\195\179n: %s (%d/%d)",
        ["Reward: %s"] = "Recompensa: %s",
        ["Click: next reward choice"] = "Clic: siguiente recompensa a elegir",
        ["Turn in at %s, %s"] = "Se entrega a %s, %s",
        ["%d more to go"] = "Faltan %d",
        ["Ready to turn in"] = "Listo para entregar",
        -- toast
        ["1 library book missing in %s"] = "Falta 1 libro de la biblioteca en %s",
        ["%d library books missing in %s"] = "Faltan %d libros de la biblioteca en %s",
        ["and %d more"] = "y %d m\195\161s",
        ["no library books in this zone."] = "no hay libros de la biblioteca en esta zona.",
        ["%s: no missing books."] = "%s: no falta ning\195\186n libro.",
        -- tracker
        ["Library Books"] = "Libros de la biblioteca",
        ["Turn in 1 book"] = "Entregar 1 libro",
        ["Turn in %d books"] = "Entregar %d libros",
        ["%d to %s (%s)"] = "%d a %s (%s)",
        -- map pins, waypoint, button
        ["Turn in: mage trainer"] = "Entrega: instructor de magos",
        ["Turn in: librarian"] = "Entrega: bibliotecario",
        ["Click: waypoint   Shift-click: journal"] = "Clic: punto de ruta   May\195\186s-clic: diario",
        ["waypoint set: %s"] = "punto de ruta: %s",
        ["the world map cannot be opened from an addon in combat."] = "un addon no puede abrir el mapa del mundo en combate.",
        ["%d library books delivered"] = "%d libros de la biblioteca entregados",
        ["Left-click: journal   Right-click: options"] = "Clic izquierdo: diario   Clic derecho: opciones",
        -- options
        ["Zone toast"] = "Aviso al entrar en una zona",
        ["Entering a zone with a missing book shows a toast, once per zone per session."] =
            "Al entrar en una zona con un libro que falta se muestra un aviso, una vez por zona y sesi\195\179n.",
        ["World map pins"] = "Marcadores en el mapa del mundo",
        ["Pins for missing books on zone and continent maps."] = "Marcadores de los libros que faltan en los mapas de zona y de continente.",
        ["Also pin books in your bags"] = "Marcar tambi\195\169n los libros en la bolsa",
        ["Pin books that are in your bags but not delivered yet."] = "Marca los libros que llevas en la bolsa pero a\195\186n no has entregado.",
        ["Objective tracker section"] = "Secci\195\179n en el seguimiento de objetivos",
        ["List the zone's missing books in the objective tracker. Changes apply out of combat."] =
            "Muestra los libros que faltan en la zona en el seguimiento de objetivos. Los cambios se aplican fuera de combate.",
        ["TomTom waypoints"] = "Puntos de ruta de TomTom",
        ["Waypoints (Add marker, map pins, the tracker) go to TomTom when it is loaded (otherwise Blizzard's map pin)."] =
            "Los puntos de ruta (A\195\177adir marcador, marcadores del mapa, el seguimiento) van a TomTom si est\195\161 cargado (si no, el marcador de mapa de Blizzard).",
        ["Show the other faction's books"] = "Mostrar los libros de la otra facci\195\179n",
        ["Include turn-ins your faction cannot do."] = "Incluye entregas que tu facci\195\179n no puede hacer.",
        ["List books that cannot be had"] = "Listar los libros que no se pueden conseguir",
        ["Books with no known location or not in Forever, at the bottom of the journal."] =
            "Libros sin ubicaci\195\179n conocida o que no est\195\161n en Forever, al final del diario.",
        ["Hide the minimap button"] = "Ocultar el bot\195\179n del minimapa",
        ["The addon compartment entry stays."] = "La entrada del compartimento de addons se mantiene.",
        ["Library book tracker. %d books."] = "Seguimiento de los libros de la biblioteca. %d libros.",
        ["Open Journal"] = "Abrir diario",
        ["Options"] = "Opciones",
        ["options cannot be opened in combat."] = "las opciones no se pueden abrir en combate.",
        -- chat
        ["no zone matches '%s'."] = "ninguna zona coincide con '%s'.",
        ["%s: no library books for your faction."] = "%s: no hay libros de la biblioteca para tu facci\195\179n.",
        ["%d books delivered (goals: 10, 20)"] = "%d libros entregados (objetivos: 10, 20)",
        ["[manual]"] = "[manual]",
    }
    for k, v in pairs(T) do rawset(L, k, v) end
end

-- ---------------------------------------------------------------------------------------
-- Names from the client (localised); the data file's English names are the fallback until
-- the item / quest is cached.

function ns:BookName(b)
    return C_Item.GetItemNameByID(b.item) or b.name
end

function ns:QuestTitle(questID, fallback)
    return C_QuestLog.GetTitleForQuestID(questID) or fallback
end

function ns:SideName(side)
    if side == "Alliance" then return FACTION_ALLIANCE or side end
    if side == "Horde" then return FACTION_HORDE or side end
    return L[side]
end

-- ---------------------------------------------------------------------------------------
-- Book data text. Places come from the game (area ID -> localised name, every client locale);
-- containers, notes and the "cannot be had" texts from Data/Strings.lua (ns.DataL, generated:
-- Blizzard's strings + hand translations); flavour from the client's own item tooltip, else
-- Blizzard's text in Strings.lua, else the site's English.

local function dataL()
    return ns.DataL or { strings = {}, flavour = {} }
end

function ns:DataText(s)
    return s and (dataL().strings[s] or s)
end

function ns:PlaceName(spot)
    if spot.area then
        local name = C_Map.GetAreaInfo(spot.area)
        if name and name ~= "" then return name end
    end
    return ns:DataText(spot.place)
end

-- "Scrolls at Moonbrook" / "Scrolls" / "Moonbrook" / nil
function ns:WhereText(spot)
    local c, p = ns:DataText(spot.container), spot.place and ns:PlaceName(spot)
    if c and p then return L["%s at %s"]:format(c, p) end
    return c or p
end

local flavourCache = {}
local function clientFlavour(item)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return end
    local data = C_TooltipInfo.GetItemByID(item)
    for _, line in ipairs(data and data.lines or {}) do
        local text = line.leftText
        local inner = type(text) == "string" and text:match('^"(.+)"$')
        if inner then return inner end
    end
end

function ns:Flavour(b)
    local official = dataL().flavour[b.item]
    if official then return official end
    if GetLocale() == "enUS" or GetLocale() == "enGB" then return b.flavour end
    if flavourCache[b.item] == nil then
        flavourCache[b.item] = clientFlavour(b.item) or false
    end
    return flavourCache[b.item] or b.flavour
end

-- Ask the client for every book's item data once; refresh the UI when names arrive.
ns:On("LOADED", function()
    local pending = {}
    for _, b in ipairs(ns.Books) do
        if not C_Item.GetItemNameByID(b.item) then
            pending[b.item] = true
            C_Item.RequestLoadItemDataByID(b.item)
        end
    end
    for _, g in ipairs(ns.Goals) do
        if C_QuestLog.RequestLoadQuestByID then C_QuestLog.RequestLoadQuestByID(g.quest) end
        for _, r in ipairs(g.rewards or {}) do
            if not C_Item.GetItemNameByID(r.item) then
                pending[r.item] = true
                C_Item.RequestLoadItemDataByID(r.item)
            end
        end
    end
    ns:RegisterEvent("ITEM_DATA_LOAD_RESULT", function(_, itemID, success)
        if pending[itemID] and success then
            pending[itemID] = nil
            flavourCache[itemID] = nil
            ns:Fire("NAMES")
        end
    end)
    ns:RegisterEvent("QUEST_DATA_LOAD_RESULT", function() ns:Fire("NAMES") end)
end)
