SWEP.PrintName = "Rocket Spam"

SWEP.Author = "BR3XALITY"
SWEP.Purpose = "Explode everything"
SWEP.Instructions = "left click to launch"
SWEP.Category = "The Fun Guns"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"

local ShootSound = Sound("Weapon_Pistol.Single")

SWEP.Primary.Damage = 2147483647
SWEP.Primary.TakeAmmo = 1
SWEP.Primary.ClipSize = 2147483647
SWEP.Primary.DefaultClip = 2147483647
SWEP.Primary.Ammo = "RPG_Round"
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.5

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

function SWEP:Initialize()
    util.PrecacheSound(ShootSound)
    util.PrecacheSound(self.ReloadSound)
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    local ply = self:GetOwner()
    if not IsValid(ply) then return end

    if SERVER then
        -- Create the rocket at the muzzle position
        local muzzlePos = ply:GetShootPos()
        local muzzleAng = ply:EyeAngles()
        
        -- Adjust for better forward spawning
        muzzlePos = muzzlePos + muzzleAng:Forward() * 25
        muzzlePos = muzzlePos + muzzleAng:Right() * 8
        muzzlePos = muzzlePos + muzzleAng:Up() * -8
        
        local rocket = ents.Create("rpg_missile")
        if IsValid(rocket) then
            rocket:SetPos(muzzlePos)
            rocket:SetAngles(muzzleAng)
            rocket:SetOwner(ply)
            
            -- Set damage before spawning
            rocket:SetKeyValue("damage", tostring(self.Primary.Damage))
            
            -- Remove delay and disable homing
            rocket:SetSaveValue("m_flDamage", self.Primary.Damage)
            rocket:SetSaveValue("m_flDelay", 0) -- Remove initial delay
            rocket:SetSaveValue("m_hOwner", ply)
            rocket:SetSaveValue("m_bCreateDangerSounds", false)
            
            rocket:Spawn()
            
            -- Activate immediately
            rocket:Fire("Launch")
            
            -- Remove any initial delay or slow movement
            local phys = rocket:GetPhysicsObject()
            if IsValid(phys) then
                -- Apply velocity immediately
                phys:SetVelocity(muzzleAng:Forward() * 2500)
                phys:EnableGravity(false)
            end
            
            -- Alternative: Use a custom rocket with better physics
            -- If still having issues, uncomment the section below:
            
            --[[
            timer.Simple(0, function()
                if IsValid(rocket) and IsValid(phys) then
                    -- Clear any residual forces and apply full velocity
                    phys:SetVelocity(Vector(0,0,0))
                    phys:SetVelocity(muzzleAng:Forward() * 3000)
                end
            end)
            --]]
        end
    end

    self:EmitSound(ShootSound)
    self:TakePrimaryAmmo(self.Primary.TakeAmmo)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    
    -- Viewpunch for recoil effect
    if ply:IsPlayer() then
        ply:ViewPunch(Angle(-2, 0, 0))
    end
end

function SWEP:SecondaryAttack()
    -- Nothing here, or add an alt-fire if desired
end

function SWEP:Reload()
    self:EmitSound(Sound(self.ReloadSound))
    self:DefaultReload(ACT_VM_RELOAD)
end