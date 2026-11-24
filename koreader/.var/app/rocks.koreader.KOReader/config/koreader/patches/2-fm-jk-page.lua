-- 选书界面（文件管理器）里用 j/k 翻页。只影响 FileChooser，其它菜单不变。
local Menu = require("ui/widget/menu")

local orig_onSelectByShortCut = Menu.onSelectByShortCut

function Menu:onSelectByShortCut(ev, keyevent)
    local key = keyevent and keyevent.key
    -- path_items 只有 FileChooser 有，用它把范围限制在选书界面
    if self.path_items and (key == "J" or key == "K") then
        local page_num = self.page_num or 1
        local page
        if key == "J" then
            page = self.page < page_num and self.page + 1 or nil
        else
            page = self.page > 1 and self.page - 1 or nil
        end
        if page then return self:onGotoPage(page) end
        return true -- 已到首/末页：吃掉按键，不循环
    end
    return orig_onSelectByShortCut(self, ev, keyevent)
end
