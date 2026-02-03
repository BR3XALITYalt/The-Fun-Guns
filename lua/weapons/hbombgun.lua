SWEP.PrintName = "HBOMB Gun"
SWEP.Author = "BR3XALITY"
SWEP.Purpose = "shoots helecopter bombs"
SWEP.Instructions = "LEFT CLICK: Throw hbomb | RIGHT CLICK: Cycle fire mode"
SWEP.Category = "The Fun Guns - Destructive"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"

local ShootSound = Sound("shoot/short.mp3")
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
SWEP.Primary.Force = 10 -- base force for normal modes

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

-- Mode system:
-- 1 = Normal
-- 2 = Rapid
-- 3 = Normal - Hard Force
-- 4 = Rapid - Hard Force
SWEP.NormalDelay = 0.5
SWEP.RapidDelay = 0.01
SWEP.HardForceMultiplier = 512 -- multiplies base Primary.Force for hard modes (10 * 3 = 30)
SWEP.BaseVelocityNormal = 1500
SWEP.BaseVelocityRapid = 1200
SWEP.HardVelocityNormal = 3000
SWEP.HardVelocityRapid = 2400

function SWEP:SetupDataTables()
    -- store an int for the current fire mode (1..4)
    self:NetworkVar("Int", 0, "FireMode")
end

function SWEP:Initialize()
    util.PrecacheSound(ShootSound)
    util.PrecacheSound(self.ReloadSound)
    util.PrecacheSound(RapidFireSound)
    self:SetWeaponHoldType(self.HoldType)
    if SERVER then
        self:SetFireMode(1) -- start in mode 1
    end
    self.Primary.Delay = self.NormalDelay
end

local function modeIsRapid(mode)
    return mode == 2 or mode == 4
end

local function modeIsHard(mode)
    return mode == 3 or mode == 4
end

function SWEP:PrimaryAttack()
    if (!self:CanPrimaryAttack()) then return end
    local mode = self:GetFireMode() or 1
    local isRapid = modeIsRapid(mode)
    local isHard = modeIsHard(mode)

    -- ensure proper delay on firing
    self.Primary.Delay = isRapid and self.RapidDelay or self.NormalDelay
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self:EmitSound(ShootSound)
    if IsValid(self.Owner) then
        self.Owner:SetAnimation(PLAYER_ATTACK1)
    end

    local recoilMult = (isRapid and 0.5) or 1
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

    -- choose velocity based on mode (hard modes launch faster)
    local velocityMult
    if isHard then
        velocityMult = isRapid and self.HardVelocityRapid or self.HardVelocityNormal
    else
        velocityMult = isRapid and self.BaseVelocityRapid or self.BaseVelocityNormal
    end

    local velocity = aimVec * velocityMult
    local phys = grenade:GetPhysicsObject()
    if (IsValid(phys)) then
        phys:SetVelocity(velocity)
        phys:AddAngleVelocity(Vector(math.random(-500, 500), math.random(-500, 500), math.random(-500, 500)))
        -- apply harder force impulse in hard modes to affect collisions more strongly
        if isHard then
            local baseForce = self.Primary.Force or 10
            phys:ApplyForceCenter(aimVec * (baseForce * self.HardForceMultiplier))
        end
    end

    -- cleanup
    timer.Simple(30, function()
        if (IsValid(grenade)) then
            grenade:Remove()
        end
    end)
end

function SWEP:SecondaryAttack()
    if (!self:CanSecondaryAttack()) then return end
    if SERVER then
        local mode = self:GetFireMode() or 1
        mode = mode + 1
        if mode > 4 then mode = 1 end
        self:SetFireMode(mode)

        -- set the delay instantly for feedback / consistency
        local isRapid = modeIsRapid(mode)
        self.Primary.Delay = isRapid and self.RapidDelay or self.NormalDelay

        if IsValid(self.Owner) then
            local label
            if mode == 1 then label = "NORMAL FIRE (MODE 1)"
            elseif mode == 2 then label = "RAPID FIRE (MODE 2)"
            elseif mode == 3 then label = "NORMAL - HARD FORCE (MODE 3)"
            elseif mode == 4 then label = "RAPID - HARD FORCE (MODE 4)" end
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
    self:DefaultReload(ACT_VM_RELOAD)
end

function SWEP:DrawHUD()
    if not IsValid(self:GetOwner()) then return end
    local mode = self:GetFireMode() or 1
    local modeText = "MODE " .. tostring(mode)
    local delay = 0.5 -- default fallback

    -- Determine delay based on mode
    if mode == 1 then
        modeText = "NORMAL"
        delay = self.NormalDelay
    elseif mode == 2 then
        modeText = "RAPID"
        delay = self.RapidDelay
    elseif mode == 3 then
        modeText = "NORMAL - HARD"
        delay = self.NormalDelay
    elseif mode == 4 then
        modeText = "RAPID - HARD"
        delay = self.RapidDelay
    end

    local color = (mode == 1 or mode == 3) and Color(50, 255, 50, 255) or Color(255, 50, 50, 255)

    surface.SetFont("Default")
    surface.SetTextColor(color)
    surface.SetTextPos(ScrW() / 2 + 20, ScrH() / 2 + 20)
    surface.DrawText("MODE: " .. modeText)
    surface.SetTextPos(ScrW() / 2 + 20, ScrH() / 2 + 35)
    surface.DrawText("DELAY: " .. string.format("%.2f", delay) .. "s")
end

function SWEP:Think()
    -- keep muzzle FX chance for rapid modes like before
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