* Project: Price updating with production networks
* Author: Glenn Magerman
* First version: April, 2018.
* This version: February, 2020.
* Stata Version 17

/*______________________________________________________________________________

Notes
- Users with B- or N-list optional codes first have to aggregate our numeric  
  PC8 codes to compulsory codes before applying concordances. Mappings are 
  provided in the B_lists and N_list files.
______________________________________________________________________________*/

*-------------------------------------
**# 1. Import raw pc8 codes from RAMON
*-------------------------------------
// import descriptions of pc8 codes (downloads RAMON website)
forvalues t = 2001/2014 {
	import excel "./input/pc/pc_desc_`t'.xlsx", firstrow clear
	cap replace pc8 = subinstr(pc8, ".","",.)
	drop if length(pc8)<7 | missing(pc8) | length(pc8) >10	// headers and 2 mistakes in 2012 excel that are aggregates. length=10 are N-list codes.
save "./tmp/pc_desc_`t'", replace
}	

// import pc8 codes, disagg mappings, units, desc and prodtype (downloads RAMON website)
forvalues t = 2001/2014 {
	import excel using "./input/pc/PC_`t'.xls", firstrow clear
	if `t' == 2012 {											
		ren Code prccode
		gen unita=""										// import info for 2012 later on
		gen prcaggr=""										
	}
	ren *, lower											
	cap ren code prccode	
	cap ren productiontype prodtype
	cap gen str blist =""		
	cap tostring blist, replace
	replace blist ="" if blist=="."
	ren (prccode unit unita) (pc8 unit_label unit_code)
	keep pc8 prcaggr blist unit_label unit_code prodtype
	cap replace pc8 = subinstr(pc8, ".","",.)
	drop if length(pc8)<7 | missing(pc8) | length(pc8) >10	// headers or 2 mistakes in 2012. length=10 are N-list codes.
	merge 1:1 pc8 using "./tmp/pc_desc_`t'", ///
	nogen keep(match master) keepusing(desc)				
	tostring unit_code, replace
	ren unit_label x
	do "./src/A. unit_labels.do"							// clean labels of units
	ren x unit_label
	gen year = `t'
save "./tmp/pc8_`t'", replace								
}

// collect years
use "./tmp/pc8_2001", clear									
	forvalues t = 2002/2014 {
		append using "./tmp/pc8_`t'"
	}	
save "./tmp/pc8_panel", replace								// 63,341 obs		

/* This file contains raw imports from the RAMON database:
- numeric PC8 codes, 
- B-list optional codes and their A aggregates,
- N-list optional codes and their 8-digit numeric aggregates, 
- T-list codes for mappings between PC and CN,
- remaining letter codes (E, Q, V, Z) + links to their disaggregates in prcaggr.
- additional info on volume units, production type, and a string description.
*/

*----------------------
**# 2. Prepare cleaning
*----------------------
// check what needs to be cleaned
use "./tmp/pc8_panel", clear									// check all variables.
foreach x in year pc8 unit_label unit_code prodtype blist prcaggr  {
	di "summary `x'"
	tab year if missing(`x')								
}	

// optional codes (B- and N-list)
	tab blist												// 797 aggregates (A) with 2,264 disaggregates (B)
	tab pc8 if strpos(pc8, "N")								// 912 N-list codes

// letter aggregates	
	tab year if strpos(pc8, "Z")							// 542 Z-codes. have mappings to disaggregates in prcaggr
	tab year if strpos(pc8, "T")							// 300 T-codes. from 2003 onwards. no 8d counterpart, but used in CN to PC mappings.
	tab year if strpos(pc8, "Q")							// 268 Q-codes. eliminated by 2005.
	tab year if strpos(pc8, "E")							// 8 E-codes. eliminated by 2005.
	tab year if strpos(pc8, "V")							// 38 V-codes. eliminated by 2003.
	tab year if missing(prcaggr) & strpos(pc8, "Z")			// 35, all 2012. added separately below.
	tab year if missing(prcaggr) & strpos(pc8, "T")			// 300. have no mappings to 8digit numerical codes. only map to CN.
	tab year if missing(prcaggr) & strpos(pc8, "Q")			// 0. ok 
	tab year if missing(prcaggr) & strpos(pc8, "E")			// 0. ok 
	tab year if missing(prcaggr) & strpos(pc8, "V")			// 0. ok 
	
// information on volume units
	tab unit_label											// strings with description of volume units contain inconsistencies and non-ASCII characters.
	br if missing(unit_label)								// 2,050 missing word labels on volume units 
	tab prodtype if missing(unit_label)						// 2,047 are non T prod types (possibly need no info on volumes)
	tab unit_code if missing(unit_label)					// +3 obs misplaced  word label in numerical code column
	tab year if missing(unit_code)							// 8,600 have missing codes for volume units. most in 2012.
	tab prodtype if missing(unit_code)						// most of these are non T prod types (possibly need not report info on volumes).
	tab unit_label if missing(unit_code)					// but for most observe string volume units, can infer code below.
		
// other items
	tab prodtype											// there are 5 prodtypes, some typos exist
	br if missing(prodtype)									// 5 obs
		
*-----------------------------
**# 3. clean other items first
*-----------------------------
use "./tmp/pc8_panel", clear
	replace unit_label = unit_code if missing(unit_label)	// 3 swapped labels and codes
	tab unit_code											// still 1 swap remains (p/st), use codes merge below
	destring unit_code, force replace						// 10,676 obs missing, either "-" or "." labeled before.				
	
	br pc8 year if prodtype=="@" | prodtype=="l" 			// looked up codes 28232300 and 33131900 in structure files to find production types
	replace prodtype = "I" if prodtype=="l"
	replace prodtype = "S" if prodtype=="@"
	
	fcollapse (firstnm) tmp_prod = prodtype, by(pc8) merge	// some codes have missing prodtype in some year, but can use other years to infer.
	replace prodtype = tmp_prod if missing(prodtype)		
	drop tmp_prod
	assert !missing(prodtype)								// none missing anymore.
save "./tmp/pc8_panel2", replace

*----------------------------
**# 4. clean volume unit info
*----------------------------
// manual cleaning label strings
use "./tmp/pc8_panel2", clear	
	replace unit_label = "-" if unit_label =="."
	ren unit_label x
	do "./src/A. unit_labels.do"							// known issues with verbal descriptions
	ren x unit_label
	
	distinct unit_label
	tab unit_label											// 48 volume units, cleaned, but some have 2 units reported. split below.
	
// fill in missing unit label strings using codes
	tab prodtype if missing(unit_label)						// if unit_label missing, also unit_code missing, and all are I or S codes (maybe no volume required)
	merge m:1 unit_code using "./input/pc/unit_labs", ///		
	keep(match master) keepusing(label) 					//  m==1: no info on unit_code, infer codes below

// find remaining inconsistencies between labels and codes	
	egen diff = diff(unit_label label)						
	br year pc8 unit_label unit_code label if diff==1 & _m==3
	tab unit_label if diff==1 & _m==3						
	// some pc8 codes have dual reporting units (e.g. kg + p/st), create secondary unit.
	// remaining codes are mismatch between code and label. (16 of these codes are in 2010).
	
// clean mismatches
	br pc8 unit* year label if unit_label != label & ///	// check t-1/t+1 in Prodcom technical document. 
	!missing(label) & !strpos(unit_label, "+")				// priority to unit_label in structure file, change unit_code							
	drop _m diff
	ren (label unit_label unit_code) (tmp_label label tmp_code)
	merge m:1 label using "./input/pc/unit_labs", ///			
	nogen keep(match master) keepusing(unit_code)
	replace tmp_code = unit_code if label != tmp_label ///
	& !missing(tmp_label) & !strpos(label, "+") 	
	// 1 inconsistency remains: pc8 29322050 in 2008. 
	// from manual or structure files: no units have to be reported, put label and code to missing
	drop unit_code tmp_label
	ren (label tmp_code) (unit_label unit_code)
	
// create secondary units 
	replace unit_label = subinstr(unit_label, " ", "", .) if strpos(unit_label, "+") 
	split unit_label, p("+")
	drop unit_label
	ren (unit_label1 unit_label2 unit_code) (unit_label label tmp_code)			
	merge m:1 label using "./input/pc/unit_labs", ///			
	keep(match master) keepusing(unit_code) nogen
	ren (label unit_code tmp_code) (unit_label2 unit_code2 unit_code)
	
// fill in missing unit codes if info on labels	
	ren (unit_label unit_code) (label tmp_code)			
	merge m:1 label using "./input/pc/unit_labs", ///			
	keep(match master) keepusing(label unit_code) 	
	replace tmp_code = unit_code if _m==3 & missing(tmp_code)	// 3,395 obs. 
	drop _m unit_code 											
	ren (tmp_code label) (unit_code unit_label)	
	
// remaining missing unit_label and unit_code
	tab prodtype if missing(unit_label) | ///
	unit_label =="-" | unit_label =="."						// 7,265 obs, all I or S product types
	tab prodtype if missing(unit_code)						// 7,265 obs
	tab prodtype if !missing(unit_code) & (missing(unit_label) | ///
	unit_label =="-" | unit_label ==".")					// 0 obs --> fully overlapping
	// 7,265 obs have no info on label or code, 
	// are all non T prodtype:  only have to report values, not quantities.
	replace unit_label = "-" if unit_label == "" | unit_label=="." // harmonize missing codes

	distinct unit_label unit_code							// 42 + 1 (missing) and 42
	tab unit_label
	tab unit_code
	order year pc8 desc unit_code unit_label unit_code2 unit_label2 prodtype
	sort year pc8
	
// labels
	label var year "year t"
	label var pc8 "PC8 code"
	label var desc "verbal description"
	label var unit_code "volume unit (code)"
	label var unit_label "volume unit (label)"
	label var unit_code2 "2nd volume unit (code)"
	label var unit_label2 "2nd volume unit (label)"
	label var prodtype "production type"
	label var blist "B-list classification"
	label var prcaggr "Prodcom Aggregate split"
	compress
save "./output/pc8_byyear_incl_letters", replace			// 63,341 obs. list of pc8 codes by year. 
export delimited using "./output/pc8_byyear_incl_letters.tsv", replace delim("tab")

*-----------------------------
**# 5. prepare letter mappings
*-----------------------------
// keep codes that have mappings (optional and aggregates)
// T-list, export separately (no mapping to pc8 numeric codes)
// B- and N-lists, keep mandatory codes and split into optionals using prcaggr
// other letter codes, split into disaggregates using prcaggr
use "./output/pc8_byyear_incl_letters", clear	
	keep year pc8 blist prcaggr
	preserve												// export T-list codes
		keep if strpos(pc8, "T")
		drop blist prcaggr
		compress
		save "./output/T_lists", replace
		export delimited using "./output/T_lists.tsv", replace delim("tab")
	restore
	drop if strpos(pc8, "T")								// drop T-list
	drop if strpos(pc8, "N")								// drop optional N-codes 
	drop if blist=="B"										// drop optional B-codes
	drop if missing(prcaggr) 								// 2012 added separately below
	keep if strpos(pc8, "E") |  strpos(pc8, "Q") | ///		// keep aggregate letter codes
	strpos(pc8, "V") | strpos(pc8, "Z") | ///				
	blist=="A" | strpos(prcaggr, "N")						// keep B- and N-list aggregates
	
	replace prcaggr = subinstr(prcaggr, ")", "", .)			// clean ending characters to prepare splits
	replace prcaggr = subinstr(prcaggr, "]", "", .)
	replace prcaggr = subinstr(prcaggr, ".", "", .)
	replace prcaggr = subinstr(prcaggr, " ", "", .)			
save "./tmp/pc_agg_mappings", replace						// 1,994 obs

*---------------------------------------------
**# 6. Create disaggregates for optional codes
*--------------------------------------------- 
// B-list	
use "./tmp/pc_agg_mappings", clear
	keep if blist=="A"										// 797 obs
	keep year pc8 prcaggr
	split prcaggr, p("(")
	replace prcaggr1 = substr(prcaggr1, -6,.)				// codes with additional N mappings, only use B here
	ren prcaggr2 z
	split z, p("+")
	drop z prcaggr
	ren prcaggr1 z0
	qui desc, varlist										// flag number of splits
	loc lastvar: word `c(k)' of `r(varlist)'
	gen lastvar = "`lastvar'"
	destring lastvar, replace ignore(z)
	qui su lastvar
	loc endvar = r(max)
	forvalues t = 1/`endvar' {								// merge extensions to trunks
		keep if strlen(z`t')==2 | missing(z`t')				// drop irregular lengths of substrings
		egen X`t' = concat(z0 z`t')
		replace X`t'="" if length(X`t')<7 | length(X`t')>8
	}	
	drop z*
	egen id = group(year pc8)
	reshape long X, i(id) j(x)
	drop if missing(X)
	keep year pc8 X 
	ren X optional
	order year pc8 optional
	compress
save "./output/B_lists", replace								// 2,264 obs
export delimited using "./output/B_lists.tsv", replace delim("tab")

// N-list
use "./tmp/pc_agg_mappings", clear	
	keep year pc8 prcaggr
	keep if strpos(prcaggr, "N")							// 380 obs
	replace prcaggr = substr(prcaggr, 1,14) if strlen(prcaggr) >25 // codes with additional B mappings, only use N here
	split prcaggr, p("[")
	ren prcaggr2 z
	split z, p("+")
	drop z prcaggr
	ren prcaggr1 z0											// N1, N2, N3 codes exist
	forvalues t = 1/3 {										// merge extensions to trunks
		keep if strlen(z`t')==2 | missing(z`t')				// drop irregular lengths of substrings
		egen X`t' = concat(z0 z`t')
	}	
	drop z*
	egen id = group(year pc8)
	reshape long X, i(id) j(x)
	drop if missing(X)
	keep year pc8 X 
	ren X optional
	drop if pc8 == optional									// aggregates
	order year pc8 optional
	compress
save "./output/N_lists", replace							// 864 obs.
export delimited using "./output/N_lists.tsv", replace delim("tab")

*-----------------------------------------------------
**# 7. Create disaggregates for aggregate letter codes
*-----------------------------------------------------
use "./tmp/pc_agg_mappings", clear
	drop blist
	keep if strpos(pc8, "E") | strpos(pc8, "Q") | ///
	strpos(pc8, "V") | strpos(pc8, "Z")						// 821 obs

// 1:1 mappings
	preserve												
		keep if !strpos(prcaggr, "+") & !strpos(prcaggr, "[") ///
		& !strpos(prcaggr, "(") & !strpos(prcaggr, "->") 
		replace prcaggr = prcaggr + "00" if strlen(prcaggr)==6
		ren prcaggr disagg
		save "./tmp/splits_1", replace						// 8 obs, all V codes
	restore		
		
// fully spelled out 8-digit codes (8d + 8d +...)
	preserve							 						
		keep if strpos(prcaggr, "+") & !strpos(prcaggr, "[") ///
		& !strpos(prcaggr, "(") & !strpos(prcaggr, "->") 
		split prcaggr, p("+")								
		drop prcaggr
		egen id = group(year pc8)
		reshape long prcaggr, i(id) j(x)
		drop if missing(prcaggr)							// aggregates
		drop id x
		replace prcaggr = prcaggr + "00" if strlen(prcaggr)==6
		ren prcaggr disagg
		save "./tmp/splits_2", replace						// 115 obs , all Z codes
	restore
	
// only "(" from 6 to 8 digit (majority of codes)
	preserve
		keep if strpos(prcaggr,"(") & !strpos(prcaggr,"[") & ///
		!strpos(prcaggr, "->") 		
		split prcaggr, p("(")								
		keep if strlen(prcaggr1)==6							
		ren prcaggr2 z
		split z, p("+")
		drop z prcaggr
		ren prcaggr1 z0
		qui desc, varlist									// flag number of splits
		loc lastvar: word `c(k)' of `r(varlist)'
		gen lastvar = "`lastvar'"
		destring lastvar, replace ignore(z)
		qui su lastvar
		loc endvar = r(max)
		forvalues t = 1/ `endvar' {							// merge extensions to trunks
			keep if strlen(z`t')==2 | missing(z`t')			// drop irregular lengths of substrings
			egen X`t' = concat(z0 z`t')
			replace X`t'="" if length(X`t')<7 | length(X`t')>8
		}	
		drop z*
		egen id = group(year pc8)
		reshape long X, i(id) j(x)
		drop if missing(X)
		keep year pc8 X
		ren X disagg
		save "./tmp/splits_3", replace						// 2,197 obs, E V Q and Z codes
		charlist pc8
	restore

// only "[" from 4 to 6- and 8-digit
	preserve													
		keep if strpos(prcaggr,"[") & !strpos(prcaggr,"(") & ///
		!strpos(prcaggr, "->") 
		split prcaggr, p("[")								
		ren prcaggr2 z
		split z, p("+")
		drop z prcaggr
		ren prcaggr1 z0
		qui desc, varlist									// flag number of splits
		loc lastvar: word `c(k)' of `r(varlist)'
		gen lastvar = "`lastvar'"
		destring lastvar, replace ignore(z)
		qui su lastvar
		loc endvar = r(max)
		forvalues t = 1/ `endvar' {	
			keep if strlen(z`t')==4 | missing(z`t')
			egen X`t' = concat(z0 z`t')
			replace X`t'="" if length(X`t')<7 | length(X`t')>8
		}	
		drop z*
		egen id = group(year pc8)
		reshape long X, i(id) j(x)
		drop if missing(X)
		keep year pc8 X
		ren X disagg
		save "./tmp/splits_4", replace						// 32 obs, all Q codes
	restore
	
// 4d with both "[" and "(" (e.g. 2410[21(21+22)]) 	
	preserve													
		keep if strpos(prcaggr,"[") & strpos(prcaggr,"(") & ///
		strpos(prcaggr,"+") & !strpos(prcaggr,"->")
		replace prcaggr = subinstr(prcaggr, "[", "", .)
		split prcaggr, p("(")
		drop if !missing(prcaggr3)							// drop complex splits do be done manually 
		ren prcaggr2 z
		split z, p("+")
		ren prcaggr1 z0
		drop z prcaggr*
		qui desc, varlist									// flag number of splits
		loc lastvar: word `c(k)' of `r(varlist)'
		gen lastvar = "`lastvar'"
		destring lastvar, replace ignore(z)
		qui su lastvar
		loc endvar = r(max)
		forvalues t = 1/ `endvar' {	
			keep if strlen(z`t')==2 | missing(z`t')
			egen X`t' = concat(z0 z`t')
			replace X`t'="" if length(X`t')<7 | length(X`t')>8
		}	
		drop z*
		egen id = group(year pc8)
		reshape long X, i(id) j(x)
		drop if missing(X)
		keep year pc8 X
		ren X disagg	
		save "./tmp/splits_5", replace						// 148 obs, all Z codes
	restore	

// collect all remaining codes to be cleaned manually	
	forvalues t = 1/5 {										// 65 obs
		merge 1:m year pc8 using "./tmp/splits_`t'"
		drop if _m==3
		drop _m 
		duplicates drop year pc8, force
	}
save "./tmp/manual_cleaning_needed", replace					// 62 obs, e.g. 2710[20(13->17+23->27+33+35+43->47+30(13->17+23->27+33+35+43->47+63->67+73->77+83+85+93->97

//////////////////////////////////////////////////////////
// CLEAN MANUALLY IN EXCEL and save as _hardcodes.dta		// no 2012 in here yet
// USE LIST OF ACTIVE PC8 CODES TO DEAL WITH "->" MAPPINGS
// FROM COMMUNICATION WITH RAMON PEOPLE.
// THEN CONTINUE HERE...
//////////////////////////////////////////////////////////

import excel "./hand/_hardcodes.xlsx", firstrow clear
	keep year pc8 disagg
	tostring disagg, replace
save "./tmp/_hardcodes", replace	

// dataset with all disaggregations (no B, N or T codes)
use "./tmp/splits_1", clear
forvalues t = 2/5 {
	append using "./tmp/splits_`t'"
	}
	append using "./tmp/_hardcodes"
save "./tmp/pc_disagg", replace									

// add disaggregation info for 2012 separately (not available in structure file)
import excel "./input/pc/_missing2012_Zcodes.xlsx", clear firstrow	// some Z codes missing in separate file.
	ren (prccode PrcAggr) (pc8 disagg)
	tostring disagg, replace
	gen year = 2012
save "./tmp/missing2012Zcodes", replace
import excel using "./input/pc/PrcAggr2012.xls", firstrow clear
	ren (Year MainCode SubCode) (year pc8 disagg)
	drop if pc8=="299900Z0"									// manual check: 299900Z0 up to Prodcom 2011, 299900Z1 from Prodcom 2012 onwards: https://ec.europa.eu/growth/tools-databases/kets-tools/sites/default/files/about/prodcom-list-technology-generation-and-exploitation.pdf
	drop AggrTyp
	append using "./tmp/missing2012Zcodes" 
	distinct pc8											// 35 letter codes that map to 118 8digit codes
save "./tmp/pc_prcaggr_2012", replace	

// Z --> E --> # mappings				
use "./tmp/pc_disagg", clear
	keep if strpos(pc8, "Z") & strpos(disagg, "E")
	ren (pc8 disagg) (temp pc8)
save "./tmp/z_to_e", replace
use "./tmp/pc_disagg", clear
	keep if strpos(pc8, "E")
	merge m:1 year pc8 using "./tmp/z_to_e", ///
	nogen keep(match) 										// m=1: no Z counterpart
	ren (temp disagg pc8) (pc8 temp disagg)
save "./tmp/z_to_e_to_num", replace

use "./tmp/pc_disagg", clear
	append using "./tmp/pc_prcaggr_2012" 								
	duplicates drop year pc8 disagg, force
	merge 1:m pc8 disagg year using  "./tmp/z_to_e_to_num"
	replace disagg = temp if _m==3
	drop temp _m
	label var disagg "numeric disaggregate E Q V Z codes"
	compress
save "./tmp/pc8_letter_aggregates", replace					// 3,138 obs, all EVQZ mappings
						
*---------------------------------------
**# 8. PC8 codes by year (numerics only)
*---------------------------------------
use "./output/pc8_byyear_incl_letters", clear
// drop codes that are reported alongside disagg or no mapping to 8d
	drop if strpos(pc8, "T")								// no 8d counterparts
	drop if strpos(pc8, "N")								// keep compulsory codes only
	drop if blist== "B"										// keep compulsory codes only
	
// attach mappings	
	drop prcaggr 
	merge 1:m year pc8 using "./tmp/pc8_letter_aggregates" // add splits, all disaggregates are  matched
	
	gen newpc = pc8 if _m==1								// pc8 to pc8 numeric, no mapping, all but 3,176 obs
	replace newpc = disagg if _m==3							// 3,138 obs. replace letter codes with numerics
	destring newpc, replace									// all aggregates are matched to numerics
	drop pc8 disagg blist _merge
	ren newpc pc8
	label var pc8 "PC8 code"
	bys year pc8: keep if _n==1								// 3,135 duplicates from mappings 
	order year pc8 unit_code unit_label
	compress
	bys pc8 year: assert _N == 1

save "./output/pc8_byyear", replace							// 59,012 obs. 
export delimited using "./output/pc8_byyear.tsv", replace delim("tab")
// year pc8 unit_code unit_label desc unit_code2 unit_label2 prodtype

clear
