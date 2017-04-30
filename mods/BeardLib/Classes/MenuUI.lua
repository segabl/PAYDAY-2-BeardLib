MenuUI = MenuUI or class()
function MenuUI:init(params)
    table.merge(self, params)
    self.type_name = "MenuUI"
    self.layer = self.layer or 200 --Some fucking layer that is higher than most vanilla menus
    self._ws = managers.gui_data:create_fullscreen_workspace()
	self._ws:connect_keyboard(Input:keyboard())
    tweak_data.gui.MOUSE_LAYER = 999999999 --nothing should have a layer that is bigger than mouse tbh
    self._panel = self._ws:panel():panel({
        name = self.name or self.type_name, 
        alpha = 0, layer = self.layer
    })
    self._panel:key_press(callback(self, self, "KeyPressed"))
    self._panel:key_release(callback(self, self, "KeyReleased"))

    self._panel:rect({
        name = "bg",
        halign = "grow",
        valign = "grow",
        visible = self.background_color ~= nil,
        color = self.background_color,
        alpha = self.background_alpha,
    })

    self._help = self._panel:panel({name = "help", alpha = 0, layer = 50, w = self.help_width or 300})
    self._help:rect({
        name = "bg",
        halign ="grow",
        valign ="grow",
        color = self.help_background_color or self.background_color,
        alpha = self.help_background_alpha or self.background_alpha,
    })    
    self._help:text({
        name = "text",
        font = self.help_font or "fonts/font_large_mf",
        font_size = self.help_font_size or 16,
        layer = 2,
        wrap = true,
        word_wrap = true,
        text = "",
        color = self.help_color or Color.black
    })

    self._menus = {}
	if self.visible == true and managers.mouse_pointer then self:enable() end

    BeardLib:AddUpdater("MenuUIUpdate"..tostring(self), function()
        local x,y = managers.mouse_pointer:world_position()
        if self._slider_hold then self._slider_hold:SetValueByMouseXPos(x) end
        self._old_x = x
        self._old_y = y
    end, true)

    local texture = "guis/textures/menuicons"
    FileManager:AddFile("texture", texture, BeardLib.Utils.Path:Combine(BeardLib.config.assets_dir, texture .. ".texture"))
    if self.create_items then self.create_items(self) end
end

function MenuUI:ShowDelayedHelp(item)
    DelayedCalls:Add("ShowItemHelp", self.show_help_time or 1, function()
        if self._highlighted == item then
            help_text = self._help:child("text")
            help_text:set_w(300)
            help_text:set_text(item.help)
            local _,_,w,h  = help_text:text_rect()
            w = math.min(w, 300)
            self._help:set_size(w + 8, h + 8)
            help_text:set_shape(4, 4, w, h)

            local mouse = managers.mouse_pointer:mouse()
            local mouse_p = mouse:parent()
            local bottom_h = (mouse_p:world_bottom() - mouse:world_bottom()) 
            local top_h = (mouse:world_y() - mouse_p:world_y()) 
            local normal_pos = h <= bottom_h or bottom_h >= top_h
            self._help:set_world_left(mouse:world_left() + 7)
            if normal_pos then
                self._help:set_world_y(mouse:world_bottom() - 5)
            else
                self._help:set_world_bottom(mouse:world_y() - 5)
            end
            QuickAnim:Work(self._help, "alpha", 1, "speed", 3)
            self._showing_help = true
        end
    end)
end

function MenuUI:Menu(params)
    params.parent_panel = self._panel
    params.parent = self
    params.menu = self
    local menu = Menu:new(params)
    table.insert(self._menus, menu)
    return menu
end

function MenuUI:Enabled() return self._enabled end

function MenuUI:Enable()
    if self:Enabled() then
        return
    end
	self._panel:set_alpha(1)
	self._enabled = true
    self._mouse_id = self._mouse_id or managers.mouse_pointer:get_id()
	managers.mouse_pointer:use_mouse({
		mouse_move = callback(self, self, "MouseMoved"),
		mouse_press = callback(self, self, "MousePressed"),
		mouse_double_click = callback(self, self, "MouseDoubleClick"),
		mouse_release = callback(self, self, "MouseReleased"),
		id = self._mouse_id
	})
end

function MenuUI:Disable()
    if not self:Enabled() then
        return
    end
	self._panel:set_alpha(0)
	self._enabled = false
	if self._highlighted then self._highlighted:UnHighlight() end
	if self._openlist then self._openlist:hide() end
	managers.mouse_pointer:remove_mouse(self._mouse_id)
end

function MenuUI:RunToggleClbk()
    if self.toggle_clbk then
        self.toggle_clbk(self:Enabled())
    end           
end

function MenuUI:toggle()
    if not self:Enabled() then
        self:enable()
        if self.toggle_clbk then
            self.toggle_clbk(self:Enabled())
        end
    elseif self:ShouldClose() then
        self:disable()
        if self.toggle_clbk then
            self.toggle_clbk(self:Enabled())
        end
    end        
end

function MenuUI:KeyReleased(o, k)
    if not self:Enabled() then
        return
    end
	self._key_pressed = nil
    if self.key_released then
        self.key_release(o, k)
    end
end

function MenuUI:MouseInside()
    for _, menu in pairs(self._menus) do
        if menu:MouseFocused() then
            return true
        end
    end
end

function MenuUI:KeyPressed(o, k)
    self._key_pressed = k
    if self._openlist then
        self._openlist:KeyPressed(o, k)
    end
    if self.toggle_key and k == Idstring(self.toggle_key) then
        self:toggle()
    end
    if not self:Enabled() then
        return
    end
    if self._highlighted and self._highlighted.parent:Visible() then
        self._highlighted:KeyPressed(o, k) 
        return 
    end   
    if self.key_press then
        self.key_press(o, k)
    end
end

function MenuUI:Param(param)
    return self[param]
end

function MenuUI:SetParam(param, value)
    self[param] = value
end

function MenuUI:MouseReleased(o, button, x, y)
	self._slider_hold = nil    
    for _, menu in ipairs(self._menus) do
        if menu:MouseReleased(button, x, y) then
            return
        end
    end
    if self.mouse_release then
        self.mouse_release(o, k)
    end
end

function MenuUI:MouseDoubleClick(o, button, x, y)
	for _, menu in ipairs(self._menus) do
		if menu:MouseDoubleClick(button, x, y) then
            return
		end
	end
    if self.mouse_double_click then
        self.mouse_double_click(button, x, y)
    end
end

function MenuUI:MousePressed(o, button, x, y)
    if self.always_mouse_press then self.always_mouse_press(button, x, y) end
    if self._openlist then
        if self._openlist.parent:Visible() then
            if self._openlist:MousePressed(button, x, y) then
                return
            end
        else
            self._openlist:hide()
        end
    else    
    	for _, menu in ipairs(self._menus) do
            if menu:MouseFocused() then
        		if menu:MousePressed(button, x, y) then
                    return
        		end
            end
    	end
    end
    if self.mouse_press then
        self.mouse_press(button, x, y)
    end
end

function MenuUI:ShouldClose()
	if not self._slider_hold and not self._grabbed_scroll_bar then
		for _, menu in pairs(self._menus) do
            if not menu:ShouldClose() then
                return false
            end
		end
		return true
	end
	return false
end

function MenuUI:MouseMoved(o, x, y)
    if self._showing_help then
        QuickAnim:Stop(self._help)
        self._help:set_alpha(0)
    end
    if self.always_mouse_move then self.always_mouse_move(x, y) end
    if self._openlist then
        if self._openlist.parent:Visible() then
            if self._openlist:MouseMoved(x, y) then
                return
            end
        else
            self._openlist:hide()
        end
    else
        if self._highlighted and not self._highlighted:MouseFocused() and not self._scroll_hold then
            self._highlighted:UnHighlight()
        else
            for _, menu in ipairs(self._menus) do
                if menu:MouseMoved(x, y) then
                    return
                end
            end
        end        
    end
    if self.mouse_move then self.mouse_move(x, y) end
end

function MenuUI:GetMenu(name)
    for _, menu in pairs(self._menus) do
        if menu.name == name then
            return menu
        end
    end
    return false
end

function MenuUI:GetItem(name, shallow)
    for _, menu in pairs(self._menus) do
        if menu.name == name then
            return menu
        elseif not shallow then
            local item = menu:GetItem(name)
            if item and item.name then
                return item
            end
        end
    end
    return false
end

function MenuUI:Focused()
	for _, menu in pairs(self._menus) do
		if menu:Focused() then
            return true
        end
	end
    return false
end

--Deprecated Functions--
function MenuUI:SwitchMenu(menu)
    self._current_menu:SetVisible(false)
    menu:SetVisible(true)
    self._current_menu = menu
end

function MenuUI:NewMenu(params) return self:Menu(params) end
function MenuUI:enable() return self:Enable() end
function MenuUI:disable() return self:Disable() end