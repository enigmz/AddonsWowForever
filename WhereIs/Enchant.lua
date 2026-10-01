local _, DC = ...

-- Materiales de encantamiento que salen al desencantar.
-- En clásico vale cualquier arma o armadura (también anillos, collares y capas)
-- del nivel de objeto indicado. No depende de un objeto con nombre concreto.
-- chance es el porcentaje de esa tirada. fromThree: 3 del otro hacen 1 de este.

DC.Disenchant = {
	[10940] = {
		sources = {
			{ quality = "Verde", min = 5, max = 10, amount = "1 o 2", chance = 80, where = "Mazmorras y zonas de nivel 5-15" },
			{ quality = "Verde", min = 11, max = 15, amount = "2 o 3", chance = 75, where = "Mazmorras de nivel 10-20" },
			{ quality = "Verde", min = 16, max = 20, amount = "2 a 5", chance = 75, where = "Minas de la Muerte y Cuevas de los Lamentos" },
		},
	},
	[10938] = {
		swap = 10939,
		sources = {
			{ quality = "Verde", min = 5, max = 10, amount = "1 o 2", chance = 20, where = "Es la esencia de este tramo" },
			{ quality = "Verde", min = 11, max = 20, amount = "1 o 2", chance = 5, where = "Sale poco; aquí manda la esencia superior" },
		},
	},
	[10939] = {
		swap = 10938,
		fromThree = true,
		sources = {
			{ quality = "Verde", min = 11, max = 20, amount = "1 o 2", chance = 20, where = "Minas de la Muerte y Cuevas de los Lamentos" },
		},
	},
	[11083] = {
		sources = {
			{ quality = "Verde", min = 21, max = 25, amount = "1 o 2", chance = 75, where = "Horado y Monasterio Escarlata" },
			{ quality = "Verde", min = 26, max = 30, amount = "2 a 5", chance = 75, where = "Horado y Monasterio Escarlata" },
		},
	},
	[10998] = {
		swap = 11082,
		sources = {
			{ quality = "Verde", min = 21, max = 25, amount = "1 o 2", chance = 20, where = "Es la esencia de este tramo" },
			{ quality = "Verde", min = 26, max = 30, amount = "1 o 2", chance = 15, where = "Sale menos; aquí manda la esencia superior" },
		},
	},
	[11082] = {
		swap = 10998,
		fromThree = true,
		sources = {
			{ quality = "Verde", min = 21, max = 25, amount = "1 o 2", chance = 5, where = "Poca cantidad" },
			{ quality = "Verde", min = 26, max = 30, amount = "1 o 2", chance = 10, where = "Horado y Monasterio Escarlata" },
		},
	},
	[11137] = {
		sources = {
			{ quality = "Verde", min = 31, max = 35, amount = "1 o 2", chance = 75, where = "Uldaman y Zul'Farrak" },
			{ quality = "Verde", min = 36, max = 40, amount = "2 a 5", chance = 75, where = "Uldaman, Zul'Farrak y Monasterio Escarlata" },
		},
	},
	[11134] = {
		swap = 11135,
		sources = {
			{ quality = "Verde", min = 31, max = 35, amount = "1 o 2", chance = 20, where = "Es la esencia de este tramo" },
			{ quality = "Verde", min = 36, max = 40, amount = "1 o 2", chance = 5, where = "Sale poco; aquí manda la esencia superior" },
		},
	},
	[11135] = {
		swap = 11134,
		fromThree = true,
		sources = {
			{ quality = "Verde", min = 31, max = 35, amount = "1 o 2", chance = 5, where = "Poca cantidad" },
			{ quality = "Verde", min = 36, max = 40, amount = "1 o 2", chance = 20, where = "Uldaman y Zul'Farrak" },
		},
	},
	[11176] = {
		sources = {
			{ quality = "Verde", min = 41, max = 45, amount = "1 o 2", chance = 75, where = "Maraudon y Templo Sumergido" },
			{ quality = "Verde", min = 46, max = 50, amount = "2 a 5", chance = 75, where = "Maraudon y Profundidades de Roca Negra" },
		},
	},
	[11174] = {
		swap = 11175,
		sources = {
			{ quality = "Verde", min = 41, max = 45, amount = "1 o 2", chance = 20, where = "Es la esencia de este tramo" },
			{ quality = "Verde", min = 46, max = 50, amount = "1 o 2", chance = 5, where = "Sale poco; aquí manda la esencia superior" },
		},
	},
	[11175] = {
		swap = 11174,
		fromThree = true,
		sources = {
			{ quality = "Verde", min = 41, max = 45, amount = "1 o 2", chance = 5, where = "Poca cantidad" },
			{ quality = "Verde", min = 46, max = 50, amount = "1 o 2", chance = 20, where = "Profundidades de Roca Negra" },
		},
	},
	[16204] = {
		sources = {
			{ quality = "Verde", min = 51, max = 55, amount = "1 o 2", chance = 75, where = "Cumbre de Roca Negra, Scholomance y Stratholme" },
			{ quality = "Verde", min = 56, max = 60, amount = "2 a 5", chance = 75, where = "Scholomance, Stratholme y La Masacre" },
		},
	},
	[16202] = {
		swap = 16203,
		sources = {
			{ quality = "Verde", min = 51, max = 55, amount = "1 o 2", chance = 20, where = "Es la esencia de este tramo" },
			{ quality = "Verde", min = 56, max = 60, amount = "1 o 2", chance = 5, where = "Sale poco; aquí manda la esencia superior" },
		},
	},
	[16203] = {
		swap = 16202,
		fromThree = true,
		sources = {
			{ quality = "Verde", min = 51, max = 55, amount = "1 o 2", chance = 5, where = "Poca cantidad" },
			{ quality = "Verde", min = 56, max = 60, amount = "1 o 2", chance = 20, where = "Scholomance, Stratholme y La Masacre" },
		},
	},
	[10978] = {
		sources = {
			{ quality = "Azul", min = 1, max = 20, amount = "1", chance = 100, where = "Azules de mazmorras de nivel 10-20" },
		},
	},
	[11084] = {
		sources = {
			{ quality = "Azul", min = 21, max = 25, amount = "1", chance = 100, where = "Horado y Monasterio Escarlata" },
		},
	},
	[11138] = {
		sources = {
			{ quality = "Azul", min = 26, max = 30, amount = "1", chance = 100, where = "Horado y Monasterio Escarlata" },
		},
	},
	[11139] = {
		sources = {
			{ quality = "Azul", min = 31, max = 35, amount = "1", chance = 100, where = "Uldaman y Zul'Farrak" },
		},
	},
	[11177] = {
		sources = {
			{ quality = "Azul", min = 36, max = 40, amount = "1", chance = 100, where = "Uldaman y Zul'Farrak" },
		},
	},
	[11178] = {
		sources = {
			{ quality = "Azul", min = 41, max = 45, amount = "1", chance = 100, where = "Maraudon y Templo Sumergido" },
		},
	},
	[14343] = {
		sources = {
			{ quality = "Azul", min = 46, max = 50, amount = "1", chance = 100, where = "Maraudon y Profundidades de Roca Negra" },
		},
	},
	[14344] = {
		sources = {
			{ quality = "Azul", min = 51, max = 60, amount = "1", chance = 100, where = "Cumbre de Roca Negra, Scholomance, Stratholme y La Masacre" },
		},
	},
	[20725] = {
		sources = {
			{ quality = "Épico", min = 51, max = 55, amount = "1", where = "Menos habitual; a menudo sale un fragmento grande brillante" },
			{ quality = "Épico", min = 56, max = 60, amount = "1", chance = 100, where = "Equipo épico de nivel alto" },
		},
	},
}
