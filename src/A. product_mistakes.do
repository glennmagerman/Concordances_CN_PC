* Project: Price updating with production networks
* Author: Glenn Magerman
* First version: April, 2018.
* This version: February, 2020.
* Stata Version 17

// List of known issues with E-codes

replace pc8 = "232000E1" if pc8 == "2320000"			
replace pc8 = "401000E1" if pc8 == "4010000"			// does not show up in aggr letter list
replace pc8 = "401010E1" if pc8 == "4010100"
replace pc8 = "401110E1" if pc8 == "4011100"

replace pc8 = "19102100" if pc8 == "19202100" 			// non-existent code in 2002 only, exists in other years and maps to this cn8 in those other years

// irregular typos 
replace pc8 = "20201337" if pc8 =="ex"					// typo in original file
