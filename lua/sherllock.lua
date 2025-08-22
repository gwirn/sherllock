vim.api.nvim_set_hl(0, "BashWarningSignHL", {
    fg = "#b55f0e",
    bg = "NONE",
})
vim.api.nvim_set_hl(0, "BashErrorSignHL", {
    fg = "#d91115",
    bg = "NONE",
})
vim.api.nvim_set_hl(0, "BashInfoSignHL", {
    fg = "#a6a2a3",
    bg = "NONE",
})
vim.api.nvim_set_hl(0, "SherllockHL", {
    underline = true,
    sp = "#00ff00",
})


vim.fn.sign_define("BashErrorSign", { text = "E>", texthl = "BashErrorSignHL", numhl = "BashErrorSignHL" })
vim.fn.sign_define("BashWarningSign", { text = "W>", texthl = "BashWarningSignHL", numhl = "BashWarningSignHL" })
vim.fn.sign_define("BashInfoSign", { text = "I>", texthl = "BashInfoSignHL", numhl = "BashInfoSignHL" })
local sign_dict = { ["E"] = "BashErrorSign", ["W"] = "BashWarningSign", ["I"] = "BashInfoSign" }

local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
if vim.fn.isdirectory(mason_bin) ~= 0 and not vim.env.PATH:find(vim.pesc(mason_bin)) then
    vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
end

local function update_sign(qf_list, buf_num)
    vim.fn.sign_unplace("ShellSignGroup", { buffer = buf_num })
    if vim.v.shell_error ~= 0 then
        for i, diag in ipairs(qf_list) do
            local sign_name = sign_dict[diag.type]
            if sign_name then
                vim.fn.sign_place(0, "ShellSignGroup", sign_name, buf_num, { lnum = diag.lnum })
            end
        end
    end
end

local function highlight_error(row, col, bufnr)
    local parser = vim.treesitter.get_parser(bufnr)
    local tree = parser:parse()[1]
    local root = tree:root()

    local node = root:descendant_for_range(row, col, row, col)
    if not node then return nil end

    local text_len = vim.treesitter.get_node_text(node, bufnr):len()
    vim.api.nvim_buf_set_extmark(bufnr, vim.api.nvim_create_namespace("SherllockErrorUnderline"), row, col, {
        end_col = col + text_len,
        hl_group = "SherllockHL",
    })
end

local function parse_shellcheck(output, buf_num)
    local file = vim.api.nvim_buf_get_name(buf_num)
    local qf_list = {}
    for _, line in ipairs(output) do
        local lnum, col, typ, msg = line:match("(%d+):(%d+): ([^:]+): (.+)")
        if file and lnum and col and typ and msg then
            table.insert(qf_list, {
                filename = file,
                lnum = tonumber(lnum),
                col = tonumber(col),
                text = typ .. ": " .. msg,
                type = typ:sub(1, 1):upper(),
            })
        end
    end
    update_sign(qf_list, buf_num)
    return qf_list
end

local function shfmt_on_buf(buf_num)
    local lines = vim.api.nvim_buf_get_lines(buf_num, 0, -1, false)
    local content = table.concat(lines, "\n")
    local output = vim.fn.systemlist("shfmt - ", content)
    vim.api.nvim_buf_set_lines(buf_num, 0, -1, false, output)
end

local function shellcheck_on_buf(buf_num)
    local lines = vim.api.nvim_buf_get_lines(buf_num, 0, -1, false)
    local content = table.concat(lines, "\n")
    local output = vim.fn.systemlist({
        "shellcheck",
        "--format=gcc",
        "-",
    }, content)
    return output
end

local M = {}
M.check = function()
    local bufnr = vim.api.nvim_get_current_buf()
    shellcheck_on_buf(bufnr)
end
M.format = function()
    local bufnr = vim.api.nvim_get_current_buf()
    shfmt_on_buf(bufnr)
end
M.setup = function()
    vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "*.sh",
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local output = shellcheck_on_buf(bufnr)
            local qf_list = parse_shellcheck(output, bufnr)
            if vim.v.shell_error ~= 0 then
                vim.fn.setqflist(qf_list, 'r')
                vim.cmd.copen()
            else
                vim.fn.setqflist({}, 'r')
                vim.cmd.cclose()
                shfmt_on_buf(bufnr)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
        pattern = "*.sh",
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local output = shellcheck_on_buf(bufnr)
            local qf_list = parse_shellcheck(output, bufnr)
            update_sign(qf_list, bufnr)
            local ns_id = vim.api.nvim_create_namespace("SherllockErrorUnderline")
            vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
            if #table ~= 0 then
                for _, elem in ipairs(qf_list) do
                    highlight_error(elem.lnum - 1, elem.col - 1, bufnr)
                end
            end
        end,
    })

    vim.api.nvim_create_autocmd("QuitPre", {
        pattern = "*.sh",
        callback = function()
            vim.cmd.cclose()
        end
    })
end

return M
