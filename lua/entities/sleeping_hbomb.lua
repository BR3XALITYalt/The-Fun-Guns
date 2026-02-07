AddCSLuaFile()

ENT.Type  = "anim"
ENT.Base  = "base_anim"
ENT.PrintName = "Sleeping HBomb"
ENT.Author = "BR3XALITY"
ENT.Spawnable = false
ENT.AdminOnly = false

-- ===== CONFIG =====
ENT.ExplosionRadius = 550   -- how big the blast is
ENT.ExplosionDamage = 500   -- how strong the blast is
-- ==================

if SERVER then

    function ENT:Initialize()
        self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")

        -- No physical collision, but still detects touches
        self:PhysicsInit(SOLID_NONE)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetTrigger(true) -- this is the magic

        -- guard so we don't explode twice
        self._Exploded = false

        -- safety: auto-remove after 30s if never touched
        timer.Simple(30, function()
            if IsValid(self) and not self._Exploded then
                self:Remove()
            end
        end)
    end

    function ENT:Explode(toucher)
        if self._Exploded then return end
        self._Exploded = true

        local pos = self:GetPos()
        local owner = self:GetOwner()
        if not IsValid(owner) then owner = self end

        local eff = EffectData()
        eff:SetOrigin(pos)
        util.Effect("HelicopterMegaBomb", eff, true, true)

        self:EmitSound("ambient/explosions/explode_4.wav", 140, 100)

        -- use the variables here
        util.BlastDamage(
            self,
            owner,
            pos,
            self.ExplosionRadius,
            self.ExplosionDamage
        )

        self:Remove()
    end

    function ENT:Touch(ent)
        if not IsValid(ent) then return end
        if ent:GetClass() == "worldspawn" then return end
        if ent:GetClass() == self:GetClass() then return end

        self:Explode(ent)
    end

    function ENT:OnTakeDamage(dmginfo)
        self:Explode(dmginfo:GetAttacker())
    end

end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end