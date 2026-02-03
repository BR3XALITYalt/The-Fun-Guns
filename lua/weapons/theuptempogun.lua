SWEP.PrintName = "The Uptempo Gun"
SWEP.Author = "BR3XALITY"
SWEP.Purpose = "Plays a random uptempo kick so you can rave"
SWEP.Instructions = "left click to BAMMMMM"
SWEP.Category = "The Fun Guns - Other"
SWEP.Spawnable= true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"

SWEP.Primary.Damage = 2048
SWEP.Primary.TakeAmmo = 1
SWEP.Primary.ClipSize = 2147483647
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.DefaultClip = 2147483647
SWEP.Primary.Spread = 0
SWEP.Primary.NumberofShots = 1
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
-- Echo implementation (no pitch, no delayed start)
-- =========================
local ECHO_VOLUME = 0.45    -- starting volume for the echo (0..1)
local ECHO_FADE_TIME = 1.2  -- seconds for the echo to fade out
local ECHO_STOP_AFTER = 1.4 -- safety stop after this many seconds

-- Play a sound attached to an entity with a simple immediate echo (no pitch, no delay)
local function PlayWithEcho(ent, soundPath)
    if not IsValid(ent) then return end

    -- play main hit immediately (full volume)
    ent:EmitSound(soundPath)

    -- create an immediate overlapping copy that will fade out to simulate an echo/tail
    local echo = CreateSound(ent, soundPath)
    if not echo then return end

    echo:Play()

    -- instantly set the echo to a reduced volume (no pitch change)
    if echo.ChangeVolume then
        echo:ChangeVolume(ECHO_VOLUME, 0) -- set volume immediately
    end

    -- fade the echo to silence over ECHO_FADE_TIME seconds
    if echo.ChangeVolume then
        echo:ChangeVolume(0, ECHO_FADE_TIME)
    end

    -- stop/cleanup after a little longer than the fade to make sure it ends
    timer.Simple(ECHO_STOP_AFTER, function()
        if echo then
            echo:Stop()
        end
    end)
end

-- Backwards compatibility: some previous code might call PlayWithReverb
-- We'll alias it so calls to PlayWithReverb won't error.
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

    local bullet = {}
    bullet.Num = self.Primary.NumberofShots
    bullet.Src = self.Owner:GetShootPos()
    bullet.Dir = self.Owner:GetAimVector()
    bullet.Spread = Vector(self.Primary.Spread * 0.1, self.Primary.Spread * 0.1, 0)
    bullet.Tracer = 1
    bullet.Force = self.Primary.Force
    bullet.Damage = self.Primary.Damage
    bullet.AmmoType = self.Primary.Ammo

    local rnda = self.Primary.Recoil * -1
    local rndb = self.Primary.Recoil * math.random(-1, 1)

    self:ShootEffects()
    self.Owner:FireBullets(bullet)

    -- choose a random uptempo sound and play it with the echo
    local snd = self.UptempoSounds[math.random(#self.UptempoSounds)]
    if snd then
        PlayWithEcho(self.Owner, snd)
    end

    self.Owner:ViewPunch(Angle(rnda, rndb, rnda))
    self:TakePrimaryAmmo(self.Primary.TakeAmmo)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
    if self.ReloadSound then
        self:EmitSound(self.ReloadSound)
    end
    self:DefaultReload(ACT_VM_RELOAD)
end