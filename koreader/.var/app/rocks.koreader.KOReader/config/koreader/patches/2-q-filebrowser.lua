-- 阅读界面按 q 回到文件列表（等同 Home 键、Dispatcher 里的 File browser）。
-- Flatpak 版路径：
--   ~/.var/app/rocks.koreader.KOReader/config/koreader/patches/2-q-filebrowser.lua
-- 文件名前缀只能用 0/1/2/8/9：KOReader 只按这几个优先级调用补丁加载器，3-7 不会被加载。
-- 位置会保存；想换键改 KEY 后重启 KOReader 生效。
local ReaderUI = require("apps/reader/readerui")
local Event = require("ui/event")

local KEY = "Q"

if ReaderUI._q_filebrowser_patched then return end
ReaderUI._q_filebrowser_patched = true

local orig_register_key_events = ReaderUI.registerKeyEvents

function ReaderUI:registerKeyEvents()
    orig_register_key_events(self)
    self.key_events.ShowFileBrowser = { { KEY } }
end

ReaderUI.onPhysicalKeyboardConnected = ReaderUI.registerKeyEvents

function ReaderUI:onShowFileBrowser()
    self:handleEvent(Event:new("Home"))
    return true
end
