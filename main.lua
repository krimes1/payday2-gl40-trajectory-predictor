-- GL40 Trajectory Predictor v1.0 - calibrated against GL40 Physics Logger v1.1.
-- The flight is estimated, not a guarantee of the engine's impact point.
_G.GL40Tracker = _G.GL40Tracker or {kills=0, enabled=false}
local tracker = _G.GL40Tracker
local CFG = {
    speed=2500, gravity=981, drag=0.005, vertical_boost=125,
    fuse=2.0, step=0.0125, muzzle_forward=0, marker_radius=16,
    recalc_interval=0.04, continuation_step=0.025, continuation_seconds=3.0,
    -- Temporary: emit at most one compact path diagnostic per second.
    debug_path=true
}
local segments, terminal, distance, state, terminal_type, continuation, ground_point = {}, nil, nil, 'WAIT', nil, {}, nil
local last_calc=-100
local last_debug=-100
local label

local function hud_label()
    if alive(label) then return label end
    if not (managers.hud and PlayerBase and tweak_data and tweak_data.menu) then return nil end
    local hud=managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2)
    local panel=hud and hud.panel
    if not alive(panel) then return nil end
    label=panel:text({name='gl40_predictor_v10',text='',
        font=tweak_data.menu.pd2_small_font,font_size=18,
        color=Color.white,align='center',vertical='center',
        w=600,h=52,layer=100,visible=false})
    label:set_center(panel:w()/2,panel:h()*0.69)
    return label
end

local function collision_mask()
    if not managers.slot then return nil end
    -- Prefer static level geometry: bullet masks may include dynamic/non-solid objects.
    local ok,mask=pcall(function() return managers.slot:get_mask('world_geometry') end)
    return ok and mask or nil
end

local function predict(origin,forward)
    local mask=collision_mask()
    if not mask then return {},nil,nil,'NO MASK',nil,{},nil end
    -- Logger: physical speed ~2500, vertical acceleration ~-981,
    -- slight horizontal damping and ~+125 vertical launch offset.
    local p=origin+forward*CFG.muzzle_forward
    local v=forward*CFG.speed+Vector3(0,0,CFG.vertical_boost)
    local lines={}
    local steps=math.floor(CFG.fuse/CFG.step+0.5)
    for i=1,steps do
        local dt=CFG.step
        local q=p+v*dt+Vector3(0,0,-0.5*CFG.gravity*dt*dt)
        local ray=World:raycast('ray',p,q,'slot_mask',mask)
        local endpoint=ray and ray.position or q
        lines[#lines+1]={p,endpoint}
        if ray then
            return lines,endpoint,(endpoint-origin):length()/100,'IMPACT (estimated)','collision',{},nil
        end
        p=q
        v=Vector3(v.x*(1-CFG.drag*dt),v.y*(1-CFG.drag*dt),
                  v.z-CFG.gravity*dt)
    end
    -- No contact: fuse endpoint is not an impact marker.
    -- The grenade is expected to explode at p. Any following arc is only a
    -- hypothetical, dashed ground projection, never part of the real flight.
    local projected={}
    local ground=nil
    for i=1,math.floor(CFG.continuation_seconds/CFG.continuation_step) do
        local dt=CFG.continuation_step
        local q=p+v*dt+Vector3(0,0,-0.5*CFG.gravity*dt*dt)
        local ray=World:raycast('ray',p,q,'slot_mask',mask)
        local endpoint=ray and ray.position or q
        if i%3==1 then projected[#projected+1]={p,endpoint} end
        if ray then ground=endpoint break end
        p=q
        v=Vector3(v.x*(1-CFG.drag*dt),v.y*(1-CFG.drag*dt),v.z-CFG.gravity*dt)
    end
    -- Preserve the real fuse endpoint, not the hypothetical ground point.
    local fuse_endpoint=lines[#lines] and lines[#lines][2] or origin
    return lines,fuse_endpoint,(fuse_endpoint-origin):length()/100,'FUSE (estimated)','fuse',projected,ground
end

local function point_text(p)
    return string.format('(%.1f,%.1f,%.1f)',p.x,p.y,p.z)
end
local function segment_summary(list)
    local longest,index,start_point,end_point,gap=0,0,nil,nil,0
    for i=1,#list do
        local a,b=list[i][1],list[i][2]
        local length=(b-a):length()
        if length>longest then
            longest,index,start_point,end_point=length,i,a,b
        end
        if i>1 then
            local previous_end=list[i-1][2]
            gap=math.max(gap,(a-previous_end):length())
        end
    end
    return #list,longest,index,start_point,end_point,gap
end
local function debug_path(t)
    if not CFG.debug_path or t-last_debug<1 then return end
    last_debug=t
    local count,longest,index,a,b,gap=segment_summary(segments)
    local continuation_count,continuation_longest,continuation_index,
        continuation_a,continuation_b,continuation_gap=segment_summary(continuation)
    local segment=a and string.format('%d:%.1f %s->%s',index,longest,point_text(a),point_text(b)) or 'none'
    local continuation_segment=continuation_a and
        string.format('%d:%.1f %s->%s',continuation_index,continuation_longest,
            point_text(continuation_a),point_text(continuation_b)) or 'none'
    local endpoint=terminal and point_text(terminal) or 'none'
    log(string.format('[GL40 path] type=%s distance=%s terminal=%s flight=%d max=%s gap=%.1f continuation=%d max=%s gap=%.1f',
        tostring(terminal_type or state),tostring(distance or 'n/a'),endpoint,
        count,segment,gap,continuation_count,continuation_segment,continuation_gap))
end

-- One stroke only. Offset parallel strokes in v0.9 produced visual branches
-- and apparent T-shaped joins. This deliberately preserves the flight maths.
local function draw(a,b,r,g,bl)
    if (b-a):length()>0.001 then
        Application:draw_line_unpaused(a,b,r,g,bl)
    end
end
local function draw_marker(p,r,g,bl)
    local radius=CFG.marker_radius
    for i=0,23 do
        local a=i*math.pi/12
        local b=(i+1)*math.pi/12
        draw(p+Vector3(radius*math.cos(a),radius*math.sin(a),0),
             p+Vector3(radius*math.cos(b),radius*math.sin(b),0),r,g,bl)
    end
    draw(p+Vector3(-radius,0,0),p+Vector3(radius,0,0),r,g,bl)
    draw(p+Vector3(0,-radius,0),p+Vector3(0,radius,0),r,g,bl)
end
local function draw_block(p)
    local d=20
    local corners={
        p+Vector3(-d,-d,-d),p+Vector3(d,-d,-d),
        p+Vector3(d,d,-d),p+Vector3(-d,d,-d),
        p+Vector3(-d,-d,d),p+Vector3(d,-d,d),
        p+Vector3(d,d,d),p+Vector3(-d,d,d)
    }
    local edges={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},
                 {1,5},{2,6},{3,7},{4,8}}
    for i=1,#edges do
        draw(corners[edges[i][1]],corners[edges[i][2]],1,0.75,0)
    end
end

local function update(self,t)
    local weapon=self._equipped_unit
    local base=alive(weapon) and weapon:base()
    local id=base and base.get_name_id and base:get_name_id()
    tracker.enabled=(id=='gre_m79')
    local ui=hud_label()
    if not tracker.enabled then
        segments,terminal,distance,state,terminal_type,continuation,ground_point={},nil,nil,'WAIT',nil,{},nil
        if alive(ui) then ui:set_visible(false) end
        return
    end
    local cam=self._ext_camera
    if not cam then return end
    local origin,forward=cam:position(),cam:forward()
    if not origin or not forward then return end
    if t-last_calc>=CFG.recalc_interval then
        last_calc=t
        segments,terminal,distance,state,terminal_type,continuation,ground_point=predict(origin,forward)
        debug_path(t)
    end
    local known=distance~=nil
    local far=known and distance>=40
    local r,g,b=far and 0.15 or 1,far and 1 or 0.22,far and 0.25 or 0.2
    local blocked=terminal_type=='collision' and known and distance<40
    if blocked then r,g,b=1,0.75,0.05 end
    if Application and Application.draw_line_unpaused then
        for i=1,#segments do
            draw(segments[i][1],segments[i][2],r,g,b)
        end
        -- Dotted extension only when the timed fuse ends before the ground.
        if terminal_type=='fuse' then
            for i=1,#continuation do
                draw(continuation[i][1],continuation[i][2],0.45,0.65,0.85)
            end
            if ground_point then
                draw_marker(ground_point,0.45,0.65,0.85)
            end
        end
        if terminal then
            if blocked then draw_block(terminal)
            elseif terminal_type=='collision' then draw_marker(terminal,r,g,b)
            else
                -- Fuse end: small cross, never pretend it is a ground impact.
                local d=8
                draw(terminal+Vector3(-d,0,0),terminal+Vector3(d,0,0),r,g,b)
                draw(terminal+Vector3(0,0,-d),terminal+Vector3(0,0,d),r,g,b)
            end
        end
    end
    if alive(ui) then
        local shown=known and string.format('~%.1f m',distance) or '--'
        local shown_state=blocked and 'GEOMETRY HIT (estimated)' or state
        ui:set_text(string.format('GL40 %s | %s | 40m kills: %d/25 | v1.0 BETA',
            shown,shown_state,tracker.kills or 0))
        ui:set_color(blocked and Color(1,0.75,0.05) or (known and (far and Color(0.15,1,0.25) or Color(1,0.22,0.2)) or Color.white))
        ui:set_visible(true)
    end
end

if PlayerStandard and Hooks and Hooks.PostHook then
    Hooks:PostHook(PlayerStandard,'update','gl40_predictor_v10_update',function(self,t,dt)
        local ok,err=pcall(update,self,t)
        if not ok and not tracker.reported_v10 then
            tracker.reported_v10=true
            log('[GL40 Predictor v1.0] '..tostring(err))
        end
    end)
end
