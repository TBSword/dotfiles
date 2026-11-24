-- 关掉阅读界面里 A/S/D(+Shift) 那组缩放快捷键（按 d 会变成"适应页面高度"）。
-- 默认只保留 Shift+PgUp/PgDn 的放大/缩小；想把哪个键要回来，把 KEEP 里对应项改成 true。
--
-- 放在 KOReader 数据目录的 patches/ 下，Flatpak 版即：
--   ~/.var/app/rocks.koreader.KOReader/config/koreader/patches/2-zoom-keys.lua
-- 改完重启 KOReader 生效；出问题就删掉这个文件。
local ok, ReaderZooming = pcall(require, "apps/reader/modules/readerzooming")
if not ok or not ReaderZooming then return end

local KEEP = {
    ZoomIn                 = true,  -- Shift+PgDn  放大
    ZoomOut                = true,  -- Shift+PgUp  缩小
    ZoomToFitPage          = false, -- A           适应页面
    ZoomToFitContent       = false, -- Shift+A     适应内容
    ZoomToFitPageWidth     = false, -- S           适应页面宽度
    ZoomToFitContentWidth  = false, -- Shift+S     适应内容宽度
    ZoomToFitPageHeight    = false, -- D           适应页面高度（就是它把 d 抢走了）
    ZoomToFitContentHeight = false, -- Shift+D     适应内容高度
    ZoomManual             = false, -- Shift+M     手动缩放
}

-- 防止补丁被重复执行时套娃
if ReaderZooming._zoom_keys_patched then return end
ReaderZooming._zoom_keys_patched = true

local orig_register_key_events = ReaderZooming.registerKeyEvents

function ReaderZooming:registerKeyEvents()
    orig_register_key_events(self)
    if not self.key_events then return end
    for name, keep in pairs(KEEP) do
        if not keep then
            self.key_events[name] = nil
        end
    end
end

-- 模块加载时 onPhysicalKeyboardConnected 只是 registerKeyEvents 的别名，
-- 这里要重新指向包装后的版本，否则运行中接上实体键盘会把这些键又装回来。
ReaderZooming.onPhysicalKeyboardConnected = ReaderZooming.registerKeyEvents
