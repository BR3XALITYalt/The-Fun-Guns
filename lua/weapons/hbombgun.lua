SWEP.PrintName = "HBOMB Gun"
SWEP.Author = "BR3XALITY"
SWEP.Purpose = "shoots helicopter bombs"
SWEP.Instructions = "LEFT CLICK: Throw hbomb | RIGHT CLICK: Cycle fire mode | MIDDLE CLICK: Configure"
SWEP.Category = "The Fun Guns - Destructive"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"

local ShootSound = Sound("shoot/short.mp3")
local RapidFireSound = Sound("buttons/button14.wav")

SWEP.Primary.TakeAmmo = 1
SWEP.Primary.ClipSize = 2147483647
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.DefaultClip = 2147483647
SWEP.Primary.Spread = 0.02
SWEP.Primary.Automatic = true
SWEP.Primary.Recoil = .2
SWEP.Primary.Delay = 0.5
SWEP.Primary.Force = 10

SWEP.Secondary.Ammo = "none"

SWEP.NormalDelay = 0.5
SWEP.RapidDelay = 0.01
SWEP.HardForceMultiplier = 512
SWEP.BaseVelocityNormal = 1500
SWEP.BaseVelocityRapid = 1200
SWEP.HardVelocityNormal = 3000
SWEP.HardVelocityRapid = 2400

if SERVER then
    util.AddNetworkString("HBOMB_RequestConfig")
    util.AddNetworkString("HBOMB_ConfigValues")
    util.AddNetworkString("HBOMB_SendConfig")

    if not HBOMBConfig then
        HBOMBConfig = {
            Radius = 350,
            Damage = 350,
            AutoRemoveTime = 30
        }
    end

    net.Receive("HBOMB_RequestConfig", function(_, ply)
        net.Start("HBOMB_ConfigValues")
        net.WriteFloat(HBOMBConfig.Radius)
        net.WriteFloat(HBOMBConfig.Damage)
        net.WriteFloat(HBOMBConfig.AutoRemoveTime)
        net.Send(ply)
    end)

    net.Receive("HBOMB_SendConfig", function(_, ply)
        HBOMBConfig.Radius = math.Clamp(net.ReadFloat(), 0, 5000)
        HBOMBConfig.Damage = math.Clamp(net.ReadFloat(), 0, 10000)
        HBOMBConfig.AutoRemoveTime = math.Clamp(net.ReadFloat(), 0, 600)
        ply:ChatPrint("HBomb config updated.")
    end)
end

function SWEP:SetupDataTables()
    self:NetworkVar("Int", 0, "FireMode")
end

function SWEP:Initialize()
    self:SetFireMode(1)
end

local function modeIsRapid(m) return m == 2 or m == 4 end
local function modeIsHard(m) return m == 3 or m == 4 end

function SWEP:PrimaryAttack()
    if not SERVER then return end

    local owner = self.Owner
    local aim = owner:GetAimVector()
    local pos = owner:GetShootPos()

    local grenade = ents.Create("grenade_helicopter")
    grenade:SetPos(pos + aim * 16)
    grenade:SetOwner(owner)
    grenade:Spawn()
    grenade:Activate()

    local mode = self:GetFireMode()
    local vel = modeIsHard(mode)
        and (modeIsRapid(mode) and self.HardVelocityRapid or self.HardVelocityNormal)
        or  (modeIsRapid(mode) and self.BaseVelocityRapid or self.BaseVelocityNormal)

    grenade:GetPhysicsObject():SetVelocity(aim * vel)

    -- === FAKE EXPLOSION HOOK ===
    grenade:AddCallback("PhysicsCollide", function(ent)
        if ent._Exploded then return end
        ent._Exploded = true

        local pos = ent:GetPos()
        local owner = ent:GetOwner() or ent

        local eff = EffectData()
        eff:SetOrigin(pos)
        util.Effect("HelicopterMegaBomb", eff)

        util.BlastDamage(ent, owner, pos,
            HBOMBConfig.Radius,
            HBOMBConfig.Damage
        )

        ent:Remove()
    end)

    timer.Simple(HBOMBConfig.AutoRemoveTime, function()
        if IsValid(grenade) then grenade:Remove() end
    end)
end

function SWEP:SecondaryAttack()
    local m = self:GetFireMode() + 1
    if m > 4 then m = 1 end
    self:SetFireMode(m)
    self.Owner:ChatPrint("Mode: " .. m)
end

function SWEP:Think()
    if CLIENT and input.IsMouseDown(MOUSE_MIDDLE) and not self._pressed then
        self._pressed = true
        net.Start("HBOMB_RequestConfig")
        net.SendToServer()
    elseif CLIENT and not input.IsMouseDown(MOUSE_MIDDLE) then
        self._pressed = false
    end
end

-- ===== CLIENT UI =====
if CLIENT then
    net.Receive("HBOMB_ConfigValues", function()
        local r = net.ReadFloat()
        local d = net.ReadFloat()
        local t = net.ReadFloat()

        local f = vgui.Create("DFrame")
        f:SetTitle("HBomb Config (Vanilla)")
        f:SetSize(400,220)
        f:Center()
        f:MakePopup()

        local sr = vgui.Create("DNumSlider", f)
        sr:Dock(TOP)
        sr:SetText("Radius")
        sr:SetMax(5000)
        sr:SetValue(r)

        local sd = vgui.Create("DNumSlider", f)
        sd:Dock(TOP)
        sd:SetText("Damage")
        sd:SetMax(10000)
        sd:SetValue(d)

        local st = vgui.Create("DNumSlider", f)
        st:Dock(TOP)
        st:SetText("Auto Remove (s)")
        st:SetMax(600)
        st:SetValue(t)

        local b = vgui.Create("DButton", f)
        b:Dock(BOTTOM)
        b:SetText("Apply")
        b.DoClick = function()
            net.Start("HBOMB_SendConfig")
            net.WriteFloat(sr:GetValue())
            net.WriteFloat(sd:GetValue())
            net.WriteFloat(st:GetValue())
            net.SendToServer()
            f:Close()
        end
    end)
end