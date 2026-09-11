local fg = "#e6e1d5"
local bg = "#212221"

return {
  normal = {
    a = { fg = bg, bg = "#7fc8a6", gui = "bold" },
    b = { fg = fg, bg = "#3a3a3a" },
    c = { fg = fg, bg = "#292929" },
  },
  insert = { a = { fg = bg, bg = "#8dbce6", gui = "bold" } },
  visual = { a = { fg = bg, bg = "#e99bc2", gui = "bold" } },
  replace = { a = { fg = bg, bg = "#e89494", gui = "bold" } },
  command = { a = { fg = bg, bg = "#e6cc77", gui = "bold" } },
  terminal = { a = { fg = bg, bg = "#67d4e8", gui = "bold" } },
}
