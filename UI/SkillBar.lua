-- The goal bar: Comprehension's profession skill-bar fill (classic skill-bar texture if the
-- client lacks it), running under a rounded tooltip border that is drawn ON TOP (own higher
-- frame), so the border's corners trim the fill's square ends. Marks (the 10-book goal) use the crafting quality meter's marker.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local FILL = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
local HEIGHT, EDGE, FILL_INSET = 24, 12, 2
-- Blizzard's rank bar: fill atlas "Skillbar_Fill_Flipbook_<kit>", 2 columns, 34 px rows, 2 s loop.
-- Comprehension is not in Enum.Profession, so Blizzard's kit lookup falls back to DefaultBlue.
local FLIP_ATLAS = "Skillbar_Fill_Flipbook_DefaultBlue"
local FLIP_COLUMNS, FLIP_FRAME_H, FLIP_DURATION = 2, 34, 2

local function atlas(name)
    local info = C_Texture.GetAtlasInfo(name)
    return info and info.width > 0 and info or nil
end

local function markerTexture(parent, height)
    local t = parent:CreateTexture(nil, "OVERLAY")
    local info = atlas("Professions-QualityBar-marker")
    if info then
        t:SetAtlas("Professions-QualityBar-marker")
        t:SetSize(info.width * height / info.height, height)
    else
        t:SetTexture(WHITE)
        t:SetVertexColor(1, 1, 1, 0.9)
        t:SetSize(2, height * 0.6)
    end
    return t
end

-- bar:SetProgress(0..1), bar:AddMark(0..1).
function ns:CreateSkillBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(HEIGHT)
    -- background, full size (the border covers its corners)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(WHITE)
    bg:SetVertexColor(0, 0, 0, 0.65)
    bg:SetPoint("TOPLEFT", FILL_INSET, -FILL_INSET)
    bg:SetPoint("BOTTOMRIGHT", -FILL_INSET, FILL_INSET)
    -- fill area: nearly the whole frame, under the border
    local area = CreateFrame("Frame", nil, bar)
    area:SetPoint("TOPLEFT", FILL_INSET, -FILL_INSET)
    area:SetPoint("BOTTOMRIGHT", -FILL_INSET, FILL_INSET)
    local setFill
    local sheet = atlas(FLIP_ATLAS)
    if sheet and sheet.file then
        -- Comprehension's skill bar: Blizzard's default profession fill. The atlas is a flipbook
        -- of FLIP_COLUMNS x (height / 34) frames; on Forever it is 880 x 33 = 2 frames of 440 x 33
        -- (probed 2026-09-28). Two textures crossfade from each frame to the next over the loop
        -- instead of hard-switching (with 2 frames a hard switch reads as a blink). Both are
        -- cropped to the progress; OnUpdate runs only while the window is shown.
        local rows = math.max(1, math.floor(sheet.height / FLIP_FRAME_H + 0.5))
        local frames = rows * FLIP_COLUMNS
        local l, r = sheet.leftTexCoord, sheet.rightTexCoord
        local t, b = sheet.topTexCoord, sheet.bottomTexCoord
        local cw, ch = (r - l) / FLIP_COLUMNS, (b - t) / rows
        local function layer(sub)
            local tex = area:CreateTexture(nil, "ARTWORK", nil, sub)
            tex:SetTexture(sheet.file)
            tex:SetPoint("TOPLEFT")
            tex:SetPoint("BOTTOMLEFT")
            return tex
        end
        local cur, nxt = layer(1), layer(2)
        local frac, clock = 0, 0
        local function crop(tex, index)
            local col, row = index % FLIP_COLUMNS, math.floor(index / FLIP_COLUMNS)
            local u0, v0 = l + col * cw, t + row * ch
            tex:SetTexCoord(u0, u0 + cw * frac, v0, v0 + ch)
        end
        local function draw()
            local pos = (clock / FLIP_DURATION) * frames -- frames advanced along the loop
            local index = math.floor(pos) % frames
            crop(cur, index)
            crop(nxt, (index + 1) % frames)
            -- smoothstep so each hand-over eases in and out
            local p = pos - math.floor(pos)
            nxt:SetAlpha(p * p * (3 - 2 * p))
        end
        setFill = function(f)
            frac = f
            local w = math.max(0.1, area:GetWidth() * f)
            cur:SetWidth(w)
            nxt:SetWidth(w)
            cur:SetShown(f > 0)
            nxt:SetShown(f > 0)
            draw()
        end
        area:SetScript("OnUpdate", function(_, dt)
            clock = (clock + dt) % FLIP_DURATION
            draw()
        end)
    else
        -- no atlas: the classic skill-bar texture, tinted gold
        local sb = CreateFrame("StatusBar", nil, area)
        sb:SetAllPoints()
        sb:SetStatusBarTexture(FILL)
        sb:SetStatusBarColor(0.85, 0.65, 0.25)
        sb:SetMinMaxValues(0, 1)
        setFill = function(f) sb:SetValue(f) end
    end
    -- border on top of the fill
    local edge = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    edge:SetAllPoints()
    edge:SetFrameLevel(area:GetFrameLevel() + 3)
    edge:SetBackdrop({ edgeFile = BORDER, edgeSize = EDGE })
    edge:SetBackdropBorderColor(0.6, 0.47, 0.24)
    -- marks above everything
    local marks = CreateFrame("Frame", nil, bar)
    marks:SetAllPoints()
    marks:SetFrameLevel(edge:GetFrameLevel() + 1)

    bar.marks = {}
    function bar:SetProgress(frac)
        self.frac = math.max(0, math.min(1, frac))
        setFill(self.frac)
        local w = area:GetWidth()
        for f, t in pairs(self.marks) do
            t:ClearAllPoints()
            t:SetPoint("CENTER", area, "LEFT", w * f, 0)
        end
    end
    function bar:AddMark(frac)
        self.marks[frac] = markerTexture(marks, HEIGHT + 10)
    end
    bar:SetScript("OnSizeChanged", function(self) self:SetProgress(self.frac or 0) end)
    return bar
end
