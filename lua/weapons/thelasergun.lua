SWEP.PrintName = "The Laser Gun"
SWEP.Author = "BR3XALITY"
SWEP.Purpose = "Explodes entities when aimed at them"
SWEP.Instructions = "LEFT CLICK: Fire laser | RIGHT CLICK: Cycle fire mode"
SWEP.Category = "The Fun Guns"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"

local ShootSound = Sound("shoot/short.mp3")
local LaserSound = Sound("weapons/airboat/airboat_gun_lastshot1.wav")
local RapidFireSound = Sound("buttons/button14.wav")

SWEP.Primary.Damage = 40
SWEP.Primary.TakeAmmo = 1
SWEP.Primary.ClipSize = 2147483647
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.DefaultClip = 2147483647
SWEP.Primary.Spread = 0
SWEP.Primary.NumberofShots = 1
SWEP.Primary.Automatic = true
SWEP.Primary.Recoil = 0
SWEP.Primary.Delay = 0.25
SWEP.Primary.Force = 10

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Slot = 2
SWEP.SlotPos = 1
SWEP.DrawCrosshair = true
SWEP.DrawAmmo = true
SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 60
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.UseHands = true

SWEP.HoldType = "pistol"
SWEP.FiresUnderwater = false

SWEP.ReloadSound = "sound/epicreload.wav"
SWEP.CSMuzzleFlashes = true

-- Explosion settings (tweak as desired)
local EXPLOSION_RADIUS = 200
local EXPLOSION_DAMAGE = 300
local EXPLOSION_EFFECT = "Explosion" -- GMod built-in explosion effect
local TRACER_NAME = "AR2Tracer" -- visible tracer effect

-- Mode system:
-- 1 = Normal
-- 2 = Rapid
SWEP.NormalDelay = 0.25
SWEP.RapidDelay = 0.05

function SWEP:SetupDataTables()
    -- store an int for the current fire mode (1..2)
    self:NetworkVar("Int", 0, "FireMode")
end

function SWEP:Initialize()
    util.PrecacheSound(ShootSound)
    util.PrecacheSound(self.ReloadSound)
    util.PrecacheSound(LaserSound)
    util.PrecacheSound(RapidFireSound)
    self:SetWeaponHoldType(self.HoldType)
    if SERVER then
        self:SetFireMode(1) -- start in mode 1 (Normal)
    end
    self.Primary.Delay = self.NormalDelay
end

local function modeIsRapid(mode)
    return mode == 2
end

function SWEP:PrimaryAttack()
    if (not self:CanPrimaryAttack()) then return end
    local owner = self.Owner
    if not IsValid(owner) then return end
    
    local mode = self:GetFireMode() or 1
    local isRapid = modeIsRapid(mode)
    
    -- Set delay based on mode
    self.Primary.Delay = isRapid and self.RapidDelay or self.NormalDelay

    -- ammo, sound, effects and recoil
    self:EmitSound(LaserSound)
    self:ShootEffects()
    self:TakePrimaryAmmo(self.Primary.TakeAmmo)
    
    -- Reduced recoil for rapid mode
    local recoilMult = isRapid and 0.5 or 1
    local rnda = self.Primary.Recoil * -1 * recoilMult
    local rndb = self.Primary.Recoil * math.random(-1, 1) * recoilMult
    owner:ViewPunch(Angle(rnda, rndb, rnda))

    -- build the bullet but use a callback so we can explode on hit
    local wep = self
    local bullet = {}
    bullet.Num = 1
    bullet.Src = owner:GetShootPos()
    bullet.Dir = owner:GetAimVector()
    bullet.Spread = Vector(0, 0, 0)
    bullet.Tracer = 1
    bullet.TracerName = TRACER_NAME
    bullet.Force = self.Primary.Force
    bullet.Damage = self.Primary.Damage
    bullet.AmmoType = self.Primary.Ammo

    bullet.Callback = function(attacker, tr, dmginfo)
        -- tr is the trace result for the impact
        local hitPos = tr.HitPos
        local hitEnt = tr.Entity

        -- spawn an explosion effect
        local ed = EffectData()
        ed:SetOrigin(hitPos)
        ed:SetNormal(tr.HitNormal)
        ed:SetMagnitude(1)
        util.Effect(EXPLOSION_EFFECT, ed, true, true)

        -- apply blast damage
        util.BlastDamage(wep, owner, hitPos, EXPLOSION_RADIUS, EXPLOSION_DAMAGE)

        -- if the hit entity is valid and NOT a player, try to destroy/remove it
        if IsValid(hitEnt) and not hitEnt:IsPlayer() then
            -- prefer to kill NPCs cleanly
            if hitEnt:IsNPC() then
                hitEnt:TakeDamage(hitEnt:Health() + 1, owner, wep)
            else
                -- try breakable or prop removal
                -- if entity has a physics object, apply a big force then remove
                local phys = hitEnt:GetPhysicsObject()
                if IsValid(phys) then
                    phys:ApplyForceCenter((tr.Normal * -1) * 100000 + VectorRand() * 50000)
                end
                -- remove after a tiny delay so the effect is visible
                timer.Simple(0.05, function()
                    if IsValid(hitEnt) then hitEnt:Remove() end
                end)
            end
        end

        -- leave scorch decal
        util.Decal("Scorch", hitPos + tr.HitNormal * 2, hitPos - tr.HitNormal * 16)
    end

    -- fire the bullet
    owner:FireBullets(bullet)

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
    if (not self:CanSecondaryAttack()) then return end
    if SERVER then
        local mode = self:GetFireMode() or 1
        mode = mode + 1
        if mode > 2 then mode = 1 end
        self:SetFireMode(mode)

        -- set the delay instantly for feedback / consistency
        local isRapid = modeIsRapid(mode)
        self.Primary.Delay = isRapid and self.RapidDelay or self.NormalDelay

        if IsValid(self.Owner) then
            local label
            if mode == 1 then label = "NORMAL FIRE"
            elseif mode == 2 then label = "RAPID FIRE" end
            self.Owner:ChatPrint(label)
        end
    end
    self:EmitSound(RapidFireSound)
    self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
    self:SetNextSecondaryFire(CurTime() + 0.3)
end

function SWEP:CanSecondaryAttack()
    return true
end

function SWEP:Reload()
    self:EmitSound(self.ReloadSound)
    if SERVER then
        self:DefaultReload(ACT_VM_RELOAD)
    end
end

function SWEP:DrawHUD()
    if not IsValid(self:GetOwner()) then return end
    local mode = self:GetFireMode() or 1
    local modeText = ""
    local delay = self.NormalDelay

    -- Determine delay based on mode
    if mode == 1 then
        modeText = "NORMAL"
        delay = self.NormalDelay
    elseif mode == 2 then
        modeText = "RAPID"
        delay = self.RapidDelay
    end

    local color = mode == 1 and Color(50, 255, 50, 255) or Color(255, 50, 50, 255)

    surface.SetFont("Default")
    surface.SetTextColor(color)
    surface.SetTextPos(ScrW() / 2 + 20, ScrH() / 2 + 20)
    surface.DrawText("MODE: " .. modeText)
    surface.SetTextPos(ScrW() / 2 + 20, ScrH() / 2 + 35)
    surface.DrawText("DELAY: " .. string.format("%.2f", delay) .. "s")
end

function SWEP:Think()
    -- keep muzzle FX chance for rapid mode
    local mode = self:GetFireMode() or 1
    if (modeIsRapid(mode) and self:GetNextPrimaryFire() > CurTime() - 0.1) then
        if (math.random(1, 3) == 1) then
            local effectdata = EffectData()
            effectdata:SetOrigin(self.Owner and self.Owner:GetShootPos() or Vector(0,0,0))
            effectdata:SetEntity(self)
            effectdata:SetAttachment(1)
            util.Effect("MuzzleEffect", effectdata)
        end
    end
end