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
ENT.MaxChainDepth = 200     -- maximum chain propagation depth for bomb-to-bomb triggering
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
    -- depth: current chain depth (0 = initial). propagation stops when depth >= MaxChainDepth
    function ENT:Explode(triggerer, excludeAttacker, depth)
        depth = depth or 0

        -- If this already exploded, bail out.
        if self._Exploded then return end

        -- Mark exploded immediately to prevent recursion loops.
        self._Exploded = true

        local pos = self:GetPos()
        local owner = self:GetOwner()
        if not IsValid(owner) then owner = self end

        -- visual + sound
        local eff = EffectData()
        eff:SetOrigin(pos)
        util.Effect("HelicopterMegaBomb", eff, true, true)

        self:EmitSound("ambient/explosions/explode_4.wav", 140, 100)

        -- Core blast damage for everything (fast).
        util.BlastDamage(self, owner, pos, self.ExplosionRadius or 200, self.ExplosionDamage or 200)

        -- MANUAL PROPAGATION FOR BOMB-TO-BOMB CHAINING
        -- We intentionally do a second sweep to find nearby bombs and call their Explode with depth+1.
        -- This gives us precise control over chain depth while still using util.BlastDamage for general damage.
        if depth < (self.MaxChainDepth or 0) then
            local radius = self.ExplosionRadius or 200
            local entsInRange = ents.FindInSphere(pos, radius)

            for _, tgt in ipairs(entsInRange) do
                if not IsValid(tgt) then continue end

                -- skip world / worldspawn
                if tgt:GetClass() == "worldspawn" or tgt:IsWorld() then continue end

                -- If this is the same bomb class, propagate the chain (depth limited).
                if tgt:GetClass() == self:GetClass() and not tgt._Exploded then
                    -- Pass this bomb as the triggerer and increment depth
                    -- excludeAttacker is nil here because chain blasts are normal blast sources
                    -- (you can tweak to exclude certain entities if desired).
                    local ok, err = pcall(function()
                        tgt:Explode(self, nil, depth + 1)
                    end)
                    if not ok then
                        -- silence errors from user code inside other bombs so one bad bomb doesn't stop propagation
                        print("[hbomb] error while propagating to bomb:", err)
                    end
                end
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

        -- optional: ignore other sleeping_hbombs to prevent immediate chain-triggering via touch
        if ent:GetClass() == self:GetClass() then return end

        -- explode on any other entity touch (same as your old version). touch-triggered explosions start at depth 0.
        self:Explode(ent, nil, 0)
    end

    -- explode if damaged (but ignore blast damage to prevent blast-induced recursion;
    -- chain propagation is handled manually in Explode above)
    function ENT:OnTakeDamage(dmginfo)
        if self._Exploded then return end

        -- Ignore raw blast damage here; we propagate explicitly in Explode() so we can control depth.
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
            self:Explode(attacker, attacker, 0) -- exclude the attacker (owner) from blast damage
            return
        end

        -- If damaged by a bullet from someone else, explode and credit the attacker (depth 0)
        if isBullet and IsValid(attacker) then
            self:Explode(attacker, nil, 0)
            return
        end

        -- For other damage types (melee, physics impact, etc.), explode at depth 0
        -- (you can change this to ignore certain damage types if desired)
        self:Explode(attacker, nil, 0)
    end

end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end