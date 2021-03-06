-- if canCast(12345,true)
function canCast(SpellID,KnownSkip,MovementCheck)
	local myCooldown = getSpellCD(SpellID) or 0
	local lagTolerance = getValue("Lag Tolerance") or 0
	if (KnownSkip == true or isKnown(SpellID)) and IsUsableSpell(SpellID) and myCooldown < 0.1
		and (MovementCheck == false or myCooldown == 0 or isMoving("player") ~= true or UnitBuffID("player",79206) ~= nil) then
		return true
	end
end

function castAoEHeal(spellID,numUnits,missingHP,rangeValue)
	-- i start an iteration that i use to build each units Table,which i will reuse for the next second
	if not holyRadianceRangeTable or not holyRadianceRangeTableTimer or holyRadianceRangeTable <= GetTime() - 1 then
		holyRadianceRangeTable = { }
		for i = 1,#br.friend do
			-- i declare a sub-table for this unit if it dont exists
			if br.friend[i].distanceTable == nil then br.friend[i].distanceTable = { } end
			-- i start a second iteration where i scan unit ranges from one another.
			for j = 1,#br.friend do
				-- i make sure i dont compute unit range to hisself.
				if not UnitIsUnit(br.friend[i].unit,br.friend[j].unit) then
					-- table the units
					br.friend[i].distanceTable[j] = { distance = getDistance(br.friend[i].unit,br.friend[j].unit),unit = br.friend[j].unit,hp = br.friend[j].hp }
				end
			end
		end
	end
	-- declare locals that will hold number
	local bestTarget,bestTargetUnits = 1,1
	-- now that nova range is built,i can iterate it
	local inRange,missingHealth,mostMissingHealth = 0,0,0
	for i = 1,#br.friend do
		if br.friend[i].distanceTable ~= nil then
			-- i count units in range
			for j = 1,#br.friend do
				if br.friend[i].distanceTable[j] and br.friend[i].distanceTable[j].distance < rangeValue then
					inRange = inRange + 1
					missingHealth = missingHealth + (100 - br.friend[i].distanceTable[j].hp)
				end
			end
			br.friend[i].inRangeForHolyRadiance = inRange
			-- i check if this is going to be the best unit for my spell
			if missingHealth > mostMissingHealth then
				bestTarget,bestTargetUnits,mostMissingHealth = i,inRange,missingHealth
			end
		end
	end
	if bestTargetUnits and bestTargetUnits > 3 and mostMissingHealth and missingHP and mostMissingHealth > missingHP then
		if castSpell(br.friend[bestTarget].unit,spellID,true,true) then return true end
	end
end
-- castGround("target",12345,40)
function castGround(Unit,SpellID,maxDistance,minDistance,radius)
	if radius == nil then radius = maxDistance end
	if minDistance == nil then minDistance = 0 end
	if GetUnitExists(Unit) and getSpellCD(SpellID) == 0 and getLineOfSight("player",Unit)
		and getDistance("player",Unit) < maxDistance and getDistance("player",Unit) >= minDistance
		and #getEnemies(Unit,radius) >= #getEnemies(Unit,radius,true)
	then
		CastSpellByName(GetSpellInfo(SpellID))
		local X,Y,Z = GetObjectPosition(Unit)
		--local distanceToGround = getGroundDistance(Unit) or 0
		ClickPosition(X,Y,Z) --distanceToGround
		return true
	end
	return false
end
-- castGroundBetween("target",12345,40)
function castGroundBetween(Unit,SpellID,maxDistance)
	if GetUnitExists(Unit) and getSpellCD(SpellID) <= 0.4 and getLineOfSight("player",Unit) and getDistance("player",Unit) <= maxDistance then
		CastSpellByName(GetSpellInfo(SpellID))
		local X,Y,Z = GetObjectPosition(Unit)
		ClickPosition(X,Y,Z,true)
		return true
	end
	return false
end
-- if shouldNotOverheal(spellCastTarget) > 80 then
function shouldNotOverheal(Unit)
	local myIncomingHeal,allIncomingHeal = 0,0
	if UnitGetIncomingHeals(Unit,"player") ~= nil then myIncomingHeal = UnitGetIncomingHeals(Unit,"player") end
	if UnitGetIncomingHeals(Unit) ~= nil then allIncomingHeal = UnitGetIncomingHeals(Unit) end
	local allIncomingHeal = UnitGetIncomingHeals(Unit) or 0
	local overheal = 0
	if myIncomingHeal >= allIncomingHeal then
		overheal = myIncomingHeal
	else
		overheal = allIncomingHeal
	end
	local CurShield = UnitHealth(Unit)
	if UnitDebuffID("player",142861) then --Ancient Miasma
		CurShield = select(14,UnitDebuffID(Unit,142863)) or select(14,UnitDebuffID(Unit,142864)) or select(14,UnitDebuffID(Unit,142865)) or (UnitHealthMax(Unit) / 2)
		overheal = 0
	end
	local overhealth = 100 * (CurShield+ overheal ) / UnitHealthMax(Unit)
	if overhealth and overheal then
		return overhealth,overheal
	else
		return 0,0
	end
end
-- if castHealGround(_HealingRain,18,80,3) then
function castHealGround(SpellID,Radius,Health,NumberOfPlayers)
	if shouldStopCasting(SpellID) ~= true then
		local lowHPTargets,foundTargets = { },{ }
		for i = 1,#br.friend do
			if getHP(br.friend[i].unit) <= Health then
				if GetUnitIsVisible(br.friend[i].unit) and GetObjectExists(br.friend[i].unit) then
					local X,Y,Z = GetObjectPosition(br.friend[i].unit)
					tinsert(lowHPTargets,{ unit = br.friend[i].unit,x = X,y = Y,z = Z })
				end
			end
		end
		if #lowHPTargets >= NumberOfPlayers then
			for i = 1,#lowHPTargets do
				for j = 1,#lowHPTargets do
					if lowHPTargets[i].unit ~= lowHPTargets[j].unit then
						if math.sqrt(((lowHPTargets[j].x-lowHPTargets[i].x)^2)+((lowHPTargets[j].y-lowHPTargets[i].y)^2)) < Radius then
							for k = 1,#lowHPTargets do
								if lowHPTargets[i].unit ~= lowHPTargets[k].unit and lowHPTargets[j].unit ~= lowHPTargets[k].unit then
									if math.sqrt(((lowHPTargets[k].x-lowHPTargets[i].x)^2)+((lowHPTargets[k].y-lowHPTargets[i].y)^2)) < Radius
										and math.sqrt(((lowHPTargets[k].x-lowHPTargets[j].x)^2)+((lowHPTargets[k].y-lowHPTargets[j].y)^2)) < Radius
									then
										tinsert(foundTargets,{ unit = lowHPTargets[i].unit,x = lowHPTargets[i].x,y = lowHPTargets[i].y,z = lowHPTargets[i].z })
										tinsert(foundTargets,{ unit = lowHPTargets[j].unit,x = lowHPTargets[j].x,y = lowHPTargets[j].y,z = lowHPTargets[i].z })
										tinsert(foundTargets,{ unit = lowHPTargets[k].unit,x = lowHPTargets[k].x,y = lowHPTargets[k].y,z = lowHPTargets[i].z })
									end
								end
							end
						end
					end
				end
			end
			local medX,medY,medZ = 0,0,0
			if foundTargets ~= nil and #foundTargets >= NumberOfPlayers then
				for i = 1,3 do
					medX = medX + foundTargets[i].x
					medY = medY + foundTargets[i].y
					medZ = medZ + foundTargets[i].z
				end
				medX,medY,medZ = medX/3,medY/3,medZ/3
				local myX,myY = GetObjectPosition("player")
				if math.sqrt(((medX-myX)^2)+((medY-myY)^2)) < 40 then
					CastSpellByName(GetSpellInfo(SpellID),"target")
					ClickPosition(medX,medY,medZ,true)
					if SpellID == 145205 then shroomsTable[1] = { x = medX,y = medY,z = medZ} end
					return true
				end
			elseif lowHPTargets~=nil and #lowHPTargets==1 and lowHPTargets[1].unit=="player" then
				local myX,myY,myZ = GetObjectPosition("player")
				CastSpellByName(GetSpellInfo(SpellID),"target")
				ClickPosition(myX,myY,myZ,true)
				if SpellID == 145205 then shroomsTable[1] = { x = medX,y = medY,z = medZ} end
				return true
			end
		end
	else
		return false
	end
end
--[[castSpell(Unit,SpellID,FacingCheck,MovementCheck,SpamAllowed,KnownSkip)
Parameter 	Value
First 	 	UnitID 			Enter valid UnitID
Second 		SpellID 		Enter ID of spell to use
Third 		Facing 			True to allow 360 degrees,false to use facing check
Fourth 		MovementCheck	True to make sure player is standing to cast,false to allow cast while moving
Fifth 		SpamAllowed 	True to skip that check,false to prevent spells that we dont want to spam from beign recast for 1 second
Sixth 		KnownSkip 		True to skip isKnown check for some spells that are not managed correctly in wow's spell book.
Seventh 	DeadCheck 		True to skip checking for dead units. (IE: Resurrection Spells)
Eigth 		DistanceSkip    True to skip range checking.
Ninth 		usableSkip 		True to skip usability checks.
Tenth 		noCast			True to return True/False instead of casting spell.
]]
-- castSpell("target",12345,true)
--                ( 1  ,    2  ,     3     ,     4       ,      5    ,   6     ,   7     ,    8       ,   9      ,  10  )
function castSpell(Unit,SpellID,FacingCheck,MovementCheck,SpamAllowed,KnownSkip,DeadCheck,DistanceSkip,usableSkip,noCast)
	if GetObjectExists(Unit) --and betterStopCasting(SpellID) ~= true
		and (not UnitIsDeadOrGhost(Unit) or DeadCheck) then
		-- we create an usableSkip for some specific spells like hammer of wrath aoe mode
		if usableSkip == nil then usableSkip = false end
		-- stop if not enough power for that spell
		if usableSkip ~= true and IsUsableSpell(SpellID) ~= true then return false end
		-- Table used to prevent refiring too quick
		if timersTable == nil then timersTable = {}	end
		-- default noCast to false
		if noCast == nil then noCast = false end
		-- make sure it is a known spell
		if not (KnownSkip == true or isKnown(SpellID)) then return false end
		-- gather our spell range information
		local spellRange = select(6,GetSpellInfo(SpellID))
		if DistanceSkip == nil then DistanceSkip = false end
		if spellRange == nil or (spellRange < 4 and DistanceSkip==false) then spellRange = 4 end
		if DistanceSkip == true then spellRange = 40 end
		-- Check unit,if it's player then we can skip facing
		if (Unit == nil or UnitIsUnit("player",Unit)) -- Player
			or (Unit ~= nil and UnitIsFriend("player",Unit))  -- Ally
			or IsHackEnabled("AlwaysFacing")
		then
			FacingCheck = true
		elseif isSafeToAttack(Unit) ~= true then -- enemy
			return false
		end
		-- if MovementCheck is nil or false then we dont check it
		if MovementCheck == false or isMoving("player") ~= true
			-- skip movement check during spiritwalkers grace and aspect of the fox
			or UnitBuffID("player",79206) ~= nil then
			-- if ability is ready and in range
            -- if getSpellCD(SpellID) < select(4,GetNetStats()) / 1000
			if (getSpellCD(SpellID) < select(4,GetNetStats()) / 1000) and (getOptionCheck("Skip Distance Check") or getDistance("player",Unit) <= spellRange or DistanceSkip == true or inRange(SpellID,Unit)) then
				-- if spam is not allowed
				if SpamAllowed == false then
					-- get our last/current cast
					if timersTable == nil or (timersTable ~= nil and (timersTable[SpellID] == nil or timersTable[SpellID] <= GetTime() -0.6)) then
						if (FacingCheck == true or getFacing("player",Unit) == true) and (UnitIsUnit("player",Unit) or getLineOfSight("player",Unit) == true) then
							if noCast then
								return true
							else
								timersTable[SpellID] = GetTime()
								currentTarget = UnitGUID(Unit)
								botCast = true
								botSpell = SpellID
								CastSpellByName(GetSpellInfo(SpellID),Unit)
								if IsAoEPending() then
									local X,Y,Z = ObjectPosition(Unit)
									ClickPosition(X,Y,Z)
								end
								--lastSpellCast = SpellID
								-- change main button icon
								if getOptionCheck("Start/Stop BadRotations") then
									mainButton:SetNormalTexture(select(3,GetSpellInfo(SpellID)))
									lastSpellCast = SpellID
									lastSpellTarget = UnitGUID(Unit)
								end
								return true
							end
						end
					end
				elseif (FacingCheck == true or getFacing("player",Unit) == true) and (UnitIsUnit("player",Unit) or getLineOfSight("player",Unit) == true) then
					if noCast then
						return true
					else
						currentTarget = UnitGUID(Unit)
						botCast = true
						botSpell = SpellID
						CastSpellByName(GetSpellInfo(SpellID),Unit)
						if IsAoEPending() then
							local X,Y,Z = ObjectPosition(Unit)
							ClickPosition(X,Y,Z)
						end
						if getOptionCheck("Start/Stop BadRotations") then
							mainButton:SetNormalTexture(select(3,GetSpellInfo(SpellID)))
							lastSpellCast = SpellID
							lastSpellTarget = UnitGUID(Unit)
						end
						return true
					end
				end
			end
		end
	end
	return false
end
-- Cast Spell Queue
function castQueue()
	-- Catch for spells not registering on Combat log
	if br.player ~= nil then
		if br.player.queue ~= nil and #br.player.queue > 0 and not IsAoEPending() then
			local spellID = br.player.queue[1].id
			local spellName,_,texture = GetSpellInfo(spellID)
			local thisUnit = br.player.queue[1].target
			CastSpellByName(spellName,thisUnit)
			if getOptionCheck("Start/Stop BadRotations") then
				mainButton:SetNormalTexture(texture)
				lastSpellCast = spellID
				lastSpellTarget = UnitGUID(thisUnit)
			end
		end
	end
	return
end
--[[castSpellMacro(Unit,SpellID,FacingCheck,MovementCheck,SpamAllowed,KnownSkip)
Parameter 	Value
First 	 	UnitID 			Enter valid UnitID
Second 		SpellID 		Enter ID of spell to use
Third 		Facing 			True to allow 360 degrees,false to use facing check
Fourth 		MovementCheck	True to make sure player is standing to cast,false to allow cast while moving
Fifth 		SpamAllowed 	True to skip that check,false to prevent spells that we dont want to spam from beign recast for 1 second
Sixth 		KnownSkip 		True to skip isKnown check for some spells that are not managed correctly in wow's spell book.
Seventh 	DeadCheck 		True to skip checking for dead units. (IE: Resurrection Spells)
Eigth 		DistanceSkip    True to skip range checking.
Ninth 		usableSkip 		True to skip usability checks.
Tenth 		noCast			True to return True/False instead of casting spell.
]]
-- castSpell("target",12345,true)
--                ( 1  ,    2  ,     3     ,     4       ,      5    ,   6     ,   7     ,    8       ,   9      ,  10  )
function castSpellMacro(Unit,SpellID,FacingCheck,MovementCheck,SpamAllowed,KnownSkip,DeadCheck,DistanceSkip,usableSkip,noCast)
	if GetObjectExists(Unit) and betterStopCasting(SpellID) ~= true
		and (not UnitIsDeadOrGhost(Unit) or DeadCheck) then
		-- we create an usableSkip for some specific spells like hammer of wrath aoe mode
		if usableSkip == nil then usableSkip = false end
		-- stop if not enough power for that spell
		if usableSkip ~= true and IsUsableSpell(SpellID) ~= true then return false end
		-- Table used to prevent refiring too quick
		if timersTable == nil then timersTable = {}	end
		-- default noCast to false
		if noCast == nil then noCast = false end
		-- make sure it is a known spell
		if not (KnownSkip == true or isKnown(SpellID)) then return false end
		-- gather our spell range information
		local spellRange = select(6,GetSpellInfo(SpellID))
		if DistanceSkip == nil then DistanceSkip = false end
		if spellRange == nil or (spellRange < 4 and DistanceSkip==false) then spellRange = 4 end
		if DistanceSkip == true then spellRange = 40 end
		-- Check unit,if it's player then we can skip facing
		if (Unit == nil or UnitIsUnit("player",Unit)) or -- Player
			(Unit ~= nil and UnitIsFriend("player",Unit)) then  -- Ally
			FacingCheck = true
		elseif isSafeToAttack(Unit) ~= true then -- enemy
			return false
		end
		-- if MovementCheck is nil or false then we dont check it
		if MovementCheck == false or isMoving("player") ~= true
			-- skip movement check during spiritwalkers grace and aspect of the fox
			or UnitBuffID("player",79206) ~= nil then
			-- if ability is ready and in range
            -- if getSpellCD(SpellID) < select(4,GetNetStats()) / 1000
			if (getSpellCD(SpellID) < select(4,GetNetStats()) / 1000) and (getOptionCheck("Skip Distance Check") or getDistance("player",Unit) <= spellRange or DistanceSkip == true or inRange(SpellID,Unit)) then
				-- if spam is not allowed
				if SpamAllowed == false then
					-- get our last/current cast
					if timersTable == nil or (timersTable ~= nil and (timersTable[SpellID] == nil or timersTable[SpellID] <= GetTime() -0.6)) then
						if (FacingCheck == true or getFacing("player",Unit) == true) and (UnitIsUnit("player",Unit) or getLineOfSight("player",Unit) == true) then
							if noCast then
								return true
							else
								timersTable[SpellID] = GetTime()
								currentTarget = UnitGUID(Unit)
								RunMacroText("/cast [@"..Unit.."] "..GetSpellInfo(SpellID))
								--lastSpellCast = SpellID
								-- change main button icon
								if getOptionCheck("Start/Stop BadRotations") then
									mainButton:SetNormalTexture(select(3,GetSpellInfo(SpellID)))
									lastSpellCast = SpellID
									lastSpellTarget = UnitGUID(Unit)
								end
								return true
							end
						end
					end
				elseif (FacingCheck == true or getFacing("player",Unit) == true) and (UnitIsUnit("player",Unit) or getLineOfSight("player",Unit) == true) then
					if noCast then
						return true
					else
						currentTarget = UnitGUID(Unit)
						RunMacroText("/cast [@"..Unit.."] "..GetSpellInfo(SpellID))
						if getOptionCheck("Start/Stop BadRotations") then
							mainButton:SetNormalTexture(select(3,GetSpellInfo(SpellID)))
							lastSpellCast = SpellID
							lastSpellTarget = UnitGUID(Unit)
						end
						return true
					end
				end
			end
		end
	end
	return false
end
-- Used in openers
function castOpener(spellIndex,flag,index,checkdistance)
	local spellCast = br.player.spell[spellIndex]
	local castSpell = br.player.cast[spellIndex]
	local spellName = select(1,GetSpellInfo(spellCast))
	local maxRange = select(6,GetSpellInfo(spellCast))
	local cooldown = br.player.cd[spellIndex].remain()
	if not maxRange or maxRange == 0 then maxRange = 5 end
	if checkdistance == nil then checkdistance = true end
	if not checkdistance or getDistance("target") < maxRange then
	    if (not castSpell(nil,"debug") and (cooldown == 0 or cooldown > br.player.gcdMax)) then
	        Print(index..": "..spellName.." (Uncastable)");
	        _G[flag] = true;
	        return true
	    else
	        if castSpell() then Print(index..": "..spellName); _G[flag] = true; return true end
	    end
	end
end
function canCast(spellID,unit)
	if unit == nil then unit = "target" end
	return castSpell(unit,spellID,false,false,false,false,false,false,false,true)
end
function castMouseoverHealing(Class)
	if UnitAffectingCombat("player") then
		local spellTable = {
			["Druid"] = { heal = 8936,dispel = 88423 }
		}
		local npcTable = {
			71604,-- Contaminated Puddle- Immerseus - SoO
			71995,-- Norushen
			71996,-- Norushen
			72000,-- Norushen
			71357,-- Wrathion
		}
		local SpecialTargets = { "mouseover","target","focus"}
		local dispelid = spellTable[Class].dispel
		for i = 1,#SpecialTargets do
			local target = SpecialTargets[i]
			if GetUnitExists(target) and not UnitIsPlayer(target) then
				local npcID = tonumber(string.match(UnitGUID(target),"-(%d+)-%x+$"))
				for i = 1,#npcTable do
					if npcID == npcTable[i] then
						-- Dispel
						for n = 1,40 do
							local buff,_,count,bufftype,duration = UnitDebuff(target,n)
							if buff then
								if bufftype == "Magic" or bufftype == "Curse" or bufftype == "Poison" then
									if castSpell(target,88423,true,false) then
										return
									end
								end
							else
								break
							end
						end
						-- Heal
						local npcHP = getHP(target)
						if npcHP < 100 then
							if castSpell(target,spellTable[Class].heal,true) then
								return
							end
						end
					end
				end
			end
		end
	end
end
function isCastingTime(lagTolerance)
	local lagTolerance = 0
	if UnitCastingInfo("player") ~= nil then
		if select(5,UnitCastingInfo("player")) - GetTime() <= lagTolerance then
			return true
		end
	elseif UnitChannelInfo("player") ~= nil then
		if select(5,UnitChannelInfo("player")) - GetTime() <= lagTolerance then
			return true
		end
	elseif (GetSpellCooldown(GetSpellInfo(61304)) ~= nil and GetSpellCooldown(GetSpellInfo(61304)) <= lagTolerance) then
		return true
	else
		return false
	end
end
-- if getCastTime("Healing Touch")<3 then
function getCastTime(spellID)
	if spellID == 202767 then
		if select(3,GetSpellInfo(202767)) == 1392545 then spellID = 202767
       	elseif select(3,GetSpellInfo(202767)) == 1392543 then spellID = 202768
        elseif select(3,GetSpellInfo(202767)) == 1392542 then spellID = 202771
        end
    end
	local castTime = select(4,GetSpellInfo(spellID))/1000
	return castTime
end
function getCastTimeRemain(unit)
	if UnitCastingInfo(unit) ~= nil then
		return select(5,UnitCastingInfo(unit))/1000 - GetTime()
	elseif UnitChannelInfo(unit) ~= nil then
		return select(5,UnitChannelInfo(unit))/1000 - GetTime()
	else
		return 0
	end
end
-- if isCasting() == true then
function castingUnit(Unit)
	if Unit == nil then Unit = "player" end
	if UnitCastingInfo(Unit) ~= nil
		or UnitChannelInfo(Unit) ~= nil
		or (GetSpellCooldown(61304) ~= nil and GetSpellCooldown(61304) > 0.001) then
		return true
	else
		return false
	end
end
-- if isCastingSpell(12345) == true then
function isCastingSpell(spellID,unit)
	if unit == nil then unit = "player" end
	local spellName = select(1,GetSpellInfo(spellID))
	local spellCasting = select(1,UnitCastingInfo(unit))
	if spellCasting == nil then
		spellCasting = select(1,UnitChannelInfo(unit))
	end
	if tostring(spellCasting) == tostring(spellName) then
		return true
	else
		return false
	end
end
-- if isCasting(12345,"target") then
function isCasting(SpellID,Unit)
	if GetObjectExists(Unit) and GetUnitIsVisible(Unit) then
		if isCasting(tostring(GetSpellInfo(SpellID)),Unit) == 1 then
			return true
		end
	else
		return false
	end
end
-- if isCastingSpell(12345) == true then
function isUnitCasting(unit)
	if unit == nil then unit = "player" end
	local spellCasting = UnitCastingInfo(unit)
	if spellCasting == nil then
		spellCasting = UnitChannelInfo(unit)
	end
	if spellCasting ~= nil then
		return true
	else
		return false
	end
end

function createCastFunction(thisUnit,debug,minUnits,effectRng,spellID,index)
    -- Invalid Spell ID Check
    if GetSpellInfo(spellID) == nil then Print("Invalid Spell ID: "..spellID.." for key: "..index) end
    -- Locals
    local spellCast = spellID
    local spellName,_,_,_,minRange,maxRange = GetSpellInfo(spellID)
    local spellType = getSpellType(spellName)
    -- local minRange = tonumber(select(5,GetSpellInfo(spellName)))
    -- local maxRange = tonumber(select(6,GetSpellInfo(GetSpellInfo(spellID))))
    -- Nil Catches
    if minRange == nil then minRange = 0 end
    if maxRange == nil or maxRange == 0 then maxRange = 5 else maxRange = tonumber(maxRange) end
    if minUnits == nil then minUnits = 1 end
    if effectRng == nil then effectRng = 5 end
    if debug == nil then debug = "norm" end
    local function castDebug()
        if isChecked("Cast Debug") and debug ~= "debug" then
            local unitName = UnitName(thisUnit) or thisUnit
            Print("Casting |cffFFFF00"..spellName.." ("..spellID..") |r on |cffFFFF00"..tostring(UnitName(thisUnit)).."\n |r Spell Type: |cffFFFF00"..spellType..
            	" |r, Cast Type: |cffFFFF00"..tostring(debug).."\n |r Ranges - Min: |cffFFFF00"..minRange.." |r, Max: |cffFFFF00"..maxRange..
            	" |r, Eff: |cffFFFF00"..effectRng.." |r, Min Units: |cffFFFF00"..minUnits)
        end
    end
    -- Base Spell Availablility Check
    if --[[isChecked("Use: "..spellName) and ]]not select(2,IsUsableSpell(spellID)) and getSpellCD(spellID) == 0 and (isKnown(spellID) or debug == "known") then --and not isIncapacitated(spellID) then
        -- Attempt to determine best unit for spell's range
        if thisUnit == nil then
        	if debug == "norm" or debug == "dead" or debug == "rect" or debug == "cone" then
        		thisUnit = getSpellUnit(spellCast)
        	else
        		thisUnit = getSpellUnit(spellCast,true)
        	end
        end
        -- Return specified/best cast method
        if debug == "debug" then
            castDebug()
            return true --castSpell(thisUnit,spellCast,false,false,false,false,false,false,false,true)
        elseif thisUnit == "best" then
            castDebug()
            return castGroundAtBestLocation(spellCast,effectRng,minUnits,maxRange,minRange,debug)
        elseif thisUnit == "playerGround" and (getDistance("player") < maxRange or IsSpellInRange(spellName,"player") == 1) then
            castDebug()
            return castGroundAtUnit(spellCast,effectRng,minUnits,maxRange,minRange,debug,"player")
        elseif thisUnit == "targetGround" and (getDistance("target") < maxRange or IsSpellInRange(spellName,"target") == 1) then
            castDebug()
            return castGroundAtUnit(spellCast,effectRng,minUnits,maxRange,minRange,debug,"target")
        elseif thisUnit ~= nil then
            local distance = getDistance(thisUnit)
            if ((distance >= minRange and distance < maxRange) or IsSpellInRange(spellName,thisUnit) == 1) then
                if debug == "rect" then
	        		if isSafeToAoE(spellID,thisUnit,effectRng,minUnits,"rect") then
                    	castDebug()
                    	return castSpell(thisUnit,spellCast,false,false,false,true,false,true,true,false)
                    end
                elseif debug == "cone" then
	        		if isSafeToAoE(spellID,thisUnit,effectRng,minUnits,"cone") then
                		castDebug()
                		return castSpell(thisUnit,spellCast,false,false,false,true,false,true,true,false)
                	end
                elseif debug == "ground" then
			        if isSafeToAoE(spellID,thisUnit,effectRng,minUnits) then
	                    if getLineOfSight(thisUnit) then
	                        if not IsMouseButtonDown(2) then
	                            castDebug()
	                            return castGround(thisUnit,spellCast,maxRange,minRange,effectRng)
	                        end
	                    end
	                end
                elseif debug == "aoe" then
			        if isSafeToAoE(spellID,thisUnit,effectRng,minUnits) then
                    	castDebug()
                    	return castSpell(thisUnit,spellCast,false,false,false,true,false,true,true,false)
                    end
                elseif debug == "dead" and UnitIsPlayer(thisUnit) and UnitIsDeadOrGhost(thisUnit) and UnitIsFriend(thisUnit,"player") then
                    castDebug()
                    return castSpell(thisUnit,spellCast,false,false,false,true,true,true,true,false)
                elseif debug == "norm" then
	                castDebug()
	                return castSpell(thisUnit,spellCast,true,false,false,true,false,true,true,false)
	            end
	        else
	        	if (isChecked("Display Failcasts") or isChecked("Cast Debug")) and debug ~= "debug" then
	            	Print("|cffFF0000Error: |r Failed to cast. - ".."Name: "..spellName..", ID: "..spellID..", Type: "..spellType..", Min Range: "..minRange..", Max Range: "..maxRange)
	            end
	            return false
            end
        elseif (thisUnit == nil or thisUnit == "best" or thisUnit == "playerGround" or thisUnit == "targetGround") and getDistance(br.player.units(maxRange)) < maxRange then
            if (isChecked("Display Failcasts") or isChecked("Cast Debug")) and debug ~= "debug" then
                Print("|cffFF0000Error: |r Failed to cast. - ".."Name: "..spellName..", ID: "..spellID..", Type: "..spellType..", Min Range: "..minRange..", Max Range: "..maxRange)
            end
            return false
        end
    elseif debug == "debug" then
        return false
    end
end
