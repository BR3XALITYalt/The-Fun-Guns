SWEP.PrintName = "The Uptempo Gun"
SWEP.Author = "BR3XALITY"
SWEP.Purpose = "Plays a random uptempo kick so you can rave"
SWEP.Instructions = "left click to BAMMMMM"
SWEP.Category = "The Fun Guns - Other"
SWEP.Spawnable= true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"

SWEP.Primary.Damage = 2147483647
SWEP.Primary.TakeAmmo = 1
SWEP.Primary.ClipSize = 2147483647
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.DefaultClip = 2147483647
SWEP.Primary.Spread = 0.13
SWEP.Primary.NumberofShots = 128
SWEP.Primary.Automatic = true
SWEP.Primary.Recoil = 0
SWEP.Primary.Delay = 0.3428571342857134285713428571
SWEP.Primary.Force = 10

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo		= "none"

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

SWEP.ReloadSound = "sound/epicreload.wav" -- keep your reload file path if you like

-- === NEW: single main volume variable ===
-- 1.0 is the normal max volume. You can set >1.0 for extra punch (may clip).
SWEP.MainVolume = 2.5

-- Helper: find all files in sound/uptempo and subfolders
local function FindUptempoSounds()
    local sounds = {}

    -- files in root of uptempo
    local files, dirs = file.Find("sound/uptempo/*", "GAME")
    for _, f in ipairs(files) do
        table.insert(sounds, "uptempo/" .. f)
    end

    -- files in subfolders of uptempo
    for _, d in ipairs(dirs) do
        local subfiles, _ = file.Find("sound/uptempo/" .. d .. "/*", "GAME")
        for _, sf in ipairs(subfiles) do
            table.insert(sounds, "uptempo/" .. d .. "/" .. sf)
        end
    end

    return sounds
end

-- =========================
-- Echo implementation (no separate echo volume variable)
-- Echo volume will be derived from SWEP.MainVolume (60% by default)
-- =========================
local ECHO_FADE_TIME = 1.2  -- seconds for the echo to fade out
local ECHO_STOP_AFTER = 1.4 -- safety stop after this many seconds
local ECHO_RELATIVE = 0.6   -- echo loudness relative to main (no separate var)

-- Play a sound attached to an entity with a simple immediate echo (no pitch, no delayed start)
-- now takes mainVolume as an argument (so the function doesn't need to grab the SWEP from ent)
local function PlayWithEcho(ent, soundPath, mainVolume)
    if not IsValid(ent) then return end
    local vol = mainVolume or 1.0

    -- play main hit immediately (use the provided main volume)
    -- EmitSound( soundName, soundLevel, pitch, volume )
    ent:EmitSound(soundPath, 75, 100, vol)

    -- create an immediate overlapping copy that will fade out to simulate an echo/tail
    local echo = CreateSound(ent, soundPath)
    if not echo then return end

    echo:Play()

    -- set the echo to a reduced volume based on mainVolume (no separate echo variable)
    if echo.ChangeVolume then
        echo:ChangeVolume(vol * ECHO_RELATIVE, 0) -- set echo instantly relative to main
        echo:ChangeVolume(0, ECHO_FADE_TIME)      -- fade echo out
    end

    -- stop/cleanup after a little longer than the fade to make sure it ends
    timer.Simple(ECHO_STOP_AFTER, function()
        if echo then
            echo:Stop()
        end
    end)
end

-- Backwards compatibility: some previous code might call PlayWithReverb
PlayWithReverb = PlayWithEcho

-- =========================
-- SWEP lifecycle
-- =========================
function SWEP:Initialize()
    self:SetWeaponHoldType(self.HoldType)

    -- gather uptempo sounds
    self.UptempoSounds = FindUptempoSounds()

    -- fallback if none found
    if not self.UptempoSounds or #self.UptempoSounds == 0 then
        -- change this to any fallback sound you have
        self.UptempoSounds = {"shoot/short.mp3"}
    end

    -- precache all picked sounds
    for _, s in ipairs(self.UptempoSounds) do
        util.PrecacheSound(s)
    end

    -- precache reload sound (if needed)
    util.PrecacheSound(self.ReloadSound)
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    -- avoid double-prediction issues: visual effects can be clientside but FireBullets should run on server
    if CLIENT then
        -- still play view punch / animations clientside for responsiveness
        self:ShootEffects()
        self.Owner:ViewPunch(Angle(self.Primary.Recoil * -1, self.Primary.Recoil * math.random(-1,1), 0))
        return
    end

    -- SERVER: create bullets
    local bullet = {}
    bullet.Num = math.max(1, self.Primary.NumberofShots or 1)
    bullet.Src = self.Owner:GetShootPos()
    bullet.Dir = self.Owner:GetAimVector()
    -- smaller spread for more visible tracers while debugging; adjust as desired
    local spread_val = (self.Primary.Spread or 1) * 0.1
    bullet.Spread = Vector(spread_val, spread_val, 0)
    bullet.Tracer = 1               -- every bullet will attempt a tracer
    bullet.TracerName = "Tracer"    -- explicit tracer effect (common default)
    bullet.Force = self.Primary.Force or 1
    bullet.Damage = self.Primary.Damage or 10
    bullet.AmmoType = self.Primary.Ammo or ""

    self.Owner:FireBullets(bullet)

    -- play server-side sound/effects attached to owner (your echo function is okay)
    local snd = self.UptempoSounds and self.UptempoSounds[math.random(#self.UptempoSounds)] or nil
    if snd then
        PlayWithEcho(self.Owner, snd, self.MainVolume)
    end

    -- consume ammo & set next fire (server)
    self:TakePrimaryAmmo(self.Primary.TakeAmmo or 1)
    self:SetNextPrimaryFire(CurTime() + (self.Primary.Delay or 0.1))

    -- network a little visual feedback to the shooter (clients)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self.Owner:SetAnimation(PLAYER_ATTACK1)
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
    if self.ReloadSound then
        self:EmitSound(self.ReloadSound)
    end
    self:DefaultReload(ACT_VM_RELOAD)
end