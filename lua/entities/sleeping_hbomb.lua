AddCSLuaFile()

ENT.Type  = "anim"
ENT.Base  = "base_anim"
ENT.PrintName = "Sleeping HBomb"
ENT.Author = "BR3XALITY"
ENT.Spawnable = false
ENT.AdminOnly = false

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

        -- safety: auto-remove after 30s if never touched (no explosion)
        timer.Simple(30, function()
            if IsValid(self) and not self._Exploded then
                self:Remove()
            end
        end)
    end

    -- central explode routine
    function ENT:Explode(toucher)
        if self._Exploded then return end
        self._Exploded = true

        local pos = self:GetPos()
        local owner = self:GetOwner()
        if not IsValid(owner) then owner = self end

        local eff = EffectData()
        eff:SetOrigin(pos)
        util.Effect("HelicopterMegaBomb", eff, true, true)

        -- replace this sound path with your preferred explosion sound if you like
        self:EmitSound("BaseExplosionEffect.Sound" or "ambient/explosions/explode_4.wav", 140, 100)

        -- damage: attacker = owner, radius = 200, damage = 200 (tune to taste)
        util.BlastDamage(self, owner, pos, 200, 200)

        -- remove immediately after explosion
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

        -- explode on any other entity touch
        self:Explode(ent)
    end

    -- optional: explode if damaged
    function ENT:OnTakeDamage(dmginfo)
        self:Explode(dmginfo:GetAttacker())
    end

end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end