AddCSLuaFile()

ENT.Type  = "anim"
ENT.Base  = "base_anim"
ENT.PrintName = "Sleeping HBomb"
ENT.Author = "BR3XALITY"
ENT.Spawnable = false
ENT.AdminOnly = false

-- ===== CONFIG =====
ENT.ExplosionRadius = 350   -- how big the blast is
ENT.ExplosionDamage = 350   -- how strong the blast is
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

        -- Override defaults from server-side HBOMBConfig if present
        if HBOMBConfig then
            -- set entity instance values so other functions use them (Explode uses self.ExplosionRadius/self.ExplosionDamage)
            self.ExplosionRadius = HBOMBConfig.Radius or self.ExplosionRadius
            self.ExplosionDamage = HBOMBConfig.Damage or self.ExplosionDamage
            self.AutoRemoveTime = HBOMBConfig.AutoRemoveTime or self.AutoRemoveTime
        end

        -- safety: auto-remove after AutoRemoveTime seconds if never touched (no explosion)
        local cleanupTime = self.AutoRemoveTime or 30
        timer.Simple(cleanupTime, function()
            if IsValid(self) and not self._Exploded then
                self:Remove()
            end
        end)
    end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end