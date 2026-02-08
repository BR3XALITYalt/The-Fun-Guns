AddCSLuaFile()

ENT.Type  = "anim"
ENT.Base  = "base_anim"
ENT.PrintName = "Sleeping HBomb"
ENT.Author = "BR3XALITY"
ENT.Spawnable = false
ENT.AdminOnly = false

-- ===== CONFIG =====
ENT.ExplosionRadius = 350   -- how big the blast is (default kept like your old working file)
ENT.ExplosionDamage = 350   -- how strong the blast is (max damage at center)
ENT.AutoRemoveTime = 30     -- safety cleanup if never touched
-- ==================

if SERVER then

    function ENT:Initialize()
        -- model matching the vanilla helibomb; change if you want a different skin
        self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(10)
        end

        -- guard so we don't explode twice
        self._Exploded = false

        -- safety: auto-remove after AutoRemoveTime seconds if never touched (no explosion)
        timer.Simple(self.AutoRemoveTime, function()
            if IsValid(self) and not self._Exploded then
                self:Remove()
            end
        end)
    end

    -- central explode routine
    -- triggerer: entity that caused explosion (may be nil)
    -- excludeAttacker: if valid entity passed here, that entity will NOT receive damage from this blast
    function ENT:Explode(triggerer, excludeAttacker)
        if self._Exploded then return end
        self._Exploded = true

        local pos = self:GetPos()
        local owner = self:GetOwner()
        if not IsValid(owner) then owner = self end

        local eff = EffectData()
        eff:SetOrigin(pos)
        util.Effect("HelicopterMegaBomb", eff, true, true)

        -- explosion sound (kept behaviour similar to original)
        self:EmitSound("ambient/explosions/explode_4.wav", 140, 100)

        -- If there's no need to exclude anyone, use util.BlastDamage (simpler, faster).
        if not IsValid(excludeAttacker) then
            util.BlastDamage(self, owner, pos, self.ExplosionRadius or 200, self.ExplosionDamage or 200)
        else
            -- Manual blast so we can skip damaging a particular attacker (e.g., owner who shot the bomb)
            local radius = self.ExplosionRadius or 200
            local maxDamage = self.ExplosionDamage or 200
            local entsInRange = ents.FindInSphere(pos, radius)
            for _, tgt in ipairs(entsInRange) do
                if not IsValid(tgt) then continue end
                -- skip the world
                if tgt:GetClass() == "worldspawn" or tgt:IsWorld() then continue end

                -- skip the excluded attacker entirely
                if tgt == excludeAttacker then continue end

                local closest = tgt:NearestPoint(pos)
                local dist = pos:Distance(closest)
                if dist > radius then continue end

                -- linear falloff
                local dmgAmount = math.max(0, maxDamage * (1 - dist / radius))
                if dmgAmount <= 0 then continue end

                local dmginfo = DamageInfo()
                dmginfo:SetDamage(dmgAmount)
                dmginfo:SetAttacker(owner)
                dmginfo:SetInflictor(self)
                dmginfo:SetDamageType(DMG_BLAST)

                -- apply small physical impulse to props and players
                local dir = (tgt:GetPos() - pos)
                if dir:Length() > 0 then
                    dir:Normalize()
                    local phys = tgt:GetPhysicsObject()
                    if IsValid(phys) and not tgt:IsPlayer() and not tgt:IsNPC() then
                        phys:ApplyForceCenter(dir * dmgAmount * 50)
                    elseif tgt:IsPlayer() then
                        -- small push for players
                        tgt:SetVelocity(dir * (dmgAmount * 10))
                    end
                end

                tgt:TakeDamageInfo(dmginfo)
            end
        end

        -- remove immediately after explosion (keeps same behavior as old)
        timer.Simple(0, function()
            if IsValid(self) then self:Remove() end
        end)
    end

    -- explode when touched by an entity (players, NPCs, props, vehicles, etc.)
    function ENT:Touch(ent)
        if not IsValid(ent) then return end

        -- ignore the worldspawn
        if ent:GetClass() == "worldspawn" then return end

        -- optional: ignore other sleeping_hbombs to prevent chain-triggering
        if ent:GetClass() == self:GetClass() then return end

        -- explode on any other entity touch (same as your old version)
        self:Explode(ent, nil)
    end

    -- explode if damaged (but ignore blast damage to prevent blast-induced recursion/chain reactions)
    function ENT:OnTakeDamage(dmginfo)
        if self._Exploded then return end

        -- Ignore blast damage caused by nearby explosions — we want this entity to only explode on touch or being shot.
        if dmginfo:IsDamageType(DMG_BLAST) then return end

        local attacker = dmginfo:GetAttacker()

        -- In case weapon object ends up as attacker, prefer weapon owner
        if IsValid(attacker) and attacker:IsWeapon() and IsValid(attacker:GetOwner()) then
            attacker = attacker:GetOwner()
        end

        local isBullet = dmginfo:IsDamageType(DMG_BULLET)
        local owner = self:GetOwner()

        -- If the bomb was shot by its owner (owner's bullets), explode but exclude the attacker from damage
        if isBullet and IsValid(attacker) and IsValid(owner) and attacker == owner then
            self:Explode(attacker, attacker) -- exclude the attacker (owner) from blast damage
            return
        end

        -- If damaged by a bullet from someone else, explode and credit the attacker
        if isBullet and IsValid(attacker) then
            self:Explode(attacker, nil)
            return
        end

        -- For all other damage types (except blast) we can choose to ignore or explode.
        -- Currently we don't explode on generic damage to avoid accidental chain reactions,
        -- but if you want to explode on any non-blast damage, uncomment the following:
        -- self:Explode(attacker, nil)
    end

end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end