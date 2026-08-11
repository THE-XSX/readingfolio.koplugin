local DataStorage = require("datastorage")
local datetime = require("datetime")
local Device = require("device")
local lfs = require("libs/libkoreader-lfs")
local SQ3 = require("lua-ljsqlite3/init")
local util = require("util")
local T = require("ffi/util").template

local Data = {}
Data.__index = Data

function Data.new(constants, translate)
    return setmetatable({
        constants = assert(constants),
        translate = assert(translate),
    }, Data)
end

local function localizedDayName(timestamp, translate)
    local key = timestamp and os.date("%A", timestamp)
    if not key then return "" end
    return translate(key)
end

local function durationText(seconds, translate)
    if not seconds then return translate("calculating time") end
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours == 0 and minutes == 0 then return translate("less than a minute") end

    local parts = {}
    if hours > 0 then
        table.insert(parts, string.format("%d %s", hours, hours == 1 and translate("hr") or translate("hrs")))
    end
    if minutes > 0 then
        table.insert(parts, string.format("%d %s", minutes, minutes == 1 and translate("min") or translate("mins")))
    end
    return table.concat(parts, " ")
end

local function bookDurations(statistics, ui)
    if not statistics or (statistics.isEnabled and not statistics:isEnabled()) then
        return 0, 0
    end
    if statistics.insertDB then pcall(statistics.insertDB, statistics) end

    local db_path = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
    if lfs.attributes(db_path, "mode") ~= "file" then return 0, 0 end
    local ok, connection = pcall(SQ3.open, db_path)
    if not ok or not connection then return 0, 0 end

    local id_book = statistics.id_curr_book
    if not id_book and statistics.getIdBookDB then
        local id_ok, id = pcall(statistics.getIdBookDB, statistics)
        if id_ok then id_book = id end
    end
    if not id_book and ui and ui.doc_props then
        local title = ui.doc_props.display_title or ""
        if title ~= "" then
            local sql = string.format("SELECT id FROM book WHERE title = %s LIMIT 1", SQ3.quote(title))
            local row_ok, id = pcall(function() return connection:rowexec(sql) end)
            if row_ok then id_book = tonumber(id) end
        end
    end

    local total, today = 0, 0
    if id_book then
        local total_sql = string.format([[
            SELECT sum(sum_duration) FROM (
                SELECT sum(duration) AS sum_duration
                FROM page_stat WHERE id_book = %d GROUP BY page
            );
        ]], id_book)
        local total_ok, value = pcall(function() return connection:rowexec(total_sql) end)
        if total_ok then total = tonumber(value) or 0 end
        if total == 0 then total = tonumber(statistics.curr_book_read_time) or 0 end

        local today_sql = string.format([[
            SELECT sum(duration) FROM page_stat
            WHERE id_book = %d
              AND date(start_time, 'unixepoch', 'localtime') = date('now', 'localtime');
        ]], id_book)
        local today_ok, today_value = pcall(function() return connection:rowexec(today_sql) end)
        if today_ok then today = tonumber(today_value) or 0 end
    end
    connection:close()

    if statistics.page_stat and statistics.curr_page then
        local page = statistics.page_stat[statistics.curr_page]
        local tuple = page and page[#page]
        if tuple and tuple[1] and (not tuple[2] or tuple[2] == 0) then
            local active = os.time() - tuple[1]
            if active > 0 and active <= 3600 then
                total = total + active
                today = today + active
            end
        end
    end
    return math.max(0, total), math.max(0, today)
end

local function randomHighlight(ui)
    local annotations = ui and ui.annotation and ui.annotation.annotations
    if not annotations then return nil end
    local candidates = {}
    for _, item in ipairs(annotations) do
        if item.drawer and item.text and util.trim(item.text) ~= "" then
            table.insert(candidates, item)
        end
    end
    return #candidates > 0 and candidates[math.random(#candidates)] or nil
end

local function batteryText()
    if not Device:hasBattery() then
        return "100%"
    end
    local power = Device:getPowerDevice()
    if not power then
        return "100%"
    end
    local ok_cap, level = pcall(function() return power:getCapacity() end)
    level = (ok_cap and level) or 0
    local is_charging = false
    if power.isCharging then
        local ok_chg, chg = pcall(function() return power:isCharging() end)
        if ok_chg and chg then is_charging = true end
    end
    local symbol = is_charging and "+" or ""
    return tostring(level) .. "%" .. symbol
end

function Data:collect(ui, state)
    if not ui or not ui.document then return nil end
    local K, tr = self.constants, self.translate
    local settings = G_reader_settings
    local props = ui.doc_props or {}
    local title = props.display_title or ""
    local author = props.authors or ""
    if author:find("\n") then
        local authors = util.splitToArray(author, "\n")
        if authors and authors[1] then author = T(tr("%1 et al."), authors[1]) end
    end

    local doc_settings = ui.doc_settings and ui.doc_settings.data or {}
    local page = (state and state.page) or 1
    local pages = math.max(tonumber(doc_settings.doc_pages) or 1, 1)
    page = math.max(1, math.min(page, pages))
    local page_number, page_total = page, pages
    local page_label, total_label = tostring(page), tostring(pages)
    if ui.pagemap and ui.pagemap:wantsPageLabels() then
        local label, index, count = ui.pagemap:getCurrentPageLabel(true)
        local last = ui.pagemap:getLastPageLabel(true)
        if index and count then page_number, page_total = index, count end
        page_label = label and label ~= "" and label or tostring(page_number)
        total_label = last and last ~= "" and last or tostring(page_total)
    end

    local chapter, chapter_total, chapter_done, chapter_left = "", page_total, 1, 0
    if ui.toc then
        chapter = ui.toc:getTocTitleByPage(page) or ""
        chapter_total = ui.toc:getChapterPageCount(page) or chapter_total
        chapter_left = ui.toc:getChapterPagesLeft(page) or 0
        chapter_done = math.max((ui.toc:getChapterPagesDone(page) or 0) + 1, 1)
    end
    chapter_total = math.max(chapter_total, 1)

    local show = {
        title = settings:nilOrTrue(K.SHOW_TITLE),
        author = settings:nilOrTrue(K.SHOW_AUTHOR),
        cover = settings:nilOrTrue(K.SHOW_COVER),
        chapter = settings:nilOrTrue(K.SHOW_CHAPTER),
        page_number = settings:nilOrTrue(K.SHOW_PAGE_NUMBER),
        percentage = settings:nilOrTrue(K.SHOW_PERCENTAGE),
        progress_bar = settings:nilOrTrue(K.SHOW_PROGRESS_BAR),
        chapter_time_left = settings:nilOrTrue(K.SHOW_CHAPTER_TIME_LEFT),
        book_time_left = settings:nilOrTrue(K.SHOW_BOOK_TIME_LEFT),
        total_time = settings:nilOrTrue(K.SHOW_TOTAL_TIME),
        today_time = settings:nilOrTrue(K.SHOW_TODAY_TIME),
        battery = settings:nilOrTrue(K.SHOW_BATTERY),
        clock = settings:nilOrTrue(K.SHOW_CLOCK),
        highlights = settings:nilOrTrue(K.SHOW_HIGHLIGHTS),
        custom_message = settings:nilOrTrue(K.SHOW_CUSTOM_MESSAGE),
    }

    local statistics = ui.statistics
    local average = statistics and statistics.avg_time
    local total_duration, today_duration = bookDurations(statistics, ui)
    local chapter_time_left_seconds = average and average * chapter_left or nil
    local book_time_left_seconds = average and average * math.max(page_total - page_number, 0) or nil

    local mode = settings:readSetting(K.CONTENT_MODE_SETTING) or K.CONTENT_MODE_READING_FOLIO
    if mode == K.CONTENT_MODE_RANDOM then
        mode = math.random(2) == 1 and K.CONTENT_MODE_READING_FOLIO or K.CONTENT_MODE_HIGHLIGHT_PROGRESS
    end

    local expanded_message = util.trim(settings:readSetting("screensaver_message") or "")
    if expanded_message ~= "" and ui.bookinfo and ui.bookinfo.expandString then
        expanded_message = util.trim(ui.bookinfo:expandString(expanded_message) or expanded_message)
    end
    if expanded_message == "" then expanded_message = nil end

    local raw_highlight = randomHighlight(ui)
    local highlight = show.highlights and raw_highlight or nil
    local percentage = math.floor(math.max(0, math.min(page_number / math.max(page_total, 1), 1)) * 100 + 0.5)
    local now = datetime.secondsToHour(os.time(), settings:isTrue("twelve_hour_clock")) or os.date("%H:%M")
    local battery_text = batteryText()
    local chapter_time_text = durationText(chapter_time_left_seconds, tr)
    local book_time_text = durationText(book_time_left_seconds, tr)
    local total_time_text = string.format(tr("Total time spent: %s"), durationText(total_duration, tr))
    local today_time_text = string.format(tr("Time spent today (%s): %s"), localizedDayName(os.time(), tr), durationText(today_duration, tr))

    return {
        ui = ui,
        title = show.title and title or "",
        author = show.author and author or "",
        chapter = show.chapter and chapter or "",
        page = page_number,
        pages = page_total,
        page_label = show.page_number and page_label or "",
        pages_label = show.page_number and total_label or "",
        percentage = percentage,
        chapter_done = chapter_done,
        chapter_total = chapter_total,
        chapter_time_left = show.chapter_time_left and chapter_time_text or nil,
        book_time_left = show.book_time_left and book_time_text or nil,
        chapter_time_left_seconds = chapter_time_left_seconds,
        book_time_left_seconds = book_time_left_seconds,
        total_duration = total_duration,
        today_duration = today_duration,
        total_time_text = show.total_time and total_time_text or nil,
        today_time_text = show.today_time and today_time_text or nil,
        battery = show.battery and battery_text or "",
        -- Unconditional reading for styles whose layout always renders a
        -- power slot (architecture/bookpost/dossier); the display toggle
        -- only governs the removable `battery` field above.
        battery_text = battery_text,
        clock = show.clock and now or "",
        highlight = highlight,
        message = Device.screen_saver_mode and show.custom_message
            and settings:isTrue("screensaver_show_message") and expanded_message or nil,
        content_mode = mode,
        show = show,
        custom = {
            title = title,
            author = author,
            chapter = chapter,
            page_number = string.format("%s / %s", page_label, total_label),
            percentage = percentage,
            percentage_text = string.format("%d%%", percentage),
            chapter_time_left = chapter_time_text,
            book_time_left = book_time_text,
            total_time = total_time_text,
            today_time = today_time_text,
            battery = battery_text,
            clock = now,
            highlight = raw_highlight,
            custom_message = expanded_message,
        },
    }
end

return Data
