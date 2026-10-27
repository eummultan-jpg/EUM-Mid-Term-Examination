gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local font = resource.load_font("font.ttf")
local bold = resource.load_font("font-bold.ttf")
local logo = resource.load_image("logo.png")

local data = {}
local cfg = { family = "ALL", rotation_seconds = 12 }
local sections = {}
local section_index = 1
local rotation_started = sys.now()

local days = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function trim(s)
    s = tostring(s or "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function words(text)
    local out = {}
    for w in tostring(text or ""):gmatch("%S+") do out[#out + 1] = w end
    return out
end

local function fit(text, f, size, maxw)
    text = tostring(text or "")
    if f:width(text, size) <= maxw then return text end
    local s = ""
    for _, w in ipairs(words(text)) do
        local n = (s == "" and w or s .. " " .. w)
        if f:width(n .. "…", size) > maxw then break end
        s = n
    end
    if s ~= "" then return s .. "…" end
    while #text > 1 and f:width(text .. "…", size) > maxw do
        text = text:sub(1, -2)
    end
    return text .. "…"
end

-- Keep complete course titles visible by wrapping them to two lines.
-- The font is reduced when required instead of adding an ellipsis.
local function wrap_two_lines(text, f, maxw, preferred_size, min_size)
    text = trim(text)
    preferred_size = preferred_size or 20
    min_size = min_size or 13

    for size = preferred_size, min_size, -1 do
        local lines = {}
        local current = ""

        for _, w in ipairs(words(text)) do
            local candidate = (current == "" and w or current .. " " .. w)
            if f:width(candidate, size) <= maxw then
                current = candidate
            else
                if current ~= "" then lines[#lines + 1] = current end
                current = w
            end
        end
        if current ~= "" then lines[#lines + 1] = current end

        if #lines <= 2 then return lines, size end
    end

    -- Fallback: preserve all words at the minimum readable size.
    local size = min_size
    local line1, line2 = "", ""
    for _, w in ipairs(words(text)) do
        local candidate = (line1 == "" and w or line1 .. " " .. w)
        if line2 == "" and f:width(candidate, size) <= maxw then
            line1 = candidate
        else
            line2 = (line2 == "" and w or line2 .. " " .. w)
        end
    end
    return {line1, line2}, size
end

local PKT_OFFSET_SECONDS = 5 * 60 * 60

local function pkt_time()
    -- Read the system clock as UTC and explicitly convert to Pakistan Standard Time (UTC+5).
    return os.date("!*t", os.time() + PKT_OFFSET_SECONDS)
end

local function minute_now()
    local t = pkt_time()
    return t.hour * 60 + t.min
end

local function date_iso_now()
    local t = pkt_time()
    return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

local months = {
    "January","February","March","April","May","June",
    "July","August","September","October","November","December"
}

local function pkt_date_label(t)
    return string.format("%02d %s %04d", t.day, months[t.month], t.year)
end

local function pkt_time_label(t)
    local hour = t.hour % 12
    if hour == 0 then hour = 12 end
    return string.format("%02d:%02d:%02d %s", hour, t.min, t.sec, t.hour >= 12 and "PM" or "AM")
end

local function rebuild_sections()
    sections = {}
    for _, family in ipairs(data.families or {}) do
        if cfg.family == "ALL" or cfg.family == "" or cfg.family == family.name then
            for _, section in ipairs(family.sections or {}) do
                section.family = family.name
                sections[#sections + 1] = section
            end
        end
    end
    if #sections == 0 then
        for _, family in ipairs(data.families or {}) do
            for _, section in ipairs(family.sections or {}) do
                section.family = family.name
                sections[#sections + 1] = section
            end
        end
    end
    if #sections > 0 then
        section_index = clamp(section_index, 1, #sections)
    else
        section_index = 1
    end
    rotation_started = sys.now()
end

util.json_watch("exam.json", function(v)
    data = v or {}
    rebuild_sections()
end)

util.json_watch("config.json", function(v)
    v = v or {}
    cfg.family = v.family or "ALL"
    cfg.rotation_seconds = tonumber(v.rotation_seconds or 12) or 12
    cfg.rotation_seconds = clamp(cfg.rotation_seconds, 5, 120)
    rebuild_sections()
end)

local function current_section()
    if #sections == 0 then return nil end
    if sys.now() - rotation_started >= cfg.rotation_seconds then
        section_index = section_index + 1
        if section_index > #sections then section_index = 1 end
        rotation_started = sys.now()
    end
    return sections[section_index]
end

local function exams_for_section(section)
    local out = {}
    local today = date_iso_now()
    local now = minute_now()
    for _, e in ipairs(section.rows or {}) do
        local date = e.date_iso or ""
        local s = tonumber(e.start_min)
        local en = tonumber(e.end_min)
        local state = "future"
        if date < today or (date == today and en and en <= now) then
            state = "past"
        elseif date == today and s and en and now >= s and now < en then
            state = "now"
        else
            state = "next"
        end
        out[#out + 1] = {
            date = date,
            date_label = e.date_label or date,
            time = e.time or "",
            start_min = s,
            end_min = en,
            state = state,
            code = e.code or "",
            course = e.course or "",
            room = e.room or "",
            invigilator = e.invigilator or "",
            students = e.students or "",
            slot = e.slot or ""
        }
    end
    table.sort(out, function(a,b)
        if a.date == b.date then
            return (a.start_min or 9999) < (b.start_min or 9999)
        end
        return a.date < b.date
    end)
    return out
end

local function find_status(exams)
    local today = date_iso_now()
    local now = minute_now()
    local cur, nxt = nil, nil
    for _, e in ipairs(exams) do
        if e.date == today and e.start_min and e.end_min and now >= e.start_min and now < e.end_min then
            cur = e
            break
        end
    end
    for _, e in ipairs(exams) do
        if e.date > today or (e.date == today and e.start_min and e.start_min > now) then
            nxt = e
            break
        end
    end
    return cur, nxt
end

local function first_display_index(exams)
    local today = date_iso_now()
    local now = minute_now()
    for i, e in ipairs(exams) do
        if e.date > today or (e.date == today and e.end_min and e.end_min > now) then
            return math.max(1, i)
        end
    end
    return math.max(1, #exams)
end

local color_textures = {}

local function color_key(r, g, b, a)
    return string.format("%.4f,%.4f,%.4f,%.4f", r, g, b, a or 1)
end

local function solid_texture(r, g, b, a)
    local key = color_key(r, g, b, a)
    local tex = color_textures[key]
    if not tex then
        tex = resource.create_colored_texture(r, g, b, a or 1)
        color_textures[key] = tex
    end
    return tex
end

local function rect(x, y, w, h, r, g, b, a)
    solid_texture(r, g, b, a):draw(x, y, x + w, y + h)
end

local function line(x1, y1, x2, y2, w, r, g, b, a)
    if math.abs(x2 - x1) >= math.abs(y2 - y1) then
        rect(math.min(x1, x2), y1 - w / 2, math.abs(x2 - x1), w, r, g, b, a)
    else
        rect(x1 - w / 2, math.min(y1, y2), w, math.abs(y2 - y1), r, g, b, a)
    end
end

local function center(f, x, y, w, text, size, r, g, b, a)
    text = tostring(text or "")
    f:write(x + (w - f:width(text, size)) / 2, y, text, size, r, g, b, a or 1)
end

local function draw_status_card(x, y, w, h, title, color, e, is_now)
    rect(x, y, w, h, 0.97, 0.985, 1.00, 1)
    rect(x, y, w, 62, color[1], color[2], color[3], 1)
    bold:write(x + 26, y + 17, title, 27, 1, 1, 1, 1)

    if not e then
        bold:write(x + 28, y + 94, is_now and "NO EXAM NOW" or "NO MORE EXAMS",
            27, 0.12, 0.20, 0.32, 1)
        return
    end

    local title_text = trim((e.code ~= "" and e.code .. " — " or "") .. e.course)
    local title_lines, title_size = wrap_two_lines(title_text, bold, w - 56, 27, 17)

    bold:write(x + 28, y + 82, title_lines[1] or "", title_size,
        0.05, 0.12, 0.22, 1)
    if title_lines[2] then
        bold:write(x + 28, y + 82 + title_size + 5, title_lines[2], title_size,
            0.05, 0.12, 0.22, 1)
    end

    local meta_y = y + 82 + (title_lines[2] and title_size + 36 or title_size + 15)
    font:write(x + 28, meta_y, e.date_label .. "  •  " .. e.time,
        20, 0.12, 0.25, 0.38, 1)
    font:write(x + 28, meta_y + 32, "ROOM  " .. (e.room ~= "" and e.room or "—"),
        20, 0.04, 0.30, 0.55, 1)

    local inv = e.invigilator ~= "" and ("INVIGILATOR: " .. e.invigilator) or "INVIGILATOR: —"
    font:write(x + 28, meta_y + 64, fit(inv, font, 18, w - 56),
        18, 0.20, 0.28, 0.38, 1)

    if e.students ~= "" then
        font:write(x + 28, meta_y + 94, "STUDENTS: " .. tostring(e.students),
            18, 0.20, 0.28, 0.38, 1)
    end
end

function node.render()
    local W, H = NATIVE_WIDTH, NATIVE_HEIGHT
    gl.clear(0.94, 0.96, 0.98, 1)

    local section = current_section()
    local t = pkt_time()
    local day = days[t.wday]
    local time_str = pkt_time_label(t)

    rect(0, 0, W, 165, 0.98, 0.99, 1.00, 1)
    rect(0, 160, W, 7, 0.98, 0.73, 0.10, 1)

    -- Official Emerson University Multan seal with transparent background.
    logo:draw(35, 18, 145, 148)

    bold:write(165, 31, "EMERSON UNIVERSITY MULTAN", 43, 0.03, 0.15, 0.30, 1)
    font:write(166, 88, "FACULTY OF COMPUTING & EMERGING TECHNOLOGIES", 25, 0.08, 0.24, 0.42, 1)

    local date_x = W - 570
    rect(date_x, 0, 570, 160, 0.04, 0.23, 0.46, 1)
    bold:write(date_x + 38, 27, day, 27, 1, 1, 1, 1)
    bold:write(date_x + 38, 61, pkt_date_label(t), 25, 1, 1, 1, 1)
    line(date_x + 285, 27, date_x + 285, 132, 2, 0.55, 0.70, 0.88, 1)
    bold:write(date_x + 315, 44, time_str, 31, 1, 1, 1, 1)
    font:write(date_x + 315, 91, "LIVE CLOCK", 17, 0.70, 0.88, 1, 1)

    if not section then
        center(bold, 0, H/2, W, "Loading examination schedule...", 42, 0.03, 0.15, 0.30, 1)
        return
    end

    local exams = exams_for_section(section)
    local cur, nxt = find_status(exams)
    local focus = first_display_index(exams)

    bold:write(45, 190, "MID TERM EXAMINATION", 38, 0.03, 0.12, 0.24, 1)
    font:write(47, 232, "FALL 2026  •  28 OCTOBER – 06 NOVEMBER 2026", 22, 0.13, 0.25, 0.39, 1)
    bold:write(47, 266, fit(section.name or "", bold, 29, W - 650), 29, 0.03, 0.18, 0.34, 1)
    font:write(47, 300, (section.semester or "") .. "  •  " .. (section.shift or ""), 20, 0.18, 0.28, 0.40, 1)

    local leftX, leftY, leftW = 35, 330, math.floor(W * 0.665)
    local rightX = leftX + leftW + 25
    local rightW = W - rightX - 35

    rect(leftX, leftY, leftW, H - leftY - 105, 0.98, 0.99, 1.00, 1)
    rect(leftX, leftY, leftW, 58, 0.04, 0.24, 0.47, 1)

    local c1 = 155
    local c2 = 165
    local c3 = math.floor(leftW * 0.38)
    local c4 = leftW - c1 - c2 - c3
    local tableY = leftY + 58
    local availableH = H - tableY - 105
    local maxRows = math.min(#exams, 6)
    local rowH = maxRows > 0 and math.floor(availableH / maxRows) or 74
    rowH = clamp(rowH, 64, 90)

    center(bold, leftX, leftY + 17, c1, "DATE", 20, 1, 1, 1, 1)
    center(bold, leftX + c1, leftY + 17, c2, "TIME", 20, 1, 1, 1, 1)
    center(bold, leftX + c1 + c2, leftY + 17, c3, "COURSE", 20, 1, 1, 1, 1)
    center(bold, leftX + c1 + c2 + c3, leftY + 17, c4, "ROOM", 20, 1, 1, 1, 1)

    if #exams == 0 then
        center(bold, leftX, tableY + 75, leftW, "NO EXAMINATION DATA", 29, 0.22, 0.31, 0.42, 1)
    else
        local start_i = focus
        for r = 1, maxRows do
            local i = start_i + r - 1
            if i > #exams then i = i - #exams end
            local e = exams[i]
            local y = tableY + (r-1) * rowH
            local is_cur = cur == e
            local is_nxt = (nxt == e)
            local bg = (r % 2 == 0) and {0.95,0.97,0.99} or {0.99,0.995,1.0}
            if is_cur then bg = {1.0, 0.91, 0.63}
            elseif is_nxt then bg = {0.89, 0.95, 1.0} end
            rect(leftX, y, leftW, rowH, bg[1], bg[2], bg[3], 1)
            if is_cur then rect(leftX, y, 7, rowH, 0.02, 0.48, 0.29, 1)
            elseif is_nxt then rect(leftX, y, 7, rowH, 0.03, 0.38, 0.72, 1) end
            line(leftX, y + rowH, leftX + leftW, y + rowH, 1, 0.78, 0.84, 0.90, 1)
            line(leftX + c1, y, leftX + c1, y + rowH, 1, 0.80, 0.86, 0.92, 1)
            line(leftX + c1 + c2, y, leftX + c1 + c2, y + rowH, 1, 0.80, 0.86, 0.92, 1)
            line(leftX + c1 + c2 + c3, y, leftX + c1 + c2 + c3, y + rowH, 1, 0.80, 0.86, 0.92, 1)

            center(font, leftX, y + rowH/2 - 10, c1, e.date_label, 18, 0.05, 0.12, 0.22, 1)
            center(font, leftX + c1, y + rowH/2 - 10, c2, e.time, 17, 0.05, 0.12, 0.22, 1)
            local course_lines, course_size = wrap_two_lines(
                e.code .. " — " .. e.course, bold, c3 - 24, 18, 14)
            local course_y = y + (course_lines[2] and 8 or math.floor((rowH - course_size) / 2))
            bold:write(leftX + c1 + c2 + 12, course_y,
                course_lines[1] or "", course_size, 0.04, 0.12, 0.22, 1)
            if course_lines[2] then
                bold:write(leftX + c1 + c2 + 12, course_y + course_size + 5,
                    course_lines[2], course_size, 0.04, 0.12, 0.22, 1)
            end
            center(font, leftX + c1 + c2 + c3, y + rowH/2 - 10, c4, fit(e.room, font, 17, c4 - 12), 17, 0.05, 0.27, 0.48, 1)
        end
    end

    draw_status_card(rightX, 330, rightW, 220, "NOW  •  CURRENT EXAM", {0.02,0.48,0.29}, cur, true)
    draw_status_card(rightX, 565, rightW, 300, "NEXT  •  UPCOMING EXAM", {0.03,0.38,0.72}, nxt, false)

    rect(0, H - 82, W, 82, 0.02, 0.16, 0.32, 1)
    bold:write(35, H - 57, "UPCOMING SECTIONS", 20, 1, 1, 1, 1)
    local bx = 260
    local shown = math.min(#sections, 6)
    for i = 1, shown do
        local idx = section_index + i - 1
        while idx > #sections do idx = idx - #sections end
        local s = sections[idx]
        local label = fit(s.id or s.name or "", bold, 16, 120)
        local bw = 135
        local active = (idx == section_index)
        rect(bx, H - 66, bw, 45,
            active and 0.99 or 0.05,
            active and 0.72 or 0.25,
            active and 0.10 or 0.45, 1)
        center(bold, bx, H - 54, bw, label, 16,
            active and 0.03 or 1,
            active and 0.12 or 1,
            active and 0.22 or 1, 1)
        bx = bx + bw + 10
    end
    font:write(W - 285, H - 57, "POWERED BY IT CENTER", 18, 1, 1, 1, 1)
end
