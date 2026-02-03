SWEP.PrintName = "The Flame Gun"
SWEP.Author = "BR3XALITY"
SWEP.Purpose = "Flame people(?)"
SWEP.Instructions = "Left click to spray flame"
SWEP.Category = "The Fun Guns - Destructive"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"

-- ---- Flamethrower tuning (easy to tweak) ----
local FLAME_RANGE = 600         -- how far the flame reaches (units)
local FLAME_CONE  = 0.12        -- spread of the flame (bigger = wider cone)
local FLAME_HITS  = 6           -- number of short traces per tick to simulate a cone
local FLAME_DAMAGE = 6          -- base damage per hit trace (DMG_BURN)
local FLAME_IGNITE_TIME = 4     -- seconds to ignite the entity for
local FLAME_BLAST_RADIUS = 48   -- small area damage radius on hit
-- -----------------------------------------------

local ShootSound = "ambient/fire/ignite.wav" -- change to preferred loop/sfx if you have one
SWEP.Primary.Damage = FLAME_DAMAGE
SWEP.Primary.TakeAmmo = 1
SWEP.Primary.ClipSize = 2147483647
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.DefaultClip = 2147483647
SWEP.Primary.Spread = 0
SWEP.Primary.NumberofShots = 1
SWEP.Primary.Automatic = true
SWEP.Primary.Recoil = 0
SWEP.Primary.Delay = 0.06 -- fast ticks for continuous spray
SWEP.Primary.Force = 5

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
SWEP.WorldModel = "models/weapons/w_irifle.mdl"
SWEP.UseHands = true

SWEP.HoldType = "ar2"

SWEP.FiresUnderwater = false

SWEP.ReloadSound = "sound/epicreload.wav"

SWEP.CSMuzzleFlashes = true

function SWEP:Initialize()
    util.PrecacheSound(ShootSound)
    util.PrecacheSound(self.ReloadSound)
    self:SetWeaponHoldType(self.HoldType)
end

local function RandomConeDirection(aim, cone)
    -- returns a direction vector within a cone around aim
    local rand = VectorRand() * cone
    local dir = (aim + rand):GetNormalized()
    return dir
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    if not IsValid(self.Owner) then return end

    -- play sound (looped-ish feel by calling on every tick; change behavior if you want a single looping sound)
    self:EmitSound(ShootSound, 75, 100)

    self.Owner:SetAnimation(PLAYER_ATTACK1)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self:ShootEffects()

    local src = self.Owner:GetShootPos()
    local aim = self.Owner:GetAimVector()
    for i = 1, FLAME_HITS do
        local dir = RandomConeDirection(aim, FLAME_CONE)
        local tr = util.TraceLine({
            start = src,
            endpos = src + dir * FLAME_RANGE,
            filter = self.Owner,
            mask = MASK_SHOT
        })

        if tr.Hit then
            local hitpos = tr.HitPos
            local ent = tr.Entity

            -- apply direct burn damage using DamageInfo
            if IsValid(ent) then
                local dmginfo = DamageInfo()
                dmginfo:SetAttacker(self.Owner)
                dmginfo:SetInflictor(self)
                dmginfo:SetDamageType(DMG_BURN)
                dmginfo:SetDamage(self.Primary.Damage)
                dmginfo:SetDamagePosition(hitpos)
                ent:TakeDamageInfo(dmginfo)

                -- ignite valid entities (players, npcs, props, etc)
                if ent:IsPlayer() or ent:IsNPC() or (ent:IsValid() and ent:GetClass() ~= "worldspawn") then
                    ent:Ignite(FLAME_IGNITE_TIME, 100)
                end
            end

            -- small blast damage so multiple things near the hit take some heat
            util.BlastDamage(self, self.Owner, hitpos, FLAME_BLAST_RADIUS, math.ceil(self.Primary.Damage * 0.6))

            -- scorch decal
            util.Decal("Scorch", hitpos + tr.HitNormal, hitpos - tr.HitNormal)
        else
            -- optional: leave scorch on distant surfaces if enough distance
        end
    end

    -- consume ammo and set next fire
    self:TakePrimaryAmmo(self.Primary.TakeAmmo)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
    -- Secondary could toggle alt-fire (like a short napalm burst). Left empty for now.
end

function SWEP:Reload()
    if self:Clip1() < self.Primary.ClipSize then
        self:EmitSound(self.ReloadSound)
        self:DefaultReload(ACT_VM_RELOAD)
    end
end

function SWEP:OnRemove()
    -- stop sounds if necessary (cleanup)
    self:StopSound(ShootSound)
end