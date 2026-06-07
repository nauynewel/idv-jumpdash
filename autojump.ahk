#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  第五人格 跳一跳 自动按压脚本 (AHK v2) — 指示圈可视化版
; ============================================================
;
;  操作说明：
;    F2 = 按住拖动测距（红圈起点 → 青圈终点）松开自动跳
;    F5 = 手动输入毫米数跳
;    F3 = 原地连跳 5 次
;    F6 = 标定（首次必做）
;    F1 = 切换指示圈是否显示
;    F4 = 退出脚本
;
;  标定（F6，只需一次，结果存 autojump.ini 永久保存）：
;    按住 F6 在屏幕上拖一段 → 松开 → 拿尺子量这段屏幕物理长度(mm)。
;    脚本根据「毫米÷像素」算出每像素对应多少毫秒，之后 F2 拖动即可自动换算。
;    ※ 示例：按住 F6 从方块左边缘拖到右边缘（比如 200px），
;      用尺子量屏幕上这两个位置的实际距离（比如 26mm），填入 26。
;    — 换屏幕 / 改分辨率 / 改系统缩放后需要重新标定。
;
;  原理：屏幕物理 1mm = 鼠标按压 7.5ms
; ============================================================

MS_PER_MM := 7.5          ; 每物理毫米对应的按压毫秒数（固定参数）

HOP_COUNT   := 5          ; F3 连跳次数
HOP_HOLD_MS := 7.5        ; F3 每次按压时长（原地最短跳）
HOP_GAP_MS  := 120        ; F3 两跳间隔

INI := A_ScriptDir "\autojump.ini"
MS_PER_PX := Number(IniRead(INI, "calib", "ms_per_px", "0"))

CIRCLE_D := 28            ; 指示圈直径（像素）

; ==================================================================
;  指示圈 GUI 创建
; ==================================================================

MakeCircleRegion(w, h, margin := 2) {
    cx := w / 2, cy := h / 2, r := Max(Min(cx, cy) - margin, 1)
    pts := ""
    loop 72 {
        rad := (A_Index - 1) * 6.283185307 / 72
        pts .= Format("{:d}-{:d} ", Round(cx + r * Cos(rad)), Round(cy + r * Sin(rad)))
    }
    return RTrim(pts)
}

rgn := MakeCircleRegion(CIRCLE_D, CIRCLE_D)

; 起点圆圈（红色，半透明）
gStart := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
gStart.BackColor := "FF2222"
gStart.Show("NA x-100 y-100 w" CIRCLE_D " h" CIRCLE_D)  ; 先离屏创建以获取有效 Hwnd
WinSetRegion(rgn, "ahk_id " gStart.Hwnd)
WinSetTransparent(200, "ahk_id " gStart.Hwnd)
gStart.Hide()

; 终点圆圈（青色，半透明）
gEnd := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
gEnd.BackColor := "00EEFF"
gEnd.Show("NA x-100 y-100 w" CIRCLE_D " h" CIRCLE_D)
WinSetRegion(rgn, "ahk_id " gEnd.Hwnd)
WinSetTransparent(200, "ahk_id " gEnd.Hwnd)
gEnd.Hide()

; 拖拽状态
drag_sx := 0, drag_sy := 0
showCircle := true          ; F1 切换

HideCircles() {
    gStart.Hide()
    gEnd.Hide()
}

; 实时更新终点圆圈 + 距离提示
UpdateDragUI() {
    global gEnd, CIRCLE_D, drag_sx, drag_sy, MS_PER_PX
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    gEnd.Show("x" (mx - CIRCLE_D // 2) " y" (my - CIRCLE_D // 2) " NoActivate")
    px := Sqrt((mx - drag_sx) ** 2 + (my - drag_sy) ** 2)
    ms := px * MS_PER_PX
    ToolTip("距离 " Round(px, 1) " px  →  按压 " Round(ms, 1) " ms")
}

; ==================================================================
;  启动提示
; ==================================================================

MsgBox("跳一跳 · 指示圈版 (AHK " A_AhkVersion ")`n`n"
     . "F2 = 按住拖动（红圈•起点 → 青圈•终点）松开跳`n"
     . "F5 = 手动输入毫米跳`n"
     . "F3 = 原地连跳 " HOP_COUNT " 次`n"
     . "F6 = 标定（首次必做）`n"
     . "F1 = 显示/隐藏指示圈`n"
     . "F4 = 退出`n`n"
     . (MS_PER_PX > 0 ? "当前标定 " Round(MS_PER_PX, 4) " ms/px" : "⚠ 尚未标定，F2 前请先按 F6"),
       "加载成功", "Iconi")

; ==================================================================
;  F2：按住拖动测距（可视化指示圈）→ 松开自动按压
; ==================================================================
F2:: {
    global MS_PER_PX, gStart, gEnd, CIRCLE_D, drag_sx, drag_sy, showCircle

    if (MS_PER_PX <= 0) {
        MsgBox("请先按 F6 完成标定。", "未标定", "Iconx")
        return
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&drag_sx, &drag_sy)

    if (showCircle) {
        gStart.Show("x" (drag_sx - CIRCLE_D // 2) " y" (drag_sy - CIRCLE_D // 2) " NoActivate")
        gEnd.Show("x" (drag_sx - CIRCLE_D // 2) " y" (drag_sy - CIRCLE_D // 2) " NoActivate")
        SetTimer(UpdateDragUI, 16)    ; ~60fps 更新
    }

    KeyWait("F2")
    Sleep(50)   ; 等 F2 松开事件完全被系统消化，防止与鼠标事件冲突

    SetTimer(UpdateDragUI, 0)
    MouseGetPos(&ex, &ey)
    HideCircles()
    ToolTip()

    px := Sqrt((ex - drag_sx) ** 2 + (ey - drag_sy) ** 2)
    if (px < 3) {
        ToolTip("距离太短，已取消")
        Sleep(600)
        ToolTip()
        return
    }
    ms := px * MS_PER_PX
    ToolTip("拖动 " Round(px, 1) " px  →  按压 " Round(ms, 2) " ms")
    Sleep(150)
    ToolTip()
    HoldClick(ms)
}

; ==================================================================
;  F5：手动输入毫米数跳（后备方案，不依赖标定）
; ==================================================================
F5:: {
    ib := InputBox("输入两块中心之间的距离（毫米，可带小数）", "手动测距", "w300 h130", "")
    if (ib.Result != "OK")
        return
    mm := ib.Value
    if !IsNumber(mm) || (mm + 0) <= 0 {
        MsgBox("请输入大于 0 的数字", "输入无效", "Iconx")
        return
    }
    ms := (mm + 0) * MS_PER_MM
    ToolTip("距离 " mm " mm  →  按压 " Round(ms, 2) " ms")
    Sleep(150)
    ToolTip()
    HoldClick(ms)
}

; ==================================================================
;  F3：原地连续弹跳（刷加分道具 / 微调位置）
; ==================================================================
F3:: {
    loop HOP_COUNT {
        ToolTip("原地弹跳 " A_Index "/" HOP_COUNT)
        HoldClick(HOP_HOLD_MS)
        if (A_Index < HOP_COUNT)
            Sleep(HOP_GAP_MS)
    }
    ToolTip()
}

; ==================================================================
;  F6：标定（像素 → 毫秒）
; ==================================================================
F6:: {
    global MS_PER_PX
    ToolTip("标定中：按住 F6 从一点拖到另一点，松开后输入毫米数")
    MouseGetPos(&x1, &y1)
    KeyWait("F6")
    MouseGetPos(&x2, &y2)
    ToolTip()
    px := Sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)
    if (px < 10) {
        MsgBox("拖动太短（" Round(px, 1) " px），按住 F6 拖长一点更准。", "标定失败", "Iconx")
        return
    }
    ib := InputBox("你刚在屏幕上拖了 " Round(px) " 像素。`n`n用直尺量这段距离的屏幕物理长度，是多少毫米？`n`n（比如拖了从方块左边到右边，用尺子量屏幕`n上这两个位置的实际距离）", "标定 - 像素→毫米换算", "w380 h180", "")
    if (ib.Result != "OK")
        return
    mm := ib.Value
    if !IsNumber(mm) || (mm + 0) <= 0 {
        MsgBox("请输入大于 0 的毫米数", "输入无效", "Iconx")
        return
    }
    MS_PER_PX := (mm + 0) * MS_PER_MM / px
    IniWrite(MS_PER_PX, INI, "calib", "ms_per_px")
    MsgBox("标定完成 ✔`n`n"
         . "拖动像素 " Round(px, 1) "`n"
         . "物理毫米 " mm "`n"
         . "换算结果 " Round(MS_PER_PX, 4) " ms/像素`n`n"
         . "已保存到 autojump.ini，下次启动自动读取。",
           "标定", "Iconi")
}

; ==================================================================
;  F1：切换指示圈是否显示
; ==================================================================
F1:: {
    global showCircle
    showCircle := !showCircle
    ToolTip(showCircle ? "指示圈：显示" : "指示圈：隐藏")
    Sleep(800)
    ToolTip()
    if (!showCircle)
        HideCircles()
}

; ==================================================================
;  F4：退出
; ==================================================================
F4:: ExitApp()

; ==================================================================
;  高精度按压：按下左键 → 忙等指定毫秒 → 松开
;  SendInput 发按键事件 + QPC 忙等计时 + timeBeginPeriod 提升精度
; ==================================================================
HoldClick(durationMs) {
    static freq := 0
    if (freq = 0)
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)

    ; 用 Click("Down/Up")——这是你最开始能正常跳出去的版本用的方式
    Click("Down")

    if (freq > 0) {
        targetTicks := durationMs / 1000 * freq
        start := 0
        DllCall("QueryPerformanceCounter", "Int64*", &start)
        startTick := A_TickCount
        loop {
            now := 0
            DllCall("QueryPerformanceCounter", "Int64*", &now)
            if (now - start >= targetTicks)
                break
            if (A_TickCount - startTick > durationMs + 50)   ; 兜底超时
                break
        }
    } else {
        Sleep(Round(durationMs))
    }

    Click("Up")
}
