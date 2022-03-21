// List of known issues with unit labels

	replace x = subinstr(x, "Â", "", .)

	replace x = "kg act. subst." if x == "kg act. Subst." 
	replace x = "kg act. subst." if x == "kg act.subst"
	replace x = "kg act. subst." if x == "kg act.subst."
	replace x = "l alc. 100%" if x == "l alc. 100 %" 
	replace x = "l alc. 100%" if x == "l alc 100%"
	replace x = "l alc. 100%" if x == "l alc. 100 %" 

	replace x = "1000 kWh" if x == "1000kWh"
	replace x = "1000 kWh" if x == "1 000 kWh"
		
	replace x = "kg met.am." if x == "kg met.am."
	replace x = "kg/net eda" if x == "kg/net eda"
	
	replace x = "kg Al2O3" if x == "kg Al‚ÇÇO‚ÇÉ"
	replace x = "kg Al2O3" if x == "kg Al₂O₃"
	replace x = "kg B2O3" if x == "kg B₂O₃"
	replace x = "kg BaCO3" if x == "kg B‚ÇÇO‚ÇÉ"
	replace x = "kg C5H14ClNO" if x == "kg C5H14ClNO"
	replace x = "kg H2O2" if x == "kg H2O2" 
	replace x = "kg H2O2" if x == "kg H₂O₂"	
	replace x = "kg H2SO4" if x == "kg H₂SO₄" 
	replace x = "kg H2SO4" if x == "kg H‚ÇÇO‚ÇÇ" 
	replace x = "kg K2O" if x == "kg K‚ÇÇO"		// while correct is K2SO4, other potassium sulphate entries are recorded as K2O
	replace x = "kg K2O" if x == "kg K₂O"
	replace x = "kg K2O" if x == "kg K2O"
	replace x = "kg KOH" if x == "kg KOH"
	replace x = "kg N" if x == "kg N"
	replace x = "kg Na2CO3" if x == "kg Na‚ÇÇCO‚ÇÉ" 
	replace x = "kg Na2CO3" if x == "kg Na₂CO₃"	// while correct is kg C2H6Na4O12, other Disodium Carbonate entries are recorded as Na2CO3
	replace x = "kg Na2S2O5" if x == "kg Na‚ÇÇS‚ÇÇO‚ÇÖ" 
	replace x = "kg Na2S2O5" if x=="kg Na₂S₂O₅"
	replace x = "kg NaOH" if x == "kg NaOH"
	replace x = "kg P2O5" if x == "kg P₂O₅"
	replace x = "kg P2O5" if x == "kg P2O5"
	replace x = "kg PbO" if x == "kg P‚ÇÇO‚ÇÖ"
	replace x = "kg SO2" if x == "kg SO‚ÇÇ" 
	replace x = "kg SO2" if x == "kg SO₂"
	replace x = "kg SiO2" if x == "kg SiO‚ÇÇ" 
	replace x = "kg SiO2" if x == "kg SiO₂"
	replace x = "kg TiO2" if x == "kg TiO‚ÇÇ" 
	replace x = "kg TiO2" if x == "kg TiO₂"
	replace x = "kg U" if x == "kg U"
	
	replace x = "m²" if x == "m¬≤"
	replace x = "m³" if x == "m¬≥"
	replace x = "m³" if x =="mn"
	replace x = "m²" if x == "m2"
	replace x = "m³" if x == "m3"
	replace x = "1000 m³" if x == "1000 m3"
	replace x = "1000 m³" if x == "1000 m3"
	replace x = "1000 l" if x == "1 000 l"
	replace x = "1000 m³" if x == "1 000 m3" | x == "1 000 m³"
	replace x = "1000 p/st" if x == "1 000 p/st" 
	replace x = "1000 p/st" if x == "1 000 p/st"
	replace x = "100 p/st" if x == "100 p/st" 
	replace x = "gi F/S" if x == "gi F/S" 
	replace x = "kg 90% sdt" if x == "kg 90 % sdt" 






	
	cap replace unit_code = 1534 if x == "kg H2SO4"		// recent code
