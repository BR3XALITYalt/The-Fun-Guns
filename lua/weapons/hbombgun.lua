SWEP.PrintName = "HBOMB Gun"
SWEP.Author = "BR3XALITY"
SWEP.Purpose = "shoots helecopter bombs"
SWEP.Instructions = "LEFT CLICK: Throw hbomb | RIGHT CLICK: Toggle rapid fire"
SWEP.Category = "The Fun Guns"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"

local ShootSound = Sound("Weapon_Pistol.Single")
local RapidFireSound = Sound("buttons/button14.wav")

SWEP.Primary.Damage = 0
SWEP.Primary.TakeAmmo = 1
SWEP.Primary.ClipSize = 2147483647
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.DefaultClip = 2147483647
SWEP.Primary.Spread = 0.02
SWEP.Primary.NumberofShots = 1
SWEP.Primary.Automatic = true
SWEP.Primary.Recoil = .2
SWEP.Primary.Delay = 0.5
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
SWEP.HoldType = "Pistol"
SWEP.FiresUnderwater = false
SWEP.ReloadSound = "sound/epicreload.wav"
SWEP.CSMuzzleFlashes = true

SWEP.RapidFireMode = false
SWEP.NormalDelay = 0.5
SWEP.RapidDelay = 0.05

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "RapidFireMode")
end

function SWEP:Initialize()
    util.PrecacheSound(ShootSound)
    util.PrecacheSound(self.ReloadSound)
    util.PrecacheSound(RapidFireSound)
    self:SetWeaponHoldType(self.HoldType)
    if SERVER then
        self:SetRapidFireMode(false)
    end
    self.Primary.Delay = self.NormalDelay
end

function SWEP:PrimaryAttack()
    if (!self:CanPrimaryAttack()) then return end
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self:EmitSound(ShootSound)
    if IsValid(self.Owner) then
        self.Owner:SetAnimation(PLAYER_ATTACK1)
    end
    local recoilMult = (self:GetRapidFireMode() and 0.5) or 1
    local rnda = self.Primary.Recoil * -1 * recoilMult
    local rndb = self.Primary.Recoil * math.random(-1, 1) * recoilMult
    if IsValid(self.Owner) then
        self.Owner:ViewPunch(Angle(rnda, rndb, rnda))
    end
    self:TakePrimaryAmmo(self.Primary.TakeAmmo)
    if (!SERVER) then return end
    local owner = self.Owner
    local spawnPos = owner:GetShootPos()
    local aimVec = owner:GetAimVector()
    local spread = Vector(math.Rand(-self.Primary.Spread, self.Primary.Spread),
                         math.Rand(-self.Primary.Spread, self.Primary.Spread),
                         0)
    aimVec = (aimVec + spread):GetNormalized()
    local grenade = ents.Create("grenade_helicopter")
    if (!IsValid(grenade)) then return end
    grenade:SetPos(spawnPos + aimVec * 16)
    grenade:SetAngles(aimVec:Angle())
    grenade:SetOwner(owner)
    grenade:Spawn()
    grenade:Activate()
    local velocityMult = (self:GetRapidFireMode() and 1200) or 1500
    local velocity = aimVec * velocityMult
    local phys = grenade:GetPhysicsObject()
    if (IsValid(phys)) then
        phys:SetVelocity(velocity)
        phys:AddAngleVelocity(Vector(math.random(-500, 500), math.random(-500, 500), math.random(-500, 500)))
    end
    timer.Simple(30, function()
        if (IsValid(grenade)) then
            grenade:Remove()
        end
    end)
end

function SWEP:SecondaryAttack()
    if (!self:CanSecondaryAttack()) then return end
    if SERVER then
        self:SetRapidFireMode(not self:GetRapidFireMode())
        if (self:GetRapidFireMode()) then
            self.Primary.Delay = self.RapidDelay
            if IsValid(self.Owner) then
                self.Owner:ChatPrint("RAPID FIRE MODE ENABLED (0.05s delay)")
            end
        else
            self.Primary.Delay = self.NormalDelay
            if IsValid(self.Owner) then
                self.Owner:ChatPrint("NORMAL FIRE MODE (0.5s delay)")
            end
        end
    end
    self:EmitSound(RapidFireSound)
    self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
    self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:CanSecondaryAttack()
    return true
end

function SWEP:Reload()
    self:EmitSound(self.ReloadSound)
    self:DefaultReload(ACT_VM_RELOAD)
end

function SWEP:DrawHUD()
    if not IsValid(self:GetOwner()) then return end
    local modeText = (self:GetRapidFireMode() and "RAPID FIRE") or "NORMAL FIRE"
    local color = (self:GetRapidFireMode() and Color(255, 50, 50, 255)) or Color(50, 255, 50, 255)
    surface.SetFont("Default")
    surface.SetTextColor(color)
    surface.SetTextPos(ScrW() / 2 + 20, ScrH() / 2 + 20)
    surface.DrawText("MODE: " .. modeText)
    surface.SetTextPos(ScrW() / 2 + 20, ScrH() / 2 + 35)
    surface.DrawText("DELAY: " .. self.Primary.Delay .. "s")
end

function SWEP:Think()
    if (self:GetRapidFireMode() and self:GetNextPrimaryFire() > CurTime() - 0.1) then
        if (math.random(1, 3) == 1) then
            local effectdata = EffectData()
            effectdata:SetOrigin(self.Owner and self.Owner:GetShootPos() or Vector(0,0,0))
            effectdata:SetEntity(self)
            effectdata:SetAttachment(1)
            util.Effect("MuzzleEffect", effectdata)
        end
    end
end