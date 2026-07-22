-- ============================================
-- 🪨 Backstreet Survival Hub v29 - PART 1
-- Custom UI + Responsive + Save/Load + Auto Cache
-- ============================================

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("BSSHub_v29") then playerGui:FindFirstChild("BSSHub_v29"):Destroy() end
pcall(function() local pg2=gethui and gethui() or game.CoreGui if pg2:FindFirstChild("BSSHub_v29") then pg2:FindFirstChild("BSSHub_v29"):Destroy() end if pg2:FindFirstChild("FlyBtn_v29") then pg2:FindFirstChild("FlyBtn_v29"):Destroy() end end)

local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local HTTP = game:GetService("HttpService")

local gameName = "Backstreet Survival"
pcall(function() local i = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) if i and i.Name then gameName = i.Name end end)

-- ============================================
-- RESPONSIVE + SAVE/LOAD
-- ============================================
local function getScreenSize()
    local vp = workspace.CurrentCamera.ViewportSize
    return vp.X, vp.Y
end

local function calcDefaultSize()
    local w, h = getScreenSize()
    local sw = math.min(math.max(w * 0.32, 300), 400)
    local sh = math.min(math.max(h * 0.65, 420), 580)
    return sw, sh
end

local defW, defH = calcDefaultSize()

local CONFIG_FILE = "BSSHub_v29.json"
local CONFIG = {posX=nil, posY=nil, sizeW=defW, sizeH=defH, minimized=false, activeTab="Main"}

local function saveConfig()
    pcall(function() if writefile then writefile(CONFIG_FILE, HTTP:JSONEncode(CONFIG)) end end)
end

local function loadConfig()
    pcall(function()
        if isfile and isfile(CONFIG_FILE) then
            local d = HTTP:JSONDecode(readfile(CONFIG_FILE))
            if d then for k,v in pairs(d) do CONFIG[k]=v end end
        end
    end)
end
loadConfig()

-- REMOTES
local RFunc, REvt = nil, nil
local remoteFound = false
local function findRemotes()
    if remoteFound then return end
    for _, name in ipairs({"LogService","LocalizationService","SocialService","GuiService","TextService","SoundService","Chat","ContentProvider"}) do
        pcall(function() local svc=game:GetService(name) local rf=svc:FindFirstChild("RemoteFunction") local re=svc:FindFirstChild("RemoteEvent") if rf and rf:IsA("RemoteFunction") then RFunc=rf end if re and re:IsA("RemoteEvent") then REvt=re end end)
        if RFunc and REvt then remoteFound=true return end
    end
    if not RFunc or not REvt then pcall(function() for _,d in pairs(game:GetDescendants()) do if d:GetFullName():find("Roblox") or d:GetFullName():find("ReplicatedStorage") then continue end if not RFunc and d:IsA("RemoteFunction") and d.Name=="RemoteFunction" then RFunc=d end if not REvt and d:IsA("RemoteEvent") and d.Name=="RemoteEvent" then REvt=d end if RFunc and REvt then break end end end) end
    if RFunc and REvt then remoteFound=true end
end

local fireID, fishFuncID, fishEvtID, castID = nil, nil, nil, nil
local KF={645547,960203,1102592,1996080,6965833,7475803}
local KFISH={415444,662421,645547}
local KDROP={417203,662663,2039847}
local KCAST={427985,415444,645547}

-- STATE
local S = {
    tpResOn=false,tpLoop=false,tpCount=0,frzLoop=false,
    selRes=nil,selChest=nil,chIdx=1,selIsland=nil,islIdx=1,selKey=nil,selSurvivor=nil,selTablet=nil,selBoss=nil,selFishRes=nil,
    tpDelay=0.2,tpDist=10,
    frzWraithOn=false,frzWraithRun=false,
    autoFireOn=false,autoFireRun=false,fireCnt=0,fireDelay=0.03,fireRange=200,
    infAmmoOn=false,infAmmoRun=false,
    maxDmgOn=false,maxDmgRun=false,
    autoFoodOn=false,autoFoodRun=false,foodThresh=50,hpThresh=50,
    flyOn=false,flySpeed=80,flyConn=nil,flyUp=false,flyDown=false,
    walkSpeedOn=false,walkSpeed=32,walkConn=nil,
    autoResOn=false,autoResRun=false,autoResCnt=0,autoResDelay=0.5,
    autoFishOn=false,autoFishRun=false,fishCnt=0,fishDelay=0.5,
    autoFishV2On=false,autoFishV2Run=false,fishV2Cnt=0,fishV2Delay=0.5,
    frozen={},frzC=nil,
    RLIST={},RMAP={},CLIST={},CMAP={},ILIST={},IMAP={},
    keysList={},keysMap={},survList={},survMap={},tabList={},tabMap={},bossList={},bossMap={},
    -- CACHE (session only)
    cachedIslands={},cachedKeys={},cachedSurv={},cachedTab={},cachedBoss={},
    exploring=false,
    gui={},activeTab=CONFIG.activeTab or "Main",
}

-- SCAN
local ATTR_PRIORITY={"Item","Resource","Grabber","Food","ItemType"}
local function getResData(obj) local a=obj:GetAttributes() local d={} for _,n in ipairs(ATTR_PRIORITY) do if a[n]~=nil then d[n]=tostring(a[n]) end end if next(d) then return d end return nil end
local function scanRes()
    local rM,rL={},{} local c=workspace:FindFirstChild("DebrisField")
    if c then for _,o in pairs(c:GetChildren()) do local d=getResData(o) if d then local dn,ig=nil,false
        if d.Food then dn="🍖 All Food" ig=true
        elseif d.Item and d.Item:lower():find("ammo") then dn="🔫 All Ammo" ig=true
        elseif d.Resource and d.Resource:lower():find("ammo") then dn="🔫 All Ammo" ig=true
        elseif d.ItemType then dn=d.ItemType
        elseif d.Item then dn=d.Item
        elseif d.Resource then dn=d.Resource
        elseif d.Grabber then dn=d.Grabber end
        if dn and not rM[dn] then rM[dn]={Name=dn,Source="DebrisField",First=o,IsGrouped=ig,Data=d} table.insert(rL,dn) end
    end end end
    table.sort(rL) S.RLIST,S.RMAP=rL,rM
end
local function getResInst(dn) local info=S.RMAP[dn] if not info then return {} end local inst={} local c=workspace:FindFirstChild(info.Source) if not c then return inst end
    for _,o in pairs(c:GetChildren()) do local d=getResData(o) if d then
        if info.IsGrouped then
            if info.Name=="🍖 All Food" and d.Food then table.insert(inst,o)
            elseif info.Name=="🔫 All Ammo" then local n1=(d.Item or ""):lower() local n2=(d.Resource or ""):lower() if n1:find("ammo") or n2:find("ammo") then table.insert(inst,o) end end
        else
            if d.ItemType==info.Name then table.insert(inst,o)
            elseif d.Item==info.Name and not d.ItemType then table.insert(inst,o)
            elseif d.Resource==info.Name and not d.Item and not d.ItemType then table.insert(inst,o)
            elseif d.Grabber==info.Name and not d.Resource and not d.Item and not d.ItemType then table.insert(inst,o) end
        end
    end end return inst
end
local function scanChests() local n,m={},{} local c=workspace:FindFirstChild("Chests") if c then for _,o in pairs(c:GetChildren()) do if not m[o.Name] then m[o.Name]={I={o}} table.insert(n,o.Name) else table.insert(m[o.Name].I,o) end end end table.sort(n) S.CLIST,S.CMAP=n,m end
local function getCI(cn) local inst={} local c=workspace:FindFirstChild("Chests") if c then for _,o in pairs(c:GetChildren()) do if o.Name==cn then table.insert(inst,o) end end end return inst end
local function scanIslands() local n,m={},{} local c=workspace:FindFirstChild("IslandContainer") if c then for _,o in pairs(c:GetChildren()) do if not m[o.Name] then m[o.Name]={I={o}} table.insert(n,o.Name) else table.insert(m[o.Name].I,o) end end end table.sort(n) S.ILIST,S.IMAP=n,m end
local function getII(nm) local inst={} local c=workspace:FindFirstChild("IslandContainer") if c then for _,o in pairs(c:GetChildren()) do if o.Name==nm then table.insert(inst,o) end end end return inst end

-- Get position from object
local function getObjPos(obj)
    if not obj or not obj.Parent then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        for _, p in pairs(obj:GetDescendants()) do
            if p:IsA("BasePart") then return p.Position end
        end
    end
    return nil
end

local function scanSpecialTargets()
    local ic = workspace:FindFirstChild("IslandContainer")
    if not ic then return end
    S.keysMap={} S.keysList={}
    local function findKey(iName,label) local island=ic:FindFirstChild(iName) if island then local pd=island:FindFirstChild("Pedestal") if pd then local key=pd:FindFirstChild("Key") if key then S.keysMap[label]=key table.insert(S.keysList,label) end end end end
    findKey("TempleIsland","🗝️ Temple Key") findKey("SkullIsland","🗝️ Skull Key")
    S.survMap={} S.survList={}
    for _,s in ipairs({{i="CageIsland",n="Dr. Madeline"},{i="PirateChallengeIsland",n="Prof. Erik"},{i="TrappedIsland",n="Cpt. Stephen"}}) do local isl=ic:FindFirstChild(s.i) if isl then local npc=isl:FindFirstChild(s.n) if npc then S.survMap[s.n]=npc table.insert(S.survList,s.n) end end end
    S.tabMap={} S.tabList={}
    for _,t in ipairs({{i="SquidIslandMain",c="AncientTablet1",l="Ancient Tablet 1"},{i="SquidIsland42",c="Dropper",l="Dropper 42"},{i="SquidIsland23",c={"Pedestal","TabletSlot"},l="Tablet Slot 23"},{i="SquidIsland25",c={"Pedestal","TabletSlot"},l="Tablet Slot 25"},{i="SquidIsland16",c="SacrificialBowl",l="Sacrificial Bowl 16"}}) do local isl=ic:FindFirstChild(t.i) if isl then local tg=isl if type(t.c)=="table" then for _,seg in ipairs(t.c) do if tg then tg=tg:FindFirstChild(seg) end end else tg=tg:FindFirstChild(t.c) end if tg then S.tabMap[t.l]=tg table.insert(S.tabList,t.l) end end end
    S.bossMap={} S.bossList={}
    for _,b in ipairs({{i="PirateStronghold",c={"Ignore","Door1"},l="Pirate Stronghold"},{i="GhostGalleon",c=nil,l="Ghost Galleon"},{i="CargoShip",c="Containers",l="Cargo Ship"},{i="DynamiteAlienIsland",c=nil,l="Dynamite Alien"}}) do local isl=ic:FindFirstChild(b.i) if isl then local tg=isl if b.c then if type(b.c)=="table" then for _,seg in ipairs(b.c) do if tg then tg=tg:FindFirstChild(seg) end end else tg=tg:FindFirstChild(b.c) end end if tg then S.bossMap[b.l]=tg table.insert(S.bossList,b.l) end end end
    table.sort(S.keysList) table.sort(S.survList) table.sort(S.tabList) table.sort(S.bossList)
end

-- ============================================
-- AUTO CACHE SYSTEM (Option D)
-- Otomatis cache setiap kali objek terdeteksi
-- ============================================
local function autoCacheTargets()
    -- Auto-cache: setiap objek yang live, simpan posisinya
    for _, iname in ipairs(S.ILIST) do
        local inst = getII(iname)
        if #inst > 0 then
            local pos = getObjPos(inst[1])
            if pos then S.cachedIslands[iname] = {Position=pos, Time=tick()} end
        end
    end
    for label, obj in pairs(S.keysMap) do
        local pos = getObjPos(obj) if pos then S.cachedKeys[label] = pos end
    end
    for label, obj in pairs(S.survMap) do
        local pos = getObjPos(obj) if pos then S.cachedSurv[label] = pos end
    end
    for label, obj in pairs(S.tabMap) do
        local pos = getObjPos(obj) if pos then S.cachedTab[label] = pos end
    end
    for label, obj in pairs(S.bossMap) do
        local pos = getObjPos(obj) if pos then S.cachedBoss[label] = pos end
    end
end

-- Merged lists (live + cached)
local function getMergedList(liveList, cachedMap)
    local merged, seen = {}, {}
    for _, name in ipairs(liveList) do if not seen[name] then table.insert(merged, name) seen[name]=true end end
    for name in pairs(cachedMap) do if not seen[name] then table.insert(merged, name .. " 💾") seen[name]=true end end
    table.sort(merged)
    return merged
end

-- Strip cache marker
local function stripCache(name) return (name:gsub(" 💾$", "")) end

-- TP with cache fallback
local function tpToTarget(name, liveMap, cachedMap)
    local realName = stripCache(name)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- Try live first
    if liveMap[realName] then
        local pos = getObjPos(liveMap[realName])
        if pos then hrp.CFrame = CFrame.new(pos + Vector3.new(0,5,0)) return true end
    end
    -- Fallback to cached
    if cachedMap[realName] then
        local pos = cachedMap[realName]
        if type(pos) == "table" then pos = pos.Position end
        if pos then hrp.CFrame = CFrame.new(pos + Vector3.new(0,5,0)) return true end
    end
    return false
end

-- ============================================
-- EXPLORE FUNCTION (Option D - ReplicationFocus)
-- ============================================
local function exploreAllIslands(statusCallback)
    if S.exploring then return end
    S.exploring = true
    
    local char = player.Character
    local originalFocus = nil
    pcall(function() originalFocus = player.ReplicationFocus end)
    
    -- Create dummy part
    local dummy = Instance.new("Part")
    dummy.Name = "ExploreFocus_v29"
    dummy.Anchored = true
    dummy.CanCollide = false
    dummy.Transparency = 1
    dummy.Size = Vector3.new(1,1,1)
    dummy.Parent = workspace
    
    pcall(function() player.ReplicationFocus = dummy end)
    
    if statusCallback then statusCallback("Scanning existing...") end
    scanIslands() scanSpecialTargets() autoCacheTargets()
    
    -- Get existing island positions to know where to visit
    local visitPoints = {}
    local ic = workspace:FindFirstChild("IslandContainer")
    if ic then
        for _, isl in pairs(ic:GetChildren()) do
            local pos = getObjPos(isl)
            if pos then table.insert(visitPoints, {name=isl.Name, pos=pos}) end
        end
    end
    
    -- Also visit cached positions (in case original is unloaded)
    for name, data in pairs(S.cachedIslands) do
        local pos = type(data)=="table" and data.Position or data
        local found = false
        for _, vp in ipairs(visitPoints) do if vp.name == name then found = true break end end
        if not found and pos then table.insert(visitPoints, {name=name, pos=pos}) end
    end
    
    -- Grid explore if no islands found yet
    if #visitPoints == 0 then
        if statusCallback then statusCallback("No islands found, grid scan...") end
        local step = 800
        for x = -3000, 3000, step do
            for z = -3000, 3000, step do
                if not S.exploring then break end
                dummy.CFrame = CFrame.new(x, 200, z)
                task.wait(0.15)
                -- Quick scan
                scanIslands() scanSpecialTargets() autoCacheTargets()
            end
            if not S.exploring then break end
        end
    else
        -- Visit each known point
        for i, vp in ipairs(visitPoints) do
            if not S.exploring then break end
            if statusCallback then statusCallback("Visit "..i.."/"..#visitPoints.." "..vp.name) end
            dummy.CFrame = CFrame.new(vp.pos.X, vp.pos.Y + 100, vp.pos.Z)
            task.wait(0.4) -- wait for streaming
            
            -- Rescan & cache after streaming
            scanIslands() scanSpecialTargets() autoCacheTargets()
        end
    end
    
    -- Restore
    pcall(function() player.ReplicationFocus = originalFocus end)
    dummy:Destroy()
    S.exploring = false
    
    if statusCallback then
        statusCallback(string.format("✅ Done | 🏝️%d 🗝️%d 🧑%d 📜%d 👹%d",
            #S.ILIST, #S.keysList, #S.survList, #S.tabList, #S.bossList))
    end
end

-- Init scan
scanRes() scanChests() scanIslands() scanSpecialTargets() autoCacheTargets()

-- Background auto refresh 2s + auto cache
task.spawn(function()
    while true do
        task.wait(2)
        pcall(function() scanRes() scanChests() scanIslands() scanSpecialTargets() autoCacheTargets() end)
    end
end)

-- HELPERS
local function frzP(p) if not p:IsA("BasePart") then return end pcall(function() p.Anchored=true p.Velocity=Vector3.zero p.RotVelocity=Vector3.zero p.CanCollide=false end) end
local function frzO(obj) if obj:IsA("BasePart") then frzP(obj) elseif obj:IsA("Model") then for _,d in pairs(obj:GetDescendants()) do if d:IsA("BasePart") then frzP(d) end end end end
local function mvO(obj,cf) pcall(function() if obj:IsA("BasePart") then obj.CFrame=cf frzP(obj) elseif obj:IsA("Model") then if obj.PrimaryPart then obj:PivotTo(cf) else local fp,pts=nil,{} for _,p in pairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(pts,p) if not fp then fp=p end end end if fp then local d=cf.Position-fp.Position for _,p in pairs(pts) do p.CFrame=p.CFrame+d end end end for _,d in pairs(obj:GetDescendants()) do if d:IsA("BasePart") then frzP(d) end end end end) end
local function fpO(obj,cf) pcall(function() if obj:IsA("BasePart") then obj.CFrame=cf obj.Anchored=true obj.Velocity=Vector3.zero obj.RotVelocity=Vector3.zero elseif obj:IsA("Model") then if obj.PrimaryPart then obj:PivotTo(cf) obj.PrimaryPart.Anchored=true else local fp,pts=nil,{} for _,p in pairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(pts,p) if not fp then fp=p end end end if fp then local d=cf.Position-fp.Position for _,p in pairs(pts) do p.CFrame=p.CFrame+d p.Anchored=true end end end end end) end
local function startFL() if S.frzLoop then return end S.frzLoop=true S.frzC=RS.Heartbeat:Connect(function() if not S.frzLoop then if S.frzC then S.frzC:Disconnect() S.frzC=nil end return end for o,c in pairs(S.frozen) do if o and o.Parent then fpO(o,c) else S.frozen[o]=nil end end end) end
local function stopFL() S.frzLoop=false if S.frzC then S.frzC:Disconnect() S.frzC=nil end for o in pairs(S.frozen) do pcall(function() if o and o.Parent then if o:IsA("BasePart") then o.Anchored=false o.CanCollide=true elseif o:IsA("Model") then for _,d in pairs(o:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=false d.CanCollide=true end end end end end) end S.frozen={} end
local function tpTo(target) local char=player.Character if not char then return end local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return end local cf if target:IsA("BasePart") then cf=target.CFrame+Vector3.new(0,5,0) elseif target:IsA("Model") then if target.PrimaryPart then cf=target.PrimaryPart.CFrame+Vector3.new(0,5,0) else for _,p in pairs(target:GetDescendants()) do if p:IsA("BasePart") then cf=p.CFrame+Vector3.new(0,5,0) break end end end end if cf then hrp.CFrame=cf end end

local function getWeaponType(tool) local n=tool.Name:lower() if n:find("laser") then return "Laser","~sLaser","~sShoot" elseif n:find("magma") or n:find("staff") then return "Staff","~s"..tool.Name,"~sFire" elseif n:find("cannon") then return "Cannon","~s"..tool.Name,"~sFire" elseif n:find("bow") then return "Bow","~s"..tool.Name,"~sShoot" end return "Gun","~sGun","~sShoot" end
local function smartFire(tool,handle,tp) if not RFunc then findRemotes() end if not RFunc then return false end local wt,tid,act=getWeaponType(tool) local ps=string.format("~v%.4f,%.4f,%.4f",tp.X,tp.Y,tp.Z) local ts=string.format("~t{1=~f%.4f,%.4f,%.4f:0.0797,-0.0508,0.9955Z-1}",tp.X,tp.Y,tp.Z) if fireID then local ok=false if wt=="Gun" then ok=pcall(function() RFunc:InvokeServer(fireID,"ToolReplicator",tid,act,handle,ts) end) else ok=pcall(function() RFunc:InvokeServer(fireID,"ToolReplicator",tid,act,ps) end) end if ok then return true end if wt=="Gun" then ok=pcall(function() RFunc:InvokeServer(fireID,"ToolReplicator",tid,act,ps) end) else ok=pcall(function() RFunc:InvokeServer(fireID,"ToolReplicator",tid,act,handle,ts) end) end if ok then return true end fireID=nil end for _,id in ipairs(KF) do local ok=false if wt=="Gun" then ok=pcall(function() RFunc:InvokeServer(id,"ToolReplicator",tid,act,handle,ts) end) else ok=pcall(function() RFunc:InvokeServer(id,"ToolReplicator",tid,act,ps) end) end if ok then fireID=id return true end if wt=="Gun" then ok=pcall(function() RFunc:InvokeServer(id,"ToolReplicator",tid,act,ps) end) else ok=pcall(function() RFunc:InvokeServer(id,"ToolReplicator",tid,act,handle,ts) end) end if ok then fireID=id return true end end return false end
local function getCPos(cr) if cr:IsA("Model") then local h=cr:FindFirstChild("HumanoidRootPart") if h then return h.Position end local r=cr:FindFirstChild("Root") if r then return r.Position end if cr.PrimaryPart then return cr.PrimaryPart.Position end for _,p in pairs(cr:GetDescendants()) do if p:IsA("BasePart") then return p.Position end end elseif cr:IsA("BasePart") then return cr.Position end return nil end
local function isAlive(cr) if not cr or not cr.Parent then return false end if cr.Name:find("_CLIENT") then return false end local hum=cr:FindFirstChildOfClass("Humanoid") if hum and hum.Health<=0 then return false end return true end
local function getNearest() local char=player.Character if not char then return nil,nil end local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return nil,nil end local myP=hrp.Position local nr,nd=nil,math.huge local cc=workspace:FindFirstChild("CreatureContainer") if not cc then return nil,nil end for _,cr in pairs(cc:GetChildren()) do if isAlive(cr) then local cp=getCPos(cr) if cp then local d=(cp-myP).Magnitude if d<nd and d<=S.fireRange then nr=cr nd=d end end end end return nr,nd end
local function getGun() local char=player.Character local bp=player:FindFirstChild("Backpack") if char then for _,t in pairs(char:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("IsGun")==true then local h=t:FindFirstChild("Handle") if h then return t,h end end end end if bp then for _,t in pairs(bp:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("IsGun")==true then local h=t:FindFirstChild("Handle") if h then return t,h end end end end return nil,nil end
local function freezeWraiths() local cc=workspace:FindFirstChild("CreatureContainer") if not cc then return 0 end local c=0 for _,obj in pairs(cc:GetChildren()) do if (obj.Name=="Wraith" or obj.Name=="Wraith_CLIENT") and obj:IsA("Model") then local root=obj:FindFirstChild("Root") if root and root:IsA("BasePart") then pcall(function() root.Anchored=true root.Velocity=Vector3.zero end) end if obj.Name=="Wraith_CLIENT" then for _,p in pairs(obj:GetChildren()) do if p:IsA("BasePart") or p:IsA("MeshPart") then pcall(function() p.Anchored=true end) end end end if obj.Name=="Wraith" then c=c+1 end end end return c end
local function unfreezeWraiths() local cc=workspace:FindFirstChild("CreatureContainer") if not cc then return end for _,obj in pairs(cc:GetChildren()) do if (obj.Name=="Wraith" or obj.Name=="Wraith_CLIENT") and obj:IsA("Model") then for _,p in pairs(obj:GetChildren()) do if p:IsA("BasePart") or p:IsA("MeshPart") then pcall(function() p.Anchored=false end) end end end end end

local FOOD_ITEMS={"Chowder","Alien Soup"} local HP_ITEMS={"Bandage","Medkit"}
local function findItemInBackpack(nm) local char=player.Character local bp=player:FindFirstChild("Backpack") if bp then for _,t in pairs(bp:GetChildren()) do if t:IsA("Tool") and t.Name==nm then return t end end end if char then for _,t in pairs(char:GetChildren()) do if t:IsA("Tool") and t.Name==nm then return t end end end return nil end
local function getPlayerHP() local char=player.Character if not char then return 100 end local hum=char:FindFirstChildOfClass("Humanoid") if not hum then return 100 end return (hum.Health/hum.MaxHealth)*100 end
local function useConsumable(items, itemType) local char=player.Character if not char then return false end local hum=char:FindFirstChildOfClass("Humanoid") if not hum then return false end local prev=nil for _,t in pairs(char:GetChildren()) do if t:IsA("Tool") then prev=t.Name break end end local tool,nm=nil,nil for _,n in ipairs(items) do tool=findItemInBackpack(n) if tool then nm=n break end end if not tool then return false end if tool.Parent~=char then hum:EquipTool(tool) task.wait(0.5) end for i=1,60 do if not S.autoFoodOn then break end if itemType=="food" then local f=player:GetAttribute("Food") or 100 if f>=95 then break end elseif itemType=="hp" then local hp=getPlayerHP() if hp>=95 then break end end local c2=player.Character if not c2 then break end local exists=false for _,t in pairs(c2:GetChildren()) do if t:IsA("Tool") and t.Name==nm then exists=true pcall(function() t:Activate() end) break end end if not exists then break end task.wait(0.3) end task.wait(0.3) pcall(function() local c2=player.Character if c2 then local h2=c2:FindFirstChildOfClass("Humanoid") if h2 then h2:UnequipTools() end end end) task.wait(0.3) if prev then local wc=false for _,n in ipairs(FOOD_ITEMS) do if prev==n then wc=true break end end for _,n in ipairs(HP_ITEMS) do if prev==n then wc=true break end end if not wc then pcall(function() local c2=player.Character if not c2 then return end local h2=c2:FindFirstChildOfClass("Humanoid") if not h2 then return end local bp2=player:FindFirstChild("Backpack") if not bp2 then return end for _,t in pairs(bp2:GetChildren()) do if t:IsA("Tool") and t.Name==prev then h2:EquipTool(t) break end end end) end end return true end

local function fireGuiButton(btn) if not btn then return false end local ok=false pcall(function() for _,c in pairs(getconnections(btn.Activated)) do c:Fire() ok=true end end) if ok then return true end pcall(function() for _,c in pairs(getconnections(btn.MouseButton1Click)) do c:Fire() ok=true end end) if ok then return true end pcall(function() for _,c in pairs(getconnections(btn.MouseButton1Down)) do c:Fire() end task.wait(0.05) for _,c in pairs(getconnections(btn.MouseButton1Up)) do c:Fire() end ok=true end) return ok end
local function findTouchButton(txt) local pg=player:FindFirstChild("PlayerGui") if not pg then return nil end local tc=pg:FindFirstChild("TouchControls") if not tc then return nil end local bh=tc:FindFirstChild("ButtonHolder") if not bh then return nil end local slots=bh:FindFirstChild("Slots") if not slots then return nil end for _,slot in pairs(slots:GetChildren()) do if slot:IsA("GuiButton") then local lbl=slot:FindFirstChild("TextLabel") if lbl and lbl.Text==txt then local vis=slot.Visible local p=slot.Parent while p and p~=pg do if p:IsA("GuiObject") and not p.Visible then vis=false break end p=p.Parent end if vis then return slot end end end end return nil end
local function moveResToPlayer(obj, dist) dist=dist or 3 local char=player.Character if not char then return false end local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return false end local tp=hrp.Position+(hrp.CFrame.LookVector*dist)-Vector3.new(0,2,0) local tcf=CFrame.new(tp) pcall(function() if obj:IsA("BasePart") then obj.CFrame=tcf obj.Velocity=Vector3.zero elseif obj:IsA("Model") then if obj.PrimaryPart then obj:PivotTo(tcf) pcall(function() obj.PrimaryPart.Velocity=Vector3.zero end) else local fp,pts=nil,{} for _,p in pairs(obj:GetDescendants()) do if p:IsA("BasePart") then table.insert(pts,p) if not fp then fp=p end end end if fp then local d=tp-fp.Position for _,p in pairs(pts) do p.CFrame=p.CFrame+d p.Velocity=Vector3.zero end end end end end) return true end
local function autoDragRes(obj) if not obj or not obj.Parent then return false end for i=1,3 do moveResToPlayer(obj,2) task.wait(0.15) end local dbtn=nil for i=1,20 do dbtn=findTouchButton("Drag") if dbtn then break end if i%3==0 then moveResToPlayer(obj,2) end task.wait(0.1) end if not dbtn then return false end fireGuiButton(dbtn) task.wait(0.4) local abtn=nil for i=1,15 do abtn=findTouchButton("Collect") if abtn then break end abtn=findTouchButton("Eat") if abtn then break end abtn=findTouchButton("Store") if abtn then break end task.wait(0.1) end if not abtn then abtn=findTouchButton("Drop") end if abtn then fireGuiButton(abtn) task.wait(0.3) return true end return false end

local function cleanupFly(char) if not char then return end local hrp=char:FindFirstChild("HumanoidRootPart") if hrp then if hrp:FindFirstChild("FlyGyro") then hrp.FlyGyro:Destroy() end if hrp:FindFirstChild("FlyVel") then hrp.FlyVel:Destroy() end end local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.PlatformStand=false end end
local function startFly() local char=player.Character if not char then return end local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return end local hum=char:FindFirstChildOfClass("Humanoid") cleanupFly(char) local bg=Instance.new("BodyGyro") bg.Name="FlyGyro" bg.P=9e4 bg.D=500 bg.MaxTorque=Vector3.new(9e9,9e9,9e9) bg.CFrame=hrp.CFrame bg.Parent=hrp local bv=Instance.new("BodyVelocity") bv.Name="FlyVel" bv.MaxForce=Vector3.new(9e9,9e9,9e9) bv.Velocity=Vector3.zero bv.Parent=hrp if hum then hum.PlatformStand=true end if S.flyConn then S.flyConn:Disconnect() end local cam=workspace.CurrentCamera S.flyConn=RS.RenderStepped:Connect(function() if not S.flyOn then return end local c2=player.Character if not c2 then return end local h2=c2:FindFirstChild("HumanoidRootPart") if not h2 then return end local hum2=c2:FindFirstChildOfClass("Humanoid") local gyro=h2:FindFirstChild("FlyGyro") local vel=h2:FindFirstChild("FlyVel") if not gyro or not vel then if S.flyOn then task.defer(function() if S.flyOn then startFly() end end) end return end local camCF=cam.CFrame local mv=Vector3.zero local camL=Vector3.new(camCF.LookVector.X,0,camCF.LookVector.Z) if camL.Magnitude>0.01 then camL=camL.Unit end local camR=Vector3.new(camCF.RightVector.X,0,camCF.RightVector.Z) if camR.Magnitude>0.01 then camR=camR.Unit end pcall(function() if UIS:IsKeyDown(Enum.KeyCode.W) then mv=mv+camL end if UIS:IsKeyDown(Enum.KeyCode.S) then mv=mv-camL end if UIS:IsKeyDown(Enum.KeyCode.A) then mv=mv-camR end if UIS:IsKeyDown(Enum.KeyCode.D) then mv=mv+camR end if UIS:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then mv=mv-Vector3.new(0,1,0) end end) if hum2 then local md=hum2.MoveDirection if md.Magnitude>0.1 then mv=mv+Vector3.new(md.X,0,md.Z) end end if S.flyUp then mv=mv+Vector3.new(0,1,0) end if S.flyDown then mv=mv-Vector3.new(0,1,0) end if mv.Magnitude>0 then vel.Velocity=mv.Unit*S.flySpeed else vel.Velocity=Vector3.zero end gyro.CFrame=camCF end) if S.gui.flyUpBtn then S.gui.flyUpBtn.Visible=true end if S.gui.flyDownBtn then S.gui.flyDownBtn.Visible=true end end
local function stopFly() S.flyOn=false if S.flyConn then S.flyConn:Disconnect() S.flyConn=nil end cleanupFly(player.Character) S.flyUp=false S.flyDown=false if S.gui.flyUpBtn then S.gui.flyUpBtn.Visible=false end if S.gui.flyDownBtn then S.gui.flyDownBtn.Visible=false end end
player.CharacterAdded:Connect(function() task.wait(1) if S.flyOn then startFly() end end)

local function startWalkSpeed() if S.walkConn then S.walkConn:Disconnect() end S.walkConn = RS.Heartbeat:Connect(function() if not S.walkSpeedOn then if S.walkConn then S.walkConn:Disconnect() S.walkConn=nil end return end pcall(function() local char=player.Character if char then local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.WalkSpeed = S.walkSpeed end end end) end) end
local function stopWalkSpeed() S.walkSpeedOn=false if S.walkConn then S.walkConn:Disconnect() S.walkConn=nil end pcall(function() local char=player.Character if char then local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.WalkSpeed = 16 end end end) end

local function findFishingRod() local char=player.Character local bp=player:FindFirstChild("Backpack") if char then for _,t in pairs(char:GetChildren()) do if t:IsA("Tool") and t.Name=="Fishing Rod" then return t end end end if bp then for _,t in pairs(bp:GetChildren()) do if t:IsA("Tool") and t.Name=="Fishing Rod" then return t end end end return nil end
local function doInstantFishing() if not RFunc or not REvt then findRemotes() end if not RFunc or not REvt then return false end local rod=findFishingRod() if not rod then return false end local char=player.Character if not char then return false end local hum=char:FindFirstChildOfClass("Humanoid") if not hum then return false end if rod.Parent~=char then hum:EquipTool(rod) task.wait(0.5) end local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return false end local pos=hrp.Position local posStr=string.format("~f%.4f,%.4f,%.4f:-0.0842,-0,-0.9965Z0",pos.X,pos.Y,pos.Z) local funcOk=false if fishFuncID then funcOk=pcall(function() RFunc:InvokeServer(fishFuncID,"ToolReplicator","~sFishing Rod","~sFishPoof",posStr) end) if not funcOk then fishFuncID=nil end end if not funcOk then for _,id in ipairs(KFISH) do funcOk=pcall(function() RFunc:InvokeServer(id,"ToolReplicator","~sFishing Rod","~sFishPoof",posStr) end) if funcOk then fishFuncID=id break end end end if not funcOk then return false end task.wait(0.3) local df=workspace:FindFirstChild("DebrisField") if not df then return false end local np,nd=nil,math.huge for _,obj in pairs(df:GetChildren()) do for _,p in pairs(obj:GetDescendants()) do if p:IsA("BasePart") then local d=(p.Position-hrp.Position).Magnitude if d<30 and d<nd then nd=d np=p end end end end if np then local evtOk=false if fishEvtID then evtOk=pcall(function() REvt:FireServer(fishEvtID,"GiveUpOwnership",np,"~v0,0,0") end) if not evtOk then fishEvtID=nil end end if not evtOk then for _,id in ipairs(KDROP) do evtOk=pcall(function() REvt:FireServer(id,"GiveUpOwnership",np,"~v0,0,0") end) if evtOk then fishEvtID=id break end end end end return true end
local function doCast() if not RFunc then findRemotes() end if not RFunc then return false end local ok=false if castID then ok=pcall(function() RFunc:InvokeServer(castID,"ToolReplicator","~sFishing Rod","~sCast") end) if not ok then castID=nil end end if not ok then for _,id in ipairs(KCAST) do ok=pcall(function() RFunc:InvokeServer(id,"ToolReplicator","~sFishing Rod","~sCast") end) if ok then castID=id break end end end return ok end
local function doFishPoof() if not RFunc then return false end local hrp=player.Character and player.Character:FindFirstChild("HumanoidRootPart") if not hrp then return false end local pos=hrp.Position local posStr=string.format("~f%.4f,%.4f,%.4f:-0.0842,-0,-0.9965Z0",pos.X,pos.Y,pos.Z) local ok=false if fishFuncID then ok=pcall(function() RFunc:InvokeServer(fishFuncID,"ToolReplicator","~sFishing Rod","~sFishPoof",posStr) end) if not ok then fishFuncID=nil end end if not ok then for _,id in ipairs(KFISH) do ok=pcall(function() RFunc:InvokeServer(id,"ToolReplicator","~sFishing Rod","~sFishPoof",posStr) end) if ok then fishFuncID=id break end end end return ok end
local function findResourceItem(rn) if not rn then return nil end local info=S.RMAP[rn] if not info then return nil end local hrp=player.Character and player.Character:FindFirstChild("HumanoidRootPart") if not hrp then return nil end local inst=getResInst(rn) local np,nd=nil,math.huge for _,obj in ipairs(inst) do if obj:IsA("Model") then for _,p in pairs(obj:GetDescendants()) do if p:IsA("BasePart") then local d=(p.Position-hrp.Position).Magnitude if d<nd then nd=d np=p end end end elseif obj:IsA("BasePart") then local d=(obj.Position-hrp.Position).Magnitude if d<nd then nd=d np=obj end end end return np end
local function doGiveUpOwnershipOnResource() if not REvt then return false end if not S.selFishRes then return false end local part=findResourceItem(S.selFishRes) if not part then return false end local ok=false if fishEvtID then ok=pcall(function() REvt:FireServer(fishEvtID,"GiveUpOwnership",part,"~v0,0,0") end) if not ok then fishEvtID=nil end end if not ok then for _,id in ipairs(KDROP) do ok=pcall(function() REvt:FireServer(id,"GiveUpOwnership",part,"~v0,0,0") end) if ok then fishEvtID=id break end end end return ok end
local function doFishingV2Loop() doCast() task.wait(0.3) doFishPoof() task.wait(0.3) doGiveUpOwnershipOnResource() task.wait(0.2) return true end

print("✅ v29 PART 1 loaded!")
-- ============================================
-- v29 PART 2 - CUSTOM UI FRAMEWORK
-- ============================================

-- ============================================
-- MAIN GUI CREATION
-- ============================================
local guiParent = playerGui
pcall(function() if gethui then guiParent = gethui() end end)

local SG = Instance.new("ScreenGui")
SG.Name = "BSSHub_v29"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = false
pcall(function() SG.Parent = guiParent end)
if not SG.Parent then SG.Parent = playerGui end

-- FLY BUTTONS (separate ScreenGui, always on top)
local FlyGui = Instance.new("ScreenGui")
FlyGui.Name = "FlyBtn_v29"
FlyGui.ResetOnSpawn = false
FlyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
FlyGui.IgnoreGuiInset = true
pcall(function() FlyGui.Parent = guiParent end)
if not FlyGui.Parent then FlyGui.Parent = playerGui end

S.gui.flyUpBtn = Instance.new("TextButton", FlyGui)
S.gui.flyUpBtn.Size = UDim2.new(0, 45, 0, 45)
S.gui.flyUpBtn.Position = UDim2.new(1, -55, 0.5, -52)
S.gui.flyUpBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 220)
S.gui.flyUpBtn.BackgroundTransparency = 0.25
S.gui.flyUpBtn.Text = "▲"
S.gui.flyUpBtn.TextSize = 20
S.gui.flyUpBtn.Font = Enum.Font.GothamBold
S.gui.flyUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
S.gui.flyUpBtn.BorderSizePixel = 0
S.gui.flyUpBtn.Visible = false
S.gui.flyUpBtn.ZIndex = 1000
S.gui.flyUpBtn.Active = true
Instance.new("UICorner", S.gui.flyUpBtn).CornerRadius = UDim.new(0, 12)
local ust = Instance.new("UIStroke", S.gui.flyUpBtn) ust.Color = Color3.fromRGB(255,255,255) ust.Thickness = 1.5 ust.Transparency = 0.5

S.gui.flyDownBtn = Instance.new("TextButton", FlyGui)
S.gui.flyDownBtn.Size = UDim2.new(0, 45, 0, 45)
S.gui.flyDownBtn.Position = UDim2.new(1, -55, 0.5, 7)
S.gui.flyDownBtn.BackgroundColor3 = Color3.fromRGB(220, 100, 60)
S.gui.flyDownBtn.BackgroundTransparency = 0.25
S.gui.flyDownBtn.Text = "▼"
S.gui.flyDownBtn.TextSize = 20
S.gui.flyDownBtn.Font = Enum.Font.GothamBold
S.gui.flyDownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
S.gui.flyDownBtn.BorderSizePixel = 0
S.gui.flyDownBtn.Visible = false
S.gui.flyDownBtn.ZIndex = 1000
S.gui.flyDownBtn.Active = true
Instance.new("UICorner", S.gui.flyDownBtn).CornerRadius = UDim.new(0, 12)
local dst = Instance.new("UIStroke", S.gui.flyDownBtn) dst.Color = Color3.fromRGB(255,255,255) dst.Thickness = 1.5 dst.Transparency = 0.5

S.gui.flyUpBtn.MouseButton1Down:Connect(function() S.flyUp=true end)
S.gui.flyUpBtn.MouseButton1Up:Connect(function() S.flyUp=false end)
S.gui.flyUpBtn.MouseLeave:Connect(function() S.flyUp=false end)
S.gui.flyDownBtn.MouseButton1Down:Connect(function() S.flyDown=true end)
S.gui.flyDownBtn.MouseButton1Up:Connect(function() S.flyDown=false end)
S.gui.flyDownBtn.MouseLeave:Connect(function() S.flyDown=false end)
S.gui.flyUpBtn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then S.flyUp=true end end)
S.gui.flyUpBtn.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then S.flyUp=false end end)
S.gui.flyDownBtn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then S.flyDown=true end end)
S.gui.flyDownBtn.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then S.flyDown=false end end)

-- ============================================
-- MAIN FRAME
-- ============================================
local sw, sh = getScreenSize()

-- Ensure position is valid (in screen bounds)
local function clampPos()
    local w = CONFIG.sizeW or defW
    local h = CONFIG.sizeH or defH
    local vw, vh = getScreenSize()
    if not CONFIG.posX or CONFIG.posX < -w+50 then CONFIG.posX = (vw - w) / 2 end
    if not CONFIG.posY or CONFIG.posY < 0 then CONFIG.posY = (vh - h) / 2 end
    if CONFIG.posX > vw - 50 then CONFIG.posX = vw - w end
    if CONFIG.posY > vh - 50 then CONFIG.posY = vh - h end
end
clampPos()

local MF = Instance.new("Frame", SG)
MF.Name = "MainFrame"
MF.Size = UDim2.new(0, CONFIG.sizeW, 0, CONFIG.sizeH)
MF.Position = UDim2.new(0, CONFIG.posX, 0, CONFIG.posY)
MF.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MF.BorderSizePixel = 0
MF.Active = true
MF.ClipsDescendants = true
MF.ZIndex = 10
Instance.new("UICorner", MF).CornerRadius = UDim.new(0, 12)
local mfs = Instance.new("UIStroke", MF) mfs.Color = Color3.fromRGB(100, 200, 255) mfs.Thickness = 2

-- Min/Max size for resize
local mfsz = Instance.new("UISizeConstraint", MF)
mfsz.MinSize = Vector2.new(260, 300)
mfsz.MaxSize = Vector2.new(500, 700)

-- ============================================
-- TITLE BAR
-- ============================================
local TB = Instance.new("Frame", MF)
TB.Name = "TitleBar"
TB.Size = UDim2.new(1, 0, 0, 40)
TB.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
TB.BorderSizePixel = 0
TB.ZIndex = 11
Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 12)
local tbp = Instance.new("Frame", TB)
tbp.Size = UDim2.new(1, 0, 0, 12)
tbp.Position = UDim2.new(0, 0, 1, -12)
tbp.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
tbp.BorderSizePixel = 0
tbp.ZIndex = 11

local titleLbl = Instance.new("TextLabel", TB)
titleLbl.Size = UDim2.new(1, -110, 1, 0)
titleLbl.Position = UDim2.new(0, 12, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🪨 " .. gameName
titleLbl.TextColor3 = Color3.fromRGB(100, 200, 255)
titleLbl.TextSize = 14
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
titleLbl.ZIndex = 12

-- Save button
local saveBtn = Instance.new("TextButton", TB)
saveBtn.Size = UDim2.new(0, 28, 0, 28)
saveBtn.Position = UDim2.new(1, -103, 0, 6)
saveBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 80)
saveBtn.Text = "💾"
saveBtn.TextSize = 14
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
saveBtn.BorderSizePixel = 0
saveBtn.ZIndex = 13
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 6)

-- Resize button
local resizeBtn = Instance.new("TextButton", TB)
resizeBtn.Size = UDim2.new(0, 28, 0, 28)
resizeBtn.Position = UDim2.new(1, -71, 0, 6)
resizeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
resizeBtn.Text = "⇲"
resizeBtn.TextSize = 16
resizeBtn.Font = Enum.Font.GothamBold
resizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resizeBtn.BorderSizePixel = 0
resizeBtn.ZIndex = 13
Instance.new("UICorner", resizeBtn).CornerRadius = UDim.new(0, 6)

-- Minimize button
local minBtn = Instance.new("TextButton", TB)
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -39, 0, 6)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
minBtn.Text = "—"
minBtn.TextSize = 16
minBtn.Font = Enum.Font.GothamBold
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.BorderSizePixel = 0
minBtn.ZIndex = 13
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- ============================================
-- TABS BAR
-- ============================================
local TabBar = Instance.new("ScrollingFrame", MF)
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -10, 0, 32)
TabBar.Position = UDim2.new(0, 5, 0, 45)
TabBar.BackgroundTransparency = 1
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 0
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.ClipsDescendants = true
TabBar.ZIndex = 11

local tabLayout = Instance.new("UIListLayout", TabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- ============================================
-- CONTENT AREA
-- ============================================
local Content = Instance.new("Frame", MF)
Content.Name = "Content"
Content.Size = UDim2.new(1, -6, 1, -84)
Content.Position = UDim2.new(0, 3, 0, 81)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ClipsDescendants = true
Content.ZIndex = 11

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
local tabs = {}
local tabButtons = {}
local currentTabFrame = nil

local function createTab(name, icon)
    -- Tab button
    local btn = Instance.new("TextButton", TabBar)
    btn.Name = name
    btn.Size = UDim2.new(0, 0, 1, 0)
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    btn.Text = "  " .. icon .. " " .. name .. "  "
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamSemibold
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.BorderSizePixel = 0
    btn.ZIndex = 12
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    -- Tab content frame
    local frame = Instance.new("ScrollingFrame", Content)
    frame.Name = name .. "Content"
    frame.Size = UDim2.new(1, -4, 1, 0)
    frame.Position = UDim2.new(0, 2, 0, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ScrollBarThickness = 4
    frame.ScrollBarImageColor3 = Color3.fromRGB(100, 200, 255)
    frame.CanvasSize = UDim2.new(0, 0, 0, 0)
    frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    frame.Visible = false
    frame.ZIndex = 11
    
    local layout = Instance.new("UIListLayout", frame)
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local padd = Instance.new("UIPadding", frame)
    padd.PaddingTop = UDim.new(0, 5)
    padd.PaddingBottom = UDim.new(0, 20)
    padd.PaddingLeft = UDim.new(0, 8)
    padd.PaddingRight = UDim.new(0, 8)
    
    tabs[name] = frame
    tabButtons[name] = btn
    
    btn.MouseButton1Click:Connect(function()
        for n, t in pairs(tabs) do
            t.Visible = false
            tabButtons[n].BackgroundColor3 = Color3.fromRGB(35, 35, 50)
            tabButtons[n].TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        frame.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        currentTabFrame = frame
        S.activeTab = name
        CONFIG.activeTab = name
        saveConfig()
    end)
    
    return frame
end

-- LayoutOrder helper
local function nxtLO(frame)
    local n = 0
    for _, c in pairs(frame:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") or c:IsA("TextLabel") then n = n + 1 end
    end
    return n + 1
end

-- Section
local function mkSection(parent, text)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 22)
    f.BackgroundTransparency = 1
    f.LayoutOrder = nxtLO(parent)
    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "── " .. text .. " ──"
    lbl.TextColor3 = Color3.fromRGB(120, 120, 160)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    return f
end

-- Toggle
local function mkToggle(parent, label, emoji)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 46)
    f.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    f.BorderSizePixel = 0
    f.LayoutOrder = nxtLO(parent)
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    
    local lb = Instance.new("TextLabel", f)
    lb.Size = UDim2.new(0.55, 0, 0, 20)
    lb.Position = UDim2.new(0, 12, 0, 6)
    lb.BackgroundTransparency = 1
    lb.Text = emoji .. " " .. label
    lb.TextColor3 = Color3.fromRGB(255, 255, 255)
    lb.TextSize = 12
    lb.Font = Enum.Font.GothamSemibold
    lb.TextXAlignment = Enum.TextXAlignment.Left
    
    local ct = Instance.new("TextLabel", f)
    ct.Size = UDim2.new(0.55, 0, 0, 14)
    ct.Position = UDim2.new(0, 12, 1, -18)
    ct.BackgroundTransparency = 1
    ct.Text = "Ready"
    ct.TextColor3 = Color3.fromRGB(130, 130, 160)
    ct.TextSize = 9
    ct.Font = Enum.Font.Gotham
    ct.TextXAlignment = Enum.TextXAlignment.Left
    
    local st = Instance.new("TextLabel", f)
    st.Size = UDim2.new(0, 30, 0, 16)
    st.Position = UDim2.new(1, -96, 0.5, -8)
    st.BackgroundTransparency = 1
    st.Text = "OFF"
    st.TextColor3 = Color3.fromRGB(255, 80, 80)
    st.TextSize = 10
    st.Font = Enum.Font.GothamBold
    
    local bt = Instance.new("TextButton", f)
    bt.Size = UDim2.new(0, 46, 0, 22)
    bt.Position = UDim2.new(1, -55, 0.5, -11)
    bt.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    bt.Text = ""
    bt.BorderSizePixel = 0
    Instance.new("UICorner", bt).CornerRadius = UDim.new(1, 0)
    
    local ci = Instance.new("Frame", bt)
    ci.Size = UDim2.new(0, 18, 0, 18)
    ci.Position = UDim2.new(0, 2, 0.5, -9)
    ci.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    ci.BorderSizePixel = 0
    Instance.new("UICorner", ci).CornerRadius = UDim.new(1, 0)
    
    local state = {value = false}
    local function setState(v)
        state.value = v
        if v then
            TS:Create(ci, TweenInfo.new(0.2), {Position = UDim2.new(1, -20, 0.5, -9)}):Play()
            TS:Create(bt, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 200, 200)}):Play()
            TS:Create(ci, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            st.Text = "ON" st.TextColor3 = Color3.fromRGB(80, 255, 200)
        else
            TS:Create(ci, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -9)}):Play()
            TS:Create(bt, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 80)}):Play()
            TS:Create(ci, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(180, 180, 180)}):Play()
            st.Text = "OFF" st.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end
    
    return {frame=f, button=bt, status=st, count=ct, setState=setState, getState=function() return state.value end}
end

-- Button
local function mkButton(parent, text, color)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1, 0, 0, 32)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.LayoutOrder = nxtLO(parent)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseEnter:Connect(function() TS:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Color3.new(color.R * 1.2, color.G * 1.2, color.B * 1.2)}):Play() end)
    b.MouseLeave:Connect(function() TS:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = color}):Play() end)
    return b
end

-- Input
local function mkInput(parent, label, emoji, defVal, unit)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 32)
    f.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    f.BorderSizePixel = 0
    f.LayoutOrder = nxtLO(parent)
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local lb = Instance.new("TextLabel", f)
    lb.Size = UDim2.new(0.5, 0, 1, 0)
    lb.Position = UDim2.new(0, 12, 0, 0)
    lb.BackgroundTransparency = 1
    lb.Text = emoji .. " " .. label
    lb.TextColor3 = Color3.fromRGB(255, 255, 255)
    lb.TextSize = 11
    lb.Font = Enum.Font.GothamSemibold
    lb.TextXAlignment = Enum.TextXAlignment.Left
    local inp = Instance.new("TextBox", f)
    inp.Size = UDim2.new(0, 48, 0, 22)
    inp.Position = UDim2.new(1, -100, 0.5, -11)
    inp.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    inp.Text = tostring(defVal)
    inp.TextColor3 = Color3.fromRGB(100, 200, 255)
    inp.TextSize = 12
    inp.Font = Enum.Font.GothamBold
    inp.BorderSizePixel = 0
    inp.ClearTextOnFocus = false
    Instance.new("UICorner", inp).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", inp).Color = Color3.fromRGB(100, 200, 255)
    local u = Instance.new("TextLabel", f)
    u.Size = UDim2.new(0, 40, 1, 0)
    u.Position = UDim2.new(1, -48, 0, 0)
    u.BackgroundTransparency = 1
    u.Text = unit
    u.TextColor3 = Color3.fromRGB(130, 130, 160)
    u.TextSize = 10
    u.Font = Enum.Font.Gotham
    u.TextXAlignment = Enum.TextXAlignment.Left
    return inp
end

-- Dropdown
local function mkDropdown(parent, label, emoji, options, callback)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 38)
    f.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    f.BorderSizePixel = 0
    f.ClipsDescendants = false
    f.ZIndex = 20
    f.LayoutOrder = nxtLO(parent)
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    
    local lb = Instance.new("TextLabel", f)
    lb.Size = UDim2.new(0, 50, 1, 0)
    lb.Position = UDim2.new(0, 10, 0, 0)
    lb.BackgroundTransparency = 1
    lb.Text = emoji
    lb.TextColor3 = Color3.fromRGB(255, 255, 255)
    lb.TextSize = 14
    lb.Font = Enum.Font.GothamBold
    lb.TextXAlignment = Enum.TextXAlignment.Left
    lb.ZIndex = 21
    
    local db = Instance.new("TextButton", f)
    db.Size = UDim2.new(1, -75, 0, 26)
    db.Position = UDim2.new(0, 60, 0.5, -13)
    db.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    db.Text = label .. " ▼"
    db.TextColor3 = Color3.fromRGB(100, 200, 255)
    db.TextSize = 10
    db.Font = Enum.Font.GothamBold
    db.BorderSizePixel = 0
    db.ZIndex = 21
    db.TextTruncate = Enum.TextTruncate.AtEnd
    Instance.new("UICorner", db).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", db).Color = Color3.fromRGB(100, 200, 255)
    
    local dl = Instance.new("ScrollingFrame", f)
    dl.Size = UDim2.new(1, -75, 0, 0)
    dl.Position = UDim2.new(0, 60, 0, 34)
    dl.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    dl.BorderSizePixel = 0
    dl.ClipsDescendants = true
    dl.Visible = false
    dl.ZIndex = 50
    dl.ScrollBarThickness = 4
    dl.ScrollBarImageColor3 = Color3.fromRGB(100, 200, 255)
    dl.CanvasSize = UDim2.new(0, 0, 0, 0)
    dl.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", dl).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", dl).Color = Color3.fromRGB(100, 200, 255)
    local dlL = Instance.new("UIListLayout", dl)
    dlL.Padding = UDim.new(0, 2)
    dlL.SortOrder = Enum.SortOrder.LayoutOrder
    local dlP = Instance.new("UIPadding", dl)
    dlP.PaddingTop = UDim.new(0, 4)
    dlP.PaddingBottom = UDim.new(0, 4)
    dlP.PaddingLeft = UDim.new(0, 4)
    dlP.PaddingRight = UDim.new(0, 4)
    
    local isOpen = false
    local currentOpts = options or {}
    
    local function refresh(newOpts)
        currentOpts = newOpts or currentOpts
        for _, c in pairs(dl:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for i, opt in ipairs(currentOpts) do
            local ob = Instance.new("TextButton", dl)
            ob.Size = UDim2.new(1, -2, 0, 22)
            ob.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
            ob.Text = "  " .. opt
            ob.TextColor3 = Color3.fromRGB(255, 255, 255)
            ob.TextSize = 10
            ob.Font = Enum.Font.GothamSemibold
            ob.TextXAlignment = Enum.TextXAlignment.Left
            ob.BorderSizePixel = 0
            ob.ZIndex = 51
            ob.LayoutOrder = i
            Instance.new("UICorner", ob).CornerRadius = UDim.new(0, 4)
            ob.MouseButton1Click:Connect(function()
                db.Text = opt .. " ▼"
                isOpen = false
                TS:Create(dl, TweenInfo.new(0.2), {Size=UDim2.new(1, -75, 0, 0)}):Play()
                task.wait(0.2)
                dl.Visible = false
                if callback then callback(opt) end
            end)
            ob.MouseEnter:Connect(function() TS:Create(ob, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(60, 80, 120)}):Play() end)
            ob.MouseLeave:Connect(function() TS:Create(ob, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(45, 45, 70)}):Play() end)
        end
    end
    refresh(currentOpts)
    
    db.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            refresh(currentOpts)
            dl.Visible = true
            TS:Create(dl, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size=UDim2.new(1, -75, 0, math.min(#currentOpts * 24 + 8, 180))}):Play()
        else
            TS:Create(dl, TweenInfo.new(0.2), {Size=UDim2.new(1, -75, 0, 0)}):Play()
            task.wait(0.2)
            dl.Visible = false
        end
    end)
    
    return {frame=f, button=db, list=dl, refresh=refresh, setText=function(t) db.Text = t .. " ▼" end}
end

-- ============================================
-- DRAG SYSTEM
-- ============================================
local dragging = false
local dragInput, dragStart, startPos

TB.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MF.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                CONFIG.posX = MF.Position.X.Offset
                CONFIG.posY = MF.Position.Y.Offset
                saveConfig()
            end
        end)
    end
end)

TB.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MF.Position = UDim2.new(0, startPos.X.Offset + delta.X, 0, startPos.Y.Offset + delta.Y)
    end
end)

-- ============================================
-- RESIZE SYSTEM
-- ============================================
local resizing = false
local rzStart, rzStartSize

resizeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        rzStart = input.Position
        rzStartSize = MF.AbsoluteSize
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                resizing = false
                CONFIG.sizeW = MF.AbsoluteSize.X
                CONFIG.sizeH = MF.AbsoluteSize.Y
                saveConfig()
            end
        end)
    end
end)

UIS.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - rzStart
        local newW = math.clamp(rzStartSize.X + delta.X, 260, 500)
        local newH = math.clamp(rzStartSize.Y + delta.Y, 300, 700)
        MF.Size = UDim2.new(0, newW, 0, newH)
    end
end)

-- ============================================
-- SAVE BUTTON
-- ============================================
saveBtn.MouseButton1Click:Connect(function()
    CONFIG.posX = MF.Position.X.Offset
    CONFIG.posY = MF.Position.Y.Offset
    CONFIG.sizeW = MF.AbsoluteSize.X
    CONFIG.sizeH = MF.AbsoluteSize.Y
    saveConfig()
    -- Visual feedback
    local origColor = saveBtn.BackgroundColor3
    saveBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    saveBtn.Text = "✅"
    task.wait(0.8)
    saveBtn.BackgroundColor3 = origColor
    saveBtn.Text = "💾"
end)
-- ============================================
-- MINIMIZE BUTTON (FIXED)
-- ============================================
local isMinimized = CONFIG.minimized or false
local savedSize = nil -- will store size before minimize

local function toggleMinimize()
    isMinimized = not isMinimized
    CONFIG.minimized = isMinimized

    if isMinimized then
        -- Save current size before collapsing
        savedSize = UDim2.new(0, MF.AbsoluteSize.X, 0, MF.AbsoluteSize.Y)
        Content.Visible = false
        TabBar.Visible = false
        TS:Create(MF, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
            Size = UDim2.new(0, MF.AbsoluteSize.X, 0, 40)
        }):Play()
        minBtn.Text = "+"
    else
        -- Restore to saved size
        local restoreSize = savedSize or UDim2.new(0, CONFIG.sizeW, 0, CONFIG.sizeH)
        TS:Create(MF, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
            Size = restoreSize
        }):Play()
        task.wait(0.3)
        Content.Visible = true
        TabBar.Visible = true
        minBtn.Text = "—"
    end
    saveConfig()
end

minBtn.MouseButton1Click:Connect(toggleMinimize)

-- Apply minimized state on load
if isMinimized then
    savedSize = UDim2.new(0, CONFIG.sizeW, 0, CONFIG.sizeH)
    Content.Visible = false
    TabBar.Visible = false
    MF.Size = UDim2.new(0, CONFIG.sizeW, 0, 40)
    minBtn.Text = "+"
end

print("✅ v29 PART 2 UI Framework loaded!")

-- ============================================
-- v29 PART 3 FIXED - ALL TABS
-- Fix: Minimize, Resize, Explore All, Instant Interact
-- ============================================

-- ============================================
-- FORWARD DECLARE dropdowns (Islands tab uses them)
-- ============================================
local islDropdown, keyDropdown, survDropdown, tabDropdown, bossDropdown

-- ============================================
-- TAB: MAIN
-- ============================================
local MainTab = createTab("Main", "🏠")

mkSection(MainTab, "MOVEMENT")

-- FLY TOGGLE
local flyTgl = mkToggle(MainTab, "Fly Mode", "🕊️")
flyTgl.button.MouseButton1Click:Connect(function()
    S.flyOn = not S.flyOn
    flyTgl.setState(S.flyOn)
    if S.flyOn then
        startFly()
        flyTgl.count.Text = "WASD+Space or ▲▼"
    else
        stopFly()
        flyTgl.count.Text = "Ready"
    end
end)

local flySpdInp = mkInput(MainTab, "Fly Speed:", "💨", S.flySpeed, "s/s")
flySpdInp.FocusLost:Connect(function()
    local n = tonumber(flySpdInp.Text)
    if n and n > 0 and n <= 500 then S.flySpeed = n
    else flySpdInp.Text = tostring(S.flySpeed) end
end)

-- WALK SPEED TOGGLE
local walkTgl = mkToggle(MainTab, "Walk Speed", "🏃")
walkTgl.button.MouseButton1Click:Connect(function()
    S.walkSpeedOn = not S.walkSpeedOn
    walkTgl.setState(S.walkSpeedOn)
    if S.walkSpeedOn then
        startWalkSpeed()
        walkTgl.count.Text = "Speed: " .. S.walkSpeed
    else
        stopWalkSpeed()
        walkTgl.count.Text = "Ready"
    end
end)

local walkSpdInp = mkInput(MainTab, "Walk Speed:", "🏃", S.walkSpeed, "s/s")
walkSpdInp.FocusLost:Connect(function()
    local n = tonumber(walkSpdInp.Text)
    if n and n > 0 and n <= 200 then S.walkSpeed = n
    else walkSpdInp.Text = tostring(S.walkSpeed) end
end)

-- ============================================
-- INSTANT INTERACTION TOGGLE (NEW)
-- ============================================
mkSection(MainTab, "INTERACTION")

local instantInteractOn = false
local instantInteractConn = nil

local interactTgl = mkToggle(MainTab, "Instant Interact", "⚡")
interactTgl.button.MouseButton1Click:Connect(function()
    instantInteractOn = not instantInteractOn
    interactTgl.setState(instantInteractOn)
    if instantInteractOn then
        interactTgl.count.Text = "Active"
        -- Loop: auto detect & press interaction buttons
        if instantInteractConn then return end
        task.spawn(function()
            instantInteractConn = true
            while instantInteractOn do
                pcall(function()
                    -- Method 1: Fire ProximityPrompts instantly
                    local char = player.Character
                    if char then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local myPos = hrp.Position
                            -- Search all ProximityPrompts in workspace
                            for _, pp in pairs(workspace:GetDescendants()) do
                                if not instantInteractOn then break end
                                if pp:IsA("ProximityPrompt") then
                                    local ppParent = pp.Parent
                                    if ppParent and ppParent:IsA("BasePart") then
                                        local dist = (ppParent.Position - myPos).Magnitude
                                        if dist <= (pp.MaxActivationDistance or 10) + 5 then
                                            -- Force trigger
                                            pcall(function()
                                                pp.MaxActivationDistance = 9999
                                                pp.RequiresLineOfSight = false
                                                pp.HoldDuration = 0
                                            end)
                                            pcall(function()
                                                fireproximityprompt(pp)
                                            end)
                                        end
                                    elseif ppParent and ppParent:IsA("Model") then
                                        local pos = getObjPos(ppParent)
                                        if pos then
                                            local dist = (pos - myPos).Magnitude
                                            if dist <= (pp.MaxActivationDistance or 10) + 5 then
                                                pcall(function()
                                                    pp.MaxActivationDistance = 9999
                                                    pp.RequiresLineOfSight = false
                                                    pp.HoldDuration = 0
                                                end)
                                                pcall(function()
                                                    fireproximityprompt(pp)
                                                end)
                                            end
                                        end
                                    end
                                end
                            end

                            -- Method 2: Also fire Touch GUI buttons (Drag/Collect/Eat/Store/Open)
                            local touchBtns = {"Drag", "Collect", "Eat", "Store", "Open", "Interact", "Use", "Pick Up", "Grab"}
                            for _, btnName in ipairs(touchBtns) do
                                if not instantInteractOn then break end
                                local btn = findTouchButton(btnName)
                                if btn then
                                    fireGuiButton(btn)
                                end
                            end
                        end
                    end
                end)
                task.wait(0.15)
            end
            instantInteractConn = nil
        end)
    else
        interactTgl.count.Text = "Ready"
    end
end)

mkSection(MainTab, "QUICK TP")

local homeBtn = mkButton(MainTab, "🏠 TP Home (Bonfire)", Color3.fromRGB(60, 140, 100))
homeBtn.MouseButton1Click:Connect(function()
    pcall(function()
        tpTo(workspace:WaitForChild("SpawnIsland", 5):WaitForChild("Bonfire", 5))
    end)
end)

local merchBtn = mkButton(MainTab, "🏪 TP Merchant", Color3.fromRGB(140, 100, 60))
merchBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local m = workspace:FindFirstChild("MerchantBrick")
        if m then tpTo(m) end
    end)
end)

mkSection(MainTab, "PLAYER STATUS")

local statFrame = Instance.new("Frame", MainTab)
statFrame.Size = UDim2.new(1, 0, 0, 56)
statFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
statFrame.BorderSizePixel = 0
statFrame.LayoutOrder = nxtLO(MainTab)
Instance.new("UICorner", statFrame).CornerRadius = UDim.new(0, 8)

local sFood = Instance.new("TextLabel", statFrame)
sFood.Size = UDim2.new(0.5, -8, 0, 22)
sFood.Position = UDim2.new(0, 10, 0, 5)
sFood.BackgroundTransparency = 1
sFood.Text = "🍖 ?"
sFood.TextColor3 = Color3.fromRGB(255, 180, 80)
sFood.TextSize = 12
sFood.Font = Enum.Font.GothamBold
sFood.TextXAlignment = Enum.TextXAlignment.Left

local sHP = Instance.new("TextLabel", statFrame)
sHP.Size = UDim2.new(0.5, -8, 0, 22)
sHP.Position = UDim2.new(0.5, 5, 0, 5)
sHP.BackgroundTransparency = 1
sHP.Text = "❤️ ?"
sHP.TextColor3 = Color3.fromRGB(255, 100, 100)
sHP.TextSize = 12
sHP.Font = Enum.Font.GothamBold
sHP.TextXAlignment = Enum.TextXAlignment.Left

local sClass = Instance.new("TextLabel", statFrame)
sClass.Size = UDim2.new(0.5, -8, 0, 20)
sClass.Position = UDim2.new(0, 10, 0, 30)
sClass.BackgroundTransparency = 1
sClass.Text = "⭐ ?"
sClass.TextColor3 = Color3.fromRGB(255, 220, 100)
sClass.TextSize = 11
sClass.Font = Enum.Font.GothamSemibold
sClass.TextXAlignment = Enum.TextXAlignment.Left

local sCoin = Instance.new("TextLabel", statFrame)
sCoin.Size = UDim2.new(0.5, -8, 0, 20)
sCoin.Position = UDim2.new(0.5, 5, 0, 30)
sCoin.BackgroundTransparency = 1
sCoin.Text = "🪙 ?"
sCoin.TextColor3 = Color3.fromRGB(255, 200, 50)
sCoin.TextSize = 11
sCoin.Font = Enum.Font.GothamSemibold
sCoin.TextXAlignment = Enum.TextXAlignment.Left

task.spawn(function()
    while SG and SG.Parent do
        pcall(function()
            sFood.Text = "🍖 " .. math.floor(player:GetAttribute("Food") or 0) .. "%"
            sHP.Text = "❤️ " .. math.floor(getPlayerHP()) .. "%"
            sClass.Text = "⭐ " .. (player:GetAttribute("Class") or "?") .. " L" .. (player:GetAttribute("ClassLevel") or 0)
            sCoin.Text = "🪙 " .. (player:GetAttribute("Doubloons") or 0)
        end)
        task.wait(1.5)
    end
end)

-- ============================================
-- TAB: RESOURCE
-- ============================================
local ResTab = createTab("Resource", "🪨")
mkSection(ResTab, "SELECT")

local resDropdown = mkDropdown(ResTab, "Select Resource", "🪨", S.RLIST, function(v) S.selRes = v end)

local resRefreshBtn = mkButton(ResTab, "🔄 Refresh Resources", Color3.fromRGB(50, 130, 80))
resRefreshBtn.MouseButton1Click:Connect(function()
    scanRes()
    resDropdown.refresh(S.RLIST)
end)

task.spawn(function()
    while SG and SG.Parent do
        task.wait(2)
        pcall(function() resDropdown.refresh(S.RLIST) end)
    end
end)

mkSection(ResTab, "ACTIONS")

local tpFrzTgl = mkToggle(ResTab, "TP + Freeze Resource", "🧊")
tpFrzTgl.button.MouseButton1Click:Connect(function()
    S.tpResOn = not S.tpResOn
    tpFrzTgl.setState(S.tpResOn)
    if S.tpResOn then
        if S.tpLoop then return end
        S.tpLoop = true
        S.tpCount = 0
        S.frozen = {}
        startFL()
        coroutine.wrap(function()
            while S.tpResOn and S.tpLoop do
                if not S.selRes then
                    tpFrzTgl.count.Text = "⚠️ Select!"
                    task.wait(1)
                    continue
                end
                local inst = getResInst(S.selRes)
                local uf = {}
                for _, o in ipairs(inst) do
                    if o and o.Parent and not S.frozen[o] then
                        table.insert(uf, o)
                    end
                end
                tpFrzTgl.count.Text = "Rem: " .. #uf .. "/" .. #inst
                if #uf == 0 then
                    tpFrzTgl.count.Text = "✅ All frozen"
                    task.wait(3)
                    continue
                end
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then task.wait(0.5) continue end
                for i, obj in ipairs(uf) do
                    if not S.tpResOn or not S.tpLoop then break end
                    if obj and obj.Parent then
                        local cf = hrp.CFrame * CFrame.new(
                            math.random(-30, 30) / 10, 0,
                            -S.tpDist + math.random(-20, 20) / 10
                        )
                        mvO(obj, cf)
                        frzO(obj)
                        S.frozen[obj] = cf
                        S.tpCount = S.tpCount + 1
                        tpFrzTgl.count.Text = "Frozen: " .. S.tpCount
                        task.wait(S.tpDelay)
                    end
                end
                task.wait(1)
            end
            S.tpLoop = false
        end)()
    else
        S.tpResOn = false
        S.tpLoop = false
    end
end)

local unfrzBtn = mkButton(ResTab, "🔓 Unfreeze All", Color3.fromRGB(180, 60, 60))
unfrzBtn.MouseButton1Click:Connect(function()
    stopFL()
    S.frozen = {}
    S.tpCount = 0
    tpFrzTgl.count.Text = "Released"
end)

local dragTgl = mkToggle(ResTab, "Auto Drag (Collect/Eat/Store)", "🔄")
dragTgl.button.MouseButton1Click:Connect(function()
    S.autoResOn = not S.autoResOn
    dragTgl.setState(S.autoResOn)
    if S.autoResOn then
        if S.autoResRun then return end
        S.autoResRun = true
        S.autoResCnt = 0
        coroutine.wrap(function()
            while S.autoResOn and S.autoResRun do
                if not S.selRes then
                    dragTgl.count.Text = "⚠️ Select!"
                    task.wait(1)
                    continue
                end
                local inst = getResInst(S.selRes)
                if #inst == 0 then
                    dragTgl.count.Text = "✅ Done: " .. S.autoResCnt
                    task.wait(3)
                    continue
                end
                for i, obj in ipairs(inst) do
                    if not S.autoResOn or not S.autoResRun then break end
                    if obj and obj.Parent then
                        dragTgl.count.Text = "Drag " .. i .. "/" .. #inst
                        autoDragRes(obj)
                        S.autoResCnt = S.autoResCnt + 1
                        task.wait(S.autoResDelay)
                    end
                end
                task.wait(1)
            end
            S.autoResRun = false
        end)()
    else
        S.autoResOn = false
        S.autoResRun = false
    end
end)

local dragDelayInp = mkInput(ResTab, "Drag Delay:", "⏱️", S.autoResDelay, "s")
dragDelayInp.FocusLost:Connect(function()
    local n = tonumber(dragDelayInp.Text)
    if n and n >= 0.1 then S.autoResDelay = n
    else dragDelayInp.Text = tostring(S.autoResDelay) end
end)

-- ============================================
-- TAB: CHESTS
-- ============================================
local ChestTab = createTab("Chests", "📦")

local chestDropdown = mkDropdown(ChestTab, "Select Chest", "📦", S.CLIST, function(v)
    S.selChest = v
    S.chIdx = 1
end)

local chestRefreshBtn = mkButton(ChestTab, "🔄 Refresh Chests", Color3.fromRGB(50, 130, 80))
chestRefreshBtn.MouseButton1Click:Connect(function()
    scanChests()
    chestDropdown.refresh(S.CLIST)
end)

task.spawn(function()
    while SG and SG.Parent do
        task.wait(2)
        pcall(function() chestDropdown.refresh(S.CLIST) end)
    end
end)

mkSection(ChestTab, "NAVIGATION")

local chStatus = Instance.new("TextLabel", ChestTab)
chStatus.Size = UDim2.new(1, 0, 0, 20)
chStatus.BackgroundTransparency = 1
chStatus.Text = "📦 -"
chStatus.TextColor3 = Color3.fromRGB(255, 200, 80)
chStatus.TextSize = 11
chStatus.Font = Enum.Font.GothamBold
chStatus.LayoutOrder = nxtLO(ChestTab)

local function updateChStatus()
    if S.selChest then
        local inst = getCI(S.selChest)
        S.chIdx = math.clamp(S.chIdx, 1, math.max(#inst, 1))
        chStatus.Text = "📦 " .. S.selChest .. " [" .. S.chIdx .. "/" .. #inst .. "]"
    else
        chStatus.Text = "📦 -"
    end
end

local tpChestBtn = mkButton(ChestTab, "🏃 TP to Chest", Color3.fromRGB(180, 130, 50))
tpChestBtn.MouseButton1Click:Connect(function()
    if not S.selChest then return end
    local inst = getCI(S.selChest)
    if #inst == 0 then return end
    S.chIdx = math.clamp(S.chIdx, 1, #inst)
    tpTo(inst[S.chIdx])
    updateChStatus()
end)

local navFrame = Instance.new("Frame", ChestTab)
navFrame.Size = UDim2.new(1, 0, 0, 32)
navFrame.BackgroundTransparency = 1
navFrame.LayoutOrder = nxtLO(ChestTab)

local prevChBtn = Instance.new("TextButton", navFrame)
prevChBtn.Size = UDim2.new(0.48, -3, 1, 0)
prevChBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 50)
prevChBtn.Text = "◀ Previous"
prevChBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
prevChBtn.TextSize = 11
prevChBtn.Font = Enum.Font.GothamBold
prevChBtn.BorderSizePixel = 0
Instance.new("UICorner", prevChBtn).CornerRadius = UDim.new(0, 8)

local nextChBtn = Instance.new("TextButton", navFrame)
nextChBtn.Size = UDim2.new(0.48, -3, 1, 0)
nextChBtn.Position = UDim2.new(0.52, 3, 0, 0)
nextChBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 50)
nextChBtn.Text = "Next ▶"
nextChBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
nextChBtn.TextSize = 11
nextChBtn.Font = Enum.Font.GothamBold
nextChBtn.BorderSizePixel = 0
Instance.new("UICorner", nextChBtn).CornerRadius = UDim.new(0, 8)

prevChBtn.MouseButton1Click:Connect(function()
    if not S.selChest then return end
    local inst = getCI(S.selChest)
    if #inst == 0 then return end
    S.chIdx = S.chIdx - 1
    if S.chIdx < 1 then S.chIdx = #inst end
    tpTo(inst[S.chIdx])
    updateChStatus()
end)

nextChBtn.MouseButton1Click:Connect(function()
    if not S.selChest then return end
    local inst = getCI(S.selChest)
    if #inst == 0 then return end
    S.chIdx = S.chIdx + 1
    if S.chIdx > #inst then S.chIdx = 1 end
    tpTo(inst[S.chIdx])
    updateChStatus()
end)

-- ============================================
-- TAB: ISLANDS & QUESTS
-- ============================================
local IslTab = createTab("Islands", "🏝️")

mkSection(IslTab, "AUTO EXPLORE (DEEP SCAN)")

local exploreBtn = mkButton(IslTab, "🔍 Deep Explore All Islands", Color3.fromRGB(80, 150, 200))
local exploreStatus = Instance.new("TextLabel", IslTab)
exploreStatus.Size = UDim2.new(1, 0, 0, 28)
exploreStatus.BackgroundTransparency = 1
exploreStatus.Text = "Status: Ready\n💡 Teleports to each island to load Keys/NPCs/Tablets/Bosses"
exploreStatus.TextColor3 = Color3.fromRGB(150, 200, 255)
exploreStatus.TextSize = 10
exploreStatus.Font = Enum.Font.Gotham
exploreStatus.TextWrapped = true
exploreStatus.LayoutOrder = nxtLO(IslTab)

-- ============================================
-- DEEP EXPLORE FUNCTION (FIXED)
-- Teleport player to each island → force streaming → scan special targets
-- ============================================
local function deepExploreAllIslands(statusCallback)
    if S.exploring then return end
    S.exploring = true

    local char = player.Character
    if not char then S.exploring = false return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then S.exploring = false return end

    -- Save original position
    local originalCF = hrp.CFrame

    -- Step 1: Initial scan
    if statusCallback then statusCallback("Step 1: Initial scan...") end
    scanIslands()
    scanSpecialTargets()
    autoCacheTargets()

    -- Step 2: Collect all island positions (live + cached)
    local visitList = {}
    local visited = {}

    local ic = workspace:FindFirstChild("IslandContainer")
    if ic then
        for _, isl in pairs(ic:GetChildren()) do
            if not visited[isl.Name] then
                local pos = getObjPos(isl)
                if pos then
                    table.insert(visitList, {name = isl.Name, pos = pos})
                    visited[isl.Name] = true
                end
            end
        end
    end

    -- Also add cached islands not yet in live
    for name, data in pairs(S.cachedIslands) do
        if not visited[name] then
            local pos = type(data) == "table" and data.Position or data
            if pos then
                table.insert(visitList, {name = name, pos = pos})
                visited[name] = true
            end
        end
    end

    -- Step 3: If no islands found at all, do grid scan first
    if #visitList == 0 then
        if statusCallback then statusCallback("No islands found, grid scanning...") end
        local step = 600
        for x = -4000, 4000, step do
            for z = -4000, 4000, step do
                if not S.exploring then break end
                char = player.Character
                if not char then break end
                hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then break end
                hrp.CFrame = CFrame.new(x, 300, z)
                task.wait(0.3)
                scanIslands()
                autoCacheTargets()
            end
            if not S.exploring then break end
        end
        -- Rebuild visit list after grid scan
        ic = workspace:FindFirstChild("IslandContainer")
        if ic then
            for _, isl in pairs(ic:GetChildren()) do
                if not visited[isl.Name] then
                    local pos = getObjPos(isl)
                    if pos then
                        table.insert(visitList, {name = isl.Name, pos = pos})
                        visited[isl.Name] = true
                    end
                end
            end
        end
    end

    -- Step 4: DEEP VISIT - Teleport player to EACH island
    -- This forces streaming to load children (Keys, NPCs, Tablets, Bosses)
    local totalIslands = #visitList
    for i, info in ipairs(visitList) do
        if not S.exploring then break end

        if statusCallback then
            statusCallback(string.format("Visiting %d/%d: %s...", i, totalIslands, info.name))
        end

        -- Teleport player near the island
        char = player.Character
        if not char then break end
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then break end

        hrp.CFrame = CFrame.new(info.pos.X, info.pos.Y + 50, info.pos.Z)
        task.wait(0.8) -- Wait for streaming to load island children

        -- Now scan special targets (Keys, Survivors, Tablets, Bosses)
        scanIslands()
        scanSpecialTargets()
        autoCacheTargets()

        -- Extra: walk around the island slightly to trigger more streaming
        for offset = 1, 3 do
            if not S.exploring then break end
            char = player.Character
            if not char then break end
            hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then break end

            local offsets = {
                Vector3.new(40, 20, 0),
                Vector3.new(-40, 20, 0),
                Vector3.new(0, 20, 40),
            }
            hrp.CFrame = CFrame.new(info.pos + offsets[offset])
            task.wait(0.4)
            scanSpecialTargets()
            autoCacheTargets()
        end
    end

    -- Step 5: Return player to original position
    char = player.Character
    if char then
        hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = originalCF
        end
    end

    S.exploring = false

    if statusCallback then
        statusCallback(string.format(
            "✅ Done! 🏝️%d 🗝️%d 🧑%d 📜%d 👹%d",
            #S.ILIST + (function() local c=0 for _ in pairs(S.cachedIslands) do c=c+1 end return c end)(),
            #S.keysList + (function() local c=0 for _ in pairs(S.cachedKeys) do c=c+1 end return c end)(),
            #S.survList + (function() local c=0 for _ in pairs(S.cachedSurv) do c=c+1 end return c end)(),
            #S.tabList + (function() local c=0 for _ in pairs(S.cachedTab) do c=c+1 end return c end)(),
            #S.bossList + (function() local c=0 for _ in pairs(S.cachedBoss) do c=c+1 end return c end)()
        ))
    end
end

exploreBtn.MouseButton1Click:Connect(function()
    if S.exploring then
        exploreStatus.Text = "⚠️ Already exploring..."
        return
    end
    task.spawn(function()
        exploreBtn.Text = "🔄 Deep Exploring..."
        exploreBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 50)

        deepExploreAllIslands(function(msg) exploreStatus.Text = msg end)

        exploreBtn.Text = "🔍 Deep Explore All Islands"
        exploreBtn.BackgroundColor3 = Color3.fromRGB(80, 150, 200)

        -- Refresh all dropdowns
        if islDropdown then islDropdown.refresh(getMergedList(S.ILIST, S.cachedIslands)) end
        if keyDropdown then keyDropdown.refresh(getMergedList(S.keysList, S.cachedKeys)) end
        if survDropdown then survDropdown.refresh(getMergedList(S.survList, S.cachedSurv)) end
        if tabDropdown then tabDropdown.refresh(getMergedList(S.tabList, S.cachedTab)) end
        if bossDropdown then bossDropdown.refresh(getMergedList(S.bossList, S.cachedBoss)) end
    end)
end)

-- Stop explore button
local stopExploreBtn = mkButton(IslTab, "⛔ Stop Exploring", Color3.fromRGB(180, 60, 60))
stopExploreBtn.MouseButton1Click:Connect(function()
    S.exploring = false
    exploreStatus.Text = "⛔ Stopped by user"
end)

mkSection(IslTab, "ALL ISLANDS")
islDropdown = mkDropdown(IslTab, "Select Island", "🏝️",
    getMergedList(S.ILIST, S.cachedIslands),
    function(v) S.selIsland = v S.islIdx = 1 end
)

local tpIslBtn = mkButton(IslTab, "🏃 TP to Island", Color3.fromRGB(60, 140, 100))
tpIslBtn.MouseButton1Click:Connect(function()
    if not S.selIsland then return end
    local name = stripCache(S.selIsland)
    local inst = getII(name)
    if #inst > 0 then
        tpTo(inst[1])
    else
        local pos = S.cachedIslands[name]
        if pos then
            if type(pos) == "table" then pos = pos.Position end
            local char = player.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and pos then
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
                end
            end
        end
    end
end)

mkSection(IslTab, "🗝️ STRONGHOLD KEYS")
keyDropdown = mkDropdown(IslTab, "Select Key", "🗝️",
    getMergedList(S.keysList, S.cachedKeys),
    function(v) S.selKey = v end
)
local tpKeyBtn = mkButton(IslTab, "🏃 TP to Key", Color3.fromRGB(150, 150, 60))
tpKeyBtn.MouseButton1Click:Connect(function()
    if S.selKey then tpToTarget(S.selKey, S.keysMap, S.cachedKeys) end
end)

mkSection(IslTab, "🧑 TRAPPED SURVIVORS")
survDropdown = mkDropdown(IslTab, "Select Survivor", "🧑",
    getMergedList(S.survList, S.cachedSurv),
    function(v) S.selSurvivor = v end
)
local tpSurvBtn = mkButton(IslTab, "🏃 TP to Survivor", Color3.fromRGB(80, 150, 100))
tpSurvBtn.MouseButton1Click:Connect(function()
    if S.selSurvivor then tpToTarget(S.selSurvivor, S.survMap, S.cachedSurv) end
end)

mkSection(IslTab, "📜 ANCIENT TABLETS")
tabDropdown = mkDropdown(IslTab, "Select Tablet", "📜",
    getMergedList(S.tabList, S.cachedTab),
    function(v) S.selTablet = v end
)
local tpTabBtn = mkButton(IslTab, "🏃 TP to Tablet", Color3.fromRGB(120, 100, 150))
tpTabBtn.MouseButton1Click:Connect(function()
    if S.selTablet then tpToTarget(S.selTablet, S.tabMap, S.cachedTab) end
end)

mkSection(IslTab, "👹 BOSS LOCATIONS")
bossDropdown = mkDropdown(IslTab, "Select Boss", "👹",
    getMergedList(S.bossList, S.cachedBoss),
    function(v) S.selBoss = v end
)
local tpBossBtn = mkButton(IslTab, "🏃 TP to Boss", Color3.fromRGB(180, 60, 60))
tpBossBtn.MouseButton1Click:Connect(function()
    if S.selBoss then tpToTarget(S.selBoss, S.bossMap, S.cachedBoss) end
end)

local refreshAllBtn = mkButton(IslTab, "🔄 Refresh All Lists", Color3.fromRGB(50, 130, 80))
refreshAllBtn.MouseButton1Click:Connect(function()
    scanIslands()
    scanSpecialTargets()
    autoCacheTargets()
    islDropdown.refresh(getMergedList(S.ILIST, S.cachedIslands))
    keyDropdown.refresh(getMergedList(S.keysList, S.cachedKeys))
    survDropdown.refresh(getMergedList(S.survList, S.cachedSurv))
    tabDropdown.refresh(getMergedList(S.tabList, S.cachedTab))
    bossDropdown.refresh(getMergedList(S.bossList, S.cachedBoss))
end)

-- Auto refresh island dropdowns
task.spawn(function()
    while SG and SG.Parent do
        task.wait(2)
        pcall(function()
            islDropdown.refresh(getMergedList(S.ILIST, S.cachedIslands))
            keyDropdown.refresh(getMergedList(S.keysList, S.cachedKeys))
            survDropdown.refresh(getMergedList(S.survList, S.cachedSurv))
            tabDropdown.refresh(getMergedList(S.tabList, S.cachedTab))
            bossDropdown.refresh(getMergedList(S.bossList, S.cachedBoss))
        end)
    end
end)

-- ============================================
-- TAB: COMBAT
-- ============================================
local CombatTab = createTab("Combat", "⚔️")
mkSection(CombatTab, "AUTO FIRE")

local afTgl = mkToggle(CombatTab, "Auto Fire Creature", "🔫")
afTgl.button.MouseButton1Click:Connect(function()
    S.autoFireOn = not S.autoFireOn
    afTgl.setState(S.autoFireOn)
    if S.autoFireOn then
        if S.autoFireRun then return end
        S.autoFireRun = true
        S.fireCnt = 0
        coroutine.wrap(function()
            if not RFunc then findRemotes() end
            if not RFunc then
                afTgl.count.Text = "❌ No remote!"
                S.autoFireRun = false
                S.autoFireOn = false
                afTgl.setState(false)
                return
            end
            while S.autoFireOn and S.autoFireRun do
                local cr, dist = getNearest()
                local gun, handle = getGun()
                if not gun then
                    afTgl.count.Text = "⚠️ Equip gun!"
                    task.wait(0.5)
                    continue
                end
                if not cr then
                    afTgl.count.Text = "Shots: " .. S.fireCnt
                    task.wait(0.3)
                    continue
                end
                local cPos = getCPos(cr)
                if not cPos then task.wait(0.1) continue end
                local ok = smartFire(gun, handle, cPos)
                if ok then
                    S.fireCnt = S.fireCnt + 1
                    afTgl.count.Text = "Shots: " .. S.fireCnt .. " | " .. cr.Name
                end
                task.wait(S.fireDelay)
            end
            S.autoFireRun = false
        end)()
    else
        S.autoFireOn = false
        S.autoFireRun = false
    end
end)

local fdInp = mkInput(CombatTab, "Fire Delay:", "🔫", S.fireDelay, "s")
fdInp.FocusLost:Connect(function()
    local n = tonumber(fdInp.Text)
    if n and n >= 0.01 then S.fireDelay = n
    else fdInp.Text = tostring(S.fireDelay) end
end)

local frInp = mkInput(CombatTab, "Fire Range:", "🎯", S.fireRange, "st")
frInp.FocusLost:Connect(function()
    local n = tonumber(frInp.Text)
    if n and n > 0 then S.fireRange = n
    else frInp.Text = tostring(S.fireRange) end
end)

mkSection(CombatTab, "BUFFS")

local iaTgl = mkToggle(CombatTab, "Inf Ammo (No Reload)", "♾️")
iaTgl.button.MouseButton1Click:Connect(function()
    S.infAmmoOn = not S.infAmmoOn
    iaTgl.setState(S.infAmmoOn)
    if S.infAmmoOn then
        if S.infAmmoRun then return end
        S.infAmmoRun = true
        coroutine.wrap(function()
            while S.infAmmoOn and S.infAmmoRun do
                local c = 0
                local function proc(ct)
                    if not ct then return end
                    for _, t in pairs(ct:GetChildren()) do
                        if t:IsA("Tool") and (t:GetAttribute("IsGun") or t:GetAttribute("AmmoType")) then
                            pcall(function()
                                if t:GetAttribute("FiredConseq") ~= nil then t:SetAttribute("FiredConseq", 0) end
                                if t:GetAttribute("Reloading") ~= nil then t:SetAttribute("Reloading", false) end
                            end)
                            c = c + 1
                        end
                    end
                end
                proc(player.Character)
                proc(player:FindFirstChild("Backpack"))
                iaTgl.count.Text = c .. " guns | ∞"
                task.wait(0.05)
            end
            S.infAmmoRun = false
        end)()
    else
        S.infAmmoOn = false
        S.infAmmoRun = false
    end
end)

local mdTgl = mkToggle(CombatTab, "Max Damage (999)", "💥")
mdTgl.button.MouseButton1Click:Connect(function()
    S.maxDmgOn = not S.maxDmgOn
    mdTgl.setState(S.maxDmgOn)
    if S.maxDmgOn then
        if S.maxDmgRun then return end
        S.maxDmgRun = true
        coroutine.wrap(function()
            while S.maxDmgOn and S.maxDmgRun do
                local c = 0
                local function proc(ct)
                    if not ct then return end
                    for _, t in pairs(ct:GetChildren()) do
                        if t:IsA("Tool") and t:GetAttribute("Damage") ~= nil then
                            pcall(function() t:SetAttribute("Damage", 999) end)
                            c = c + 1
                        end
                    end
                end
                proc(player.Character)
                proc(player:FindFirstChild("Backpack"))
                mdTgl.count.Text = c .. " weapons | 999"
                task.wait(0.1)
            end
            S.maxDmgRun = false
        end)()
    else
        S.maxDmgOn = false
        S.maxDmgRun = false
    end
end)

mkSection(CombatTab, "CREATURE CONTROL")

local wrTgl = mkToggle(CombatTab, "Freeze Wraith", "👻")
wrTgl.button.MouseButton1Click:Connect(function()
    S.frzWraithOn = not S.frzWraithOn
    wrTgl.setState(S.frzWraithOn)
    if S.frzWraithOn then
        if not S.frzWraithRun then
            S.frzWraithRun = true
            coroutine.wrap(function()
                while S.frzWraithOn and S.frzWraithRun do
                    local c = freezeWraiths()
                    wrTgl.count.Text = "Frozen: " .. c
                    task.wait(0.1)
                end
                S.frzWraithRun = false
            end)()
        end
    else
        S.frzWraithOn = false
        unfreezeWraiths()
        wrTgl.count.Text = "Released"
    end
end)

-- ============================================
-- TAB: SURVIVAL
-- ============================================
local SurvTab = createTab("Survival", "🍖")
mkSection(SurvTab, "AUTO CONSUME")

local eatTgl = mkToggle(SurvTab, "Auto Eat/Heal", "🍖")
eatTgl.button.MouseButton1Click:Connect(function()
    S.autoFoodOn = not S.autoFoodOn
    eatTgl.setState(S.autoFoodOn)
    if S.autoFoodOn then
        if S.autoFoodRun then return end
        S.autoFoodRun = true
        coroutine.wrap(function()
            while S.autoFoodOn and S.autoFoodRun do
                local food = player:GetAttribute("Food") or 100
                local hp = getPlayerHP()
                if hp < S.hpThresh then
                    eatTgl.count.Text = "❤️ Heal..."
                    useConsumable(HP_ITEMS, "hp")
                    task.wait(1)
                elseif food < S.foodThresh then
                    eatTgl.count.Text = "🍖 Eat..."
                    useConsumable(FOOD_ITEMS, "food")
                    task.wait(1)
                else
                    eatTgl.count.Text = "🍖" .. math.floor(food) .. "% ❤️" .. math.floor(hp) .. "%"
                end
                task.wait(1)
            end
            S.autoFoodRun = false
        end)()
    else
        S.autoFoodOn = false
        S.autoFoodRun = false
        pcall(function()
            local c = player.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then h:UnequipTools() end
            end
        end)
    end
end)

local ftInp = mkInput(SurvTab, "Eat Food <", "🍖", S.foodThresh, "%")
ftInp.FocusLost:Connect(function()
    local n = tonumber(ftInp.Text)
    if n and n > 0 and n <= 100 then S.foodThresh = n
    else ftInp.Text = tostring(S.foodThresh) end
end)

local htInp = mkInput(SurvTab, "Heal HP <", "❤️", S.hpThresh, "%")
htInp.FocusLost:Connect(function()
    local n = tonumber(htInp.Text)
    if n and n > 0 and n <= 100 then S.hpThresh = n
    else htInp.Text = tostring(S.hpThresh) end
end)

local infoFrame = Instance.new("Frame", SurvTab)
infoFrame.Size = UDim2.new(1, 0, 0, 42)
infoFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
infoFrame.BorderSizePixel = 0
infoFrame.LayoutOrder = nxtLO(SurvTab)
Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0, 8)

local infoLbl = Instance.new("TextLabel", infoFrame)
infoLbl.Size = UDim2.new(1, -16, 1, -8)
infoLbl.Position = UDim2.new(0, 8, 0, 4)
infoLbl.BackgroundTransparency = 1
infoLbl.Text = "🍖 Food: Chowder → Alien Soup\n❤️ HP: Bandage → Medkit"
infoLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
infoLbl.TextSize = 10
infoLbl.Font = Enum.Font.Gotham
infoLbl.TextXAlignment = Enum.TextXAlignment.Left
infoLbl.TextYAlignment = Enum.TextYAlignment.Top

-- ============================================
-- TAB: FISHING
-- ============================================
local FishTab = createTab("Fishing", "🎣")
mkSection(FishTab, "INSTANT FISHING V1")

local fishTgl = mkToggle(FishTab, "Instant Fishing V1", "🎣")
fishTgl.button.MouseButton1Click:Connect(function()
    S.autoFishOn = not S.autoFishOn
    fishTgl.setState(S.autoFishOn)
    if S.autoFishOn then
        if S.autoFishRun then return end
        S.autoFishRun = true
        S.fishCnt = 0
        coroutine.wrap(function()
            if not RFunc or not REvt then findRemotes() end
            if not RFunc or not REvt then
                fishTgl.count.Text = "❌ No remote"
                S.autoFishRun = false
                S.autoFishOn = false
                fishTgl.setState(false)
                return
            end
            local rod = findFishingRod()
            if not rod then
                fishTgl.count.Text = "⚠️ No Rod!"
                S.autoFishRun = false
                S.autoFishOn = false
                fishTgl.setState(false)
                return
            end
            while S.autoFishOn and S.autoFishRun do
                local ok = doInstantFishing()
                if ok then
                    S.fishCnt = S.fishCnt + 1
                    fishTgl.count.Text = "Fish: " .. S.fishCnt
                end
                task.wait(S.fishDelay)
            end
            S.autoFishRun = false
        end)()
    else
        S.autoFishOn = false
        S.autoFishRun = false
    end
end)

local fdInp2 = mkInput(FishTab, "V1 Delay:", "⏱️", S.fishDelay, "s")
fdInp2.FocusLost:Connect(function()
    local n = tonumber(fdInp2.Text)
    if n and n >= 0.1 then S.fishDelay = n
    else fdInp2.Text = tostring(S.fishDelay) end
end)

mkSection(FishTab, "🧪 FISHING V2")

local fishResDropdown = mkDropdown(FishTab, "Select Resource V2", "🎣", S.RLIST, function(v) S.selFishRes = v end)

local fishRefreshBtn = mkButton(FishTab, "🔄 Refresh Resources", Color3.fromRGB(50, 130, 80))
fishRefreshBtn.MouseButton1Click:Connect(function()
    scanRes()
    fishResDropdown.refresh(S.RLIST)
end)

task.spawn(function()
    while SG and SG.Parent do
        task.wait(2)
        pcall(function() fishResDropdown.refresh(S.RLIST) end)
    end
end)

local fishV2Tgl = mkToggle(FishTab, "Instant Fishing V2", "🧪")
fishV2Tgl.button.MouseButton1Click:Connect(function()
    S.autoFishV2On = not S.autoFishV2On
    fishV2Tgl.setState(S.autoFishV2On)
    if S.autoFishV2On then
        if S.autoFishV2Run then return end
        S.autoFishV2Run = true
        S.fishV2Cnt = 0
        coroutine.wrap(function()
            if not RFunc or not REvt then findRemotes() end
            if not RFunc or not REvt then
                fishV2Tgl.count.Text = "❌ No remote"
                S.autoFishV2Run = false
                S.autoFishV2On = false
                fishV2Tgl.setState(false)
                return
            end
            if not S.selFishRes then
                fishV2Tgl.count.Text = "⚠️ Select resource!"
                S.autoFishV2Run = false
                S.autoFishV2On = false
                fishV2Tgl.setState(false)
                return
            end
            local rod = findFishingRod()
            if not rod then
                fishV2Tgl.count.Text = "⚠️ No Rod!"
                S.autoFishV2Run = false
                S.autoFishV2On = false
                fishV2Tgl.setState(false)
                return
            end
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and rod.Parent ~= char then
                    hum:EquipTool(rod)
                    task.wait(0.5)
                end
            end
            fishV2Tgl.count.Text = "🎣 " .. S.selFishRes
            while S.autoFishV2On and S.autoFishV2Run do
                local ok = doFishingV2Loop()
                if ok then
                    S.fishV2Cnt = S.fishV2Cnt + 1
                    fishV2Tgl.count.Text = "V2: " .. S.fishV2Cnt
                end
                task.wait(S.fishV2Delay)
            end
            S.autoFishV2Run = false
        end)()
    else
        S.autoFishV2On = false
        S.autoFishV2Run = false
    end
end)

local fdInp3 = mkInput(FishTab, "V2 Delay:", "⏱️", S.fishV2Delay, "s")
fdInp3.FocusLost:Connect(function()
    local n = tonumber(fdInp3.Text)
    if n and n >= 0.1 then S.fishV2Delay = n
    else fdInp3.Text = tostring(S.fishV2Delay) end
end)

local v2Info = Instance.new("Frame", FishTab)
v2Info.Size = UDim2.new(1, 0, 0, 60)
v2Info.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
v2Info.BorderSizePixel = 0
v2Info.LayoutOrder = nxtLO(FishTab)
Instance.new("UICorner", v2Info).CornerRadius = UDim.new(0, 8)

local v2Lbl = Instance.new("TextLabel", v2Info)
v2Lbl.Size = UDim2.new(1, -16, 1, -8)
v2Lbl.Position = UDim2.new(0, 8, 0, 4)
v2Lbl.BackgroundTransparency = 1
v2Lbl.Text = "V2 Flow:\n1. Equip Rod (once)\n2. Loop: Cast → FishPoof → GiveUpOwnership"
v2Lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
v2Lbl.TextSize = 10
v2Lbl.Font = Enum.Font.Gotham
v2Lbl.TextXAlignment = Enum.TextXAlignment.Left
v2Lbl.TextYAlignment = Enum.TextYAlignment.Top

-- ============================================
-- TAB: SETTINGS
-- ============================================
local SetTab = createTab("Settings", "⚙️")
mkSection(SetTab, "TP SETTINGS")

local tpDistInp = mkInput(SetTab, "TP Distance:", "📏", S.tpDist, "st")
tpDistInp.FocusLost:Connect(function()
    local n = tonumber(tpDistInp.Text)
    if n and n > 0 then S.tpDist = n
    else tpDistInp.Text = tostring(S.tpDist) end
end)

local tpDelayInp = mkInput(SetTab, "TP Delay:", "⏱️", S.tpDelay, "s")
tpDelayInp.FocusLost:Connect(function()
    local n = tonumber(tpDelayInp.Text)
    if n and n >= 0.01 then S.tpDelay = n
    else tpDelayInp.Text = tostring(S.tpDelay) end
end)

mkSection(SetTab, "UI SETTINGS")

local saveNowBtn = mkButton(SetTab, "💾 Save Position & Size", Color3.fromRGB(60, 130, 80))
saveNowBtn.MouseButton1Click:Connect(function()
    CONFIG.posX = MF.Position.X.Offset
    CONFIG.posY = MF.Position.Y.Offset
    CONFIG.sizeW = MF.AbsoluteSize.X
    CONFIG.sizeH = MF.AbsoluteSize.Y
    saveConfig()
    saveNowBtn.Text = "✅ Saved!"
    task.wait(1)
    saveNowBtn.Text = "💾 Save Position & Size"
end)

local resetUIBtn = mkButton(SetTab, "🔄 Reset UI Position/Size", Color3.fromRGB(180, 130, 60))
resetUIBtn.MouseButton1Click:Connect(function()
    local w, h = calcDefaultSize()
    local vw, vh = getScreenSize()
    MF.Size = UDim2.new(0, w, 0, h)
    MF.Position = UDim2.new(0, (vw - w) / 2, 0, (vh - h) / 2)
    CONFIG.posX = (vw - w) / 2
    CONFIG.posY = (vh - h) / 2
    CONFIG.sizeW = w
    CONFIG.sizeH = h
    CONFIG.minimized = false
    isMinimized = false
    Content.Visible = true
    TabBar.Visible = true
    minBtn.Text = "—"
    saveConfig()
end)

mkSection(SetTab, "INFO")

local infoParaFrame = Instance.new("Frame", SetTab)
infoParaFrame.Size = UDim2.new(1, 0, 0, 90)
infoParaFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
infoParaFrame.BorderSizePixel = 0
infoParaFrame.LayoutOrder = nxtLO(SetTab)
Instance.new("UICorner", infoParaFrame).CornerRadius = UDim.new(0, 8)

local infoParaLbl = Instance.new("TextLabel", infoParaFrame)
infoParaLbl.Size = UDim2.new(1, -16, 1, -8)
infoParaLbl.Position = UDim2.new(0, 8, 0, 4)
infoParaLbl.BackgroundTransparency = 1
infoParaLbl.Text = "🪨 Backstreet Survival Hub v29\n\n💾 Auto-save posisi & ukuran\n🔍 Deep Explore: TP ke setiap island\n     agar Key/NPC/Tablet/Boss terdeteksi\n⚡ Instant Interact: auto fire ProximityPrompts\n📱 Responsive: PC & Mobile"
infoParaLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
infoParaLbl.TextSize = 10
infoParaLbl.Font = Enum.Font.Gotham
infoParaLbl.TextXAlignment = Enum.TextXAlignment.Left
infoParaLbl.TextYAlignment = Enum.TextYAlignment.Top
infoParaLbl.TextWrapped = true

local destroyBtn = mkButton(SetTab, "🗑️ Destroy UI", Color3.fromRGB(180, 60, 60))
destroyBtn.MouseButton1Click:Connect(function()
    S.tpResOn = false
    S.tpLoop = false
    stopFL()
    S.frzWraithOn = false
    unfreezeWraiths()
    S.autoFireOn = false
    S.autoFireRun = false
    S.infAmmoOn = false
    S.infAmmoRun = false
    S.maxDmgOn = false
    S.maxDmgRun = false
    S.autoFoodOn = false
    S.autoFoodRun = false
    S.autoResOn = false
    S.autoResRun = false
    S.autoFishOn = false
    S.autoFishRun = false
    S.autoFishV2On = false
    S.autoFishV2Run = false
    instantInteractOn = false
    S.flyOn = false
    stopFly()
    S.walkSpeedOn = false
    stopWalkSpeed()
    S.exploring = false
    pcall(function() FlyGui:Destroy() end)
    pcall(function() SG:Destroy() end)
end)

-- ============================================
-- INIT - Activate default tab AFTER all tabs created
-- ============================================
task.wait(0.2)

-- Hide all tabs first
for n, t in pairs(tabs) do
    t.Visible = false
    tabButtons[n].BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    tabButtons[n].TextColor3 = Color3.fromRGB(180, 180, 180)
end

-- Activate saved or Main tab
local activeTabName = S.activeTab or "Main"
if not tabs[activeTabName] then activeTabName = "Main" end

if tabs[activeTabName] then
    tabs[activeTabName].Visible = true
    tabButtons[activeTabName].BackgroundColor3 = Color3.fromRGB(60, 120, 180)
    tabButtons[activeTabName].TextColor3 = Color3.fromRGB(255, 255, 255)
    S.activeTab = activeTabName
end

-- Ensure Content is visible (unless minimized)
if not isMinimized then
    Content.Visible = true
    TabBar.Visible = true
end

-- Find remotes background
task.spawn(function()
    task.wait(2)
    findRemotes()
    if RFunc then print("✅ Remote: " .. RFunc:GetFullName()) end
end)

-- Responsive listener
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    task.wait(0.5)
    local vw, vh = getScreenSize()
    local pos = MF.Position
    local newX = math.clamp(pos.X.Offset, -MF.AbsoluteSize.X + 50, vw - 50)
    local newY = math.clamp(pos.Y.Offset, 0, vh - 50)
    if newX ~= pos.X.Offset or newY ~= pos.Y.Offset then
        MF.Position = UDim2.new(0, newX, 0, newY)
    end
end)

print("✅ v29 COMPLETE! Deep Explore + Instant Interact + Fixed UI")
