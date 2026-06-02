local fn = vim.fn

local CompletionItemKind = vim.lsp.protocol.CompletionItemKind
local InsertTextFormat = vim.lsp.protocol.InsertTextFormat

---@class blink_emmet_vim.Options
---@field public filetypes string[]

---@type blink_emmet_vim.Options
local defaults = {
    filetypes = {
        "html",
        "xml",
        "typescriptreact",
        "javascriptreact",
        "css",
        "sass",
        "scss",
        "less",
        "heex",
        "tsx",
        "jsx",
    },
}

--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

---Returns the filetype at the cursor, using tree-sitter if available
---@return unknown
local function get_file_type ()
    local ok, parser = pcall(vim.treesitter.get_parser)
    if not ok then
        return vim.bo.filetype
    end
    local cursor = vim.api.nvim_win_get_cursor(0)
    local range_parser = parser:language_for_range({ cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2] })
    local lang = range_parser:lang()
    if lang == "html" then
        local ok_node, node = pcall(vim.treesitter.get_node)
        if ok_node and node and node:type() == "style_element" then
            return "css"
        end
    end
    return lang
end

---Gets the last non-whitespace character sequence from current cursor
---@param line string current line text
---@param col integer 0-indexed byte column of the cursor
---@param filetype string filetype resolved for the cursor
---@return string?
local function get_last_word (line, col, filetype)
    local current_word = line:sub(1, col):match("%S+$")
    if current_word == nil then
        return nil
    end
    local type = filetype or fn["emmet#getFileType"]()
    local ok, rtype = pcall(fn["emmet#lang#type"], type)
    if not ok then
        return
    end
    local part = fn["emmet#lang#" .. rtype .. "#findTokens"](current_word)
    return part
end

---Gets the emmet string to be expanded
---@param line string current line text
---@param col integer 0-indexed byte column of the cursor
---@param filetype string filetype resolved for the cursor
---@return string?
local function emmet_complete (line, col, filetype)
    local last_word = get_last_word(line, col, filetype)
    local type = filetype or fn["emmet#getFileType"]()
    local ok1, rtype = pcall(fn["emmet#lang#type"], type)
    if not ok1 then
        return
    end
    local ok2, tree = pcall(fn["emmet#parseIntoTree"], last_word, rtype)
    if not ok2 then
        return
    end
    local tree_view = tree.child[1]
    local indentation = fn["emmet#getIndentation"](type)
    local ok3, string_view = pcall(fn["emmet#toString"], tree_view, type, 0, { type }, 0, indentation)
    return ok3 and string_view or nil
end

---Builds the snippet
---@param text string
---@return string
local function build_snippet (text)
    local n = 0
    local snippet = text:gsub("%$%{([^}]+)%}", function (placeholder)
        if placeholder == "cursor" then
            -- We can't use $0 here, because there can be multiple $cursor placeholders
            n = n + 1
            return "$" .. n
        elseif vim.startswith(placeholder, "lorem") then
            local lorem = fn["emmet#lorem#en#expand"](placeholder)
            return string.format("%s", lorem)
        else
            -- Sometimes emmet uses numbered placeholders, which we want to remove
            placeholder = placeholder:gsub("%d+:", "")
            n = n + 1
            return string.format("${%d:%s}", n, placeholder)
        end
    end)
    -- Remove trailing empty line
    snippet = snippet:gsub("\n+$", "")
    return snippet
end

---`opts` comes from `sources.providers.<provider>.opts`
---@param opts blink_emmet_vim.Options
function source.new (opts)
    local self = setmetatable({}, { __index = source })
    self.opts = vim.tbl_deep_extend("keep", opts or {}, defaults)
    vim.validate("blink-emmet-vim.opts.filetypes", self.opts.filetypes, "table")
    return self
end

function source:enabled ()
    return vim.g.loaded_emmet_vim == 1 and vim.tbl_contains(self.opts.filetypes, get_file_type())
end

function source:get_trigger_characters ()
    return { ".", "#", ">", "+", "*", "(", ")", "[", "]", "{", "}", "/", ":" }
end

function source:get_completions (ctx, callback)
    local function transformed_callback (items)
        callback({
            items = items,
            -- Emmet expansion depends on the whole abbreviation, so re-query the
            -- source on every keystroke instead of letting blink reuse the cache.
            is_incomplete_backward = true,
            is_incomplete_forward = true,
        })
    end

    -- ctx.cursor is `{ row (1-indexed), col (0-indexed byte) }`.
    local line = ctx.line
    local col = ctx.cursor[2]
    -- Resolve the filetype once and thread it through, instead of letting each
    -- helper re-run the tree-sitter lookup.
    local filetype = get_file_type()

    local ok, word = pcall(get_last_word, line, col, filetype)

    if not ok or not word or word == "" then
        return transformed_callback({})
    end

    local text = emmet_complete(line, col, filetype)

    if not text then
        return transformed_callback({})
    end

    local snippet = build_snippet(text)

    if not snippet or snippet == "" then
        return transformed_callback({})
    end

    -- LSP ranges are 0-indexed and end-exclusive.
    local range = {
        ["start"] = { line = ctx.cursor[1] - 1, character = col - #word },
        ["end"] = { line = ctx.cursor[1] - 1, character = col },
    }

    --- @type lsp.CompletionItem
    local item = {
        label = word,
        filterText = word,
        kind = CompletionItemKind.Snippet,
        insertTextFormat = InsertTextFormat.Snippet,
        textEdit = {
            newText = snippet,
            range = range,
        },
    }

    transformed_callback({ item })

    return function () end
end

function source:resolve (item, callback)
    item = vim.deepcopy(item)

    local documentation = {}
    local repr = item.textEdit.newText
    local lines = vim.split(repr, "\n", { plain = true })

    table.insert(documentation, "```" .. vim.bo.ft)
    for _, line in ipairs(lines) do
        table.insert(documentation, line)
    end
    table.insert(documentation, "```")

    item.documentation = {
        kind = "markdown",
        value = table.concat(documentation, "\n"),
    }

    callback(item)
end

return source
