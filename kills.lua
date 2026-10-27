-- Counts only kills whose attack data explicitly identifies a GL40 weapon.
-- Beta: projectile attribution varies between game versions; missed kills are possible.
_G.GL40Tracker = _G.GL40Tracker or { kills=0, enabled=false }
local tracker=_G.GL40Tracker
local seen={}
if CopDamage and Hooks and Hooks.PreHook then
    Hooks:PreHook(CopDamage,'die','gl40_predictor_v02_kills',function(self,attack_data)
        if not attack_data or not alive(self._unit) then return end
        local key=tostring(self._unit:key())
        if seen[key] then return end
        local attacker=attack_data.attacker_unit
        local player=managers.player and managers.player:player_unit()
        if not alive(player) or not alive(attacker) or attacker~=player then return end
        local weapon=attack_data.weapon_unit
        local base=alive(weapon) and weapon:base()
        local id=base and base.get_name_id and base:get_name_id()
        if id~='gre_m79' then return end
        local distance=(self._unit:position()-player:position()):length()/100
        if distance<40 then return end
        seen[key]=true
        tracker.kills=(tracker.kills or 0)+1
        log(string.format('[GL40 Predictor] Long-range GL40 kill %.1fm; total %d',distance,tracker.kills))
    end)
end
