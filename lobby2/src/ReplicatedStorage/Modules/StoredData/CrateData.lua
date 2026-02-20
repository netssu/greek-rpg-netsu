local CrateData = {}

CrateData.UnitTiers = {
	["Suzette"] = "Common",
	["Cowboy"] = "Common",
	["Sheriff Pete"] = "Rare",
	["Tim Scientist"] = "Rare",
	["Grenader"] = "Epic",
	["Magician"] = "Epic",
	["General"] = "Epic",
	["Wizard"] = "Legendary",
	["Wobblus"] = "Legendary",
	["Professor"] = "Mythic",
	["Airport"] = "Mythic",
	["Grandma"] = "Mythic",
}

CrateData.Banners = {
	["Normal"] = {
		DisplayName = "Normal Banner",
		Price = 1000,
		Currency = "Coins",
		PityThreshold = 50,
		Rates = {
			["Common"] = 6500,
			["Rare"] = 2500,
			["Epic"] = 900,
			["Legendary"] = 100,
			["Mythic"] = 0,
		}
	},

	["Steel"] = {
		DisplayName = "Steel Banner",
		Price = 5000,
		Currency = "Coins",
		PityThreshold = 45,
		Rates = {
			["Common"] = 4000,
			["Rare"] = 4000,
			["Epic"] = 1800,
			["Legendary"] = 200,
			["Mythic"] = 0,
		}
	},

	["Golden"] = {
		DisplayName = "Golden Banner",
		Price = 10000,
		Currency = "Coins",
		PityThreshold = 40,
		Rates = {
			["Common"] = 0,
			["Rare"] = 5000,
			["Epic"] = 4000,
			["Legendary"] = 900,
			["Mythic"] = 100,
		}
	},

	["Diamond"] = {
		DisplayName = "Diamond Banner",
		Price = 500,
		Currency = "Gems",
		PityThreshold = 80,
		Rates = {
			["Common"] = 0,
			["Rare"] = 0,
			["Epic"] = 2000,
			["Legendary"] = 7250,
			["Mythic"] = 750,
		}
	}
}

return CrateData