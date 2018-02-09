CoD.PlayerLives = InheritFrom(LUI.UIElement)

function CoD.PlayerLives.new(PlayerLivesWidget, InstanceRef)
	local PlayerLivesWidget = LUI.UIElement.new()
	PlayerLivesWidget:setClass(CoD.PlayerLives)
	PlayerLivesWidget.id = "PlayerLives"
	PlayerLivesWidget.soundSet = "default"

	CoD.PlayerLifeImg = RegisterImage("i_mod_oic_player_life")
	PlayerLivesWidget.PlayerLives = {}

	for i=0,2 do
		-- create it
		local PlayerLife = LUI.UIImage.new(HudRef, InstanceRef)
		-- set the distance apart 64 units
		PlayerLife:setLeftRight(false, false, -128 + (96 * i), -32 + (96 * i ))
		-- set the distance apart 64 units
		PlayerLife:setTopBottom(false, true, -96, -0)
		-- set the image
		PlayerLife:setImage(CoD.PlayerLifeImg)
		-- add into hud
		PlayerLivesWidget:addElement(PlayerLife)
		-- store in array
		PlayerLivesWidget.PlayerLives[i] = PlayerLife;
	end

	local function checkForLivesUpdated(ModelRef)
		local value = Engine.GetModelValue(ModelRef)
		for i=0,value-1 do
			PlayerLivesWidget.PlayerLives[i]:setAlpha(1)
		end
		for i=value,2 do
			PlayerLivesWidget.PlayerLives[i]:beginAnimation("keyframe", 500.000000, true, true, CoD.TweenType.Linear)
			PlayerLivesWidget.PlayerLives[i]:setAlpha(0)
		end
	end

	local PlayerLivesModel = Engine.CreateModel(Engine.GetModelForController(InstanceRef), "hudItems.players_lives")
	PlayerLivesWidget:subscribeToModel(Engine.GetModel(Engine.GetModelForController(InstanceRef), "hudItems.players_lives"), checkForLivesUpdated)
	Engine.SetModelValue(PlayerLivesModel, 0)

	return PlayerLivesWidget
end