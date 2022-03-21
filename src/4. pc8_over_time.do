* Project: Price updating with production networks
* Author: Glenn Magerman
* First version: April, 2018.
* This version: Marh, 2022.
* Stata Version 17

/*______________________________________________________________________________

Notes
- Users with B- or N-list optional codes first have to aggregate our numeric  
  PC8 codes to compulsory codes before applying concordances. Mappings are 
  provided in the B_lists and N_list files.
  
- Contrary to CN8, in PC8 there is entry and exit of codes that do not have 
  correspondences. 
______________________________________________________________________________*/

*-----------------------------------------
**# 1. Import pc8 correspondences t-1 to t 
*-----------------------------------------
// import tables t-1 to t (include optional and aggregate codes)
forvalues t = 2002/2014 {									
	local t_1 = `t'-1
	
// mappings for 2001 to 2009 are in one single excel file
// sheets contain only changes in codes, not unchanged codes!	
	if `t' <= 2009 {
		import excel "./input/pc/pc_conc_2009_2001.xlsx", ///  // contains all mappings between 2001 and 2009
		firstrow clear sheet("`t' - `t_1'")
	}
	
// other years are in format t-1 to t 
// these sheets contain also non-changing codes --> need to be dropped below	
	else {
		import excel "./input/pc/pc_conc_`t'_`t_1'.xlsx", firstrow clear
	}
	
// harmonize variable names	
	cap ren (Code`t' Code`t_1') (pc8 lpc8)
	cap ren (PRCcode PrevPRCcode) (pc8 lpc8)
	cap ren(PRC`t' PRC`t_1') (pc8 lpc8)
	cap ren(A B) (pc8 lpc8)
	gen year = `t'
	gen lyear = `t_1'
	keep pc8 lpc8 year lyear
	cap tostring pc8 lpc8, replace							// in string format to accomodate letter codes 
	
// drop B and N list optional codes
	drop if strpos(pc8, "N") | strpos(lpc8, "N") 			// in t 
	ren pc8 optional
	merge m:1 year optional using "./output/B_lists", ///
	nogen keep(master) keepusing(optional)
	ren optional pc8
	
	ren (lpc8 lyear year) (optional year temp)				// in t-1 
	merge m:1 year optional using "./output/B_lists", ///
	nogen keep(master) keepusing(optional)
	ren (optional year temp) (lpc8 lyear year) 
	
// cleaning	of pc8 and lpc8 strings
	forvalues i = 1/11 {									// clear some text fields 2007-2006 (checked in raw excel files)
		replace pc8 = subinstr(pc8, "[`i']","", .)		
		replace lpc8 = subinstr(lpc8, "[`i']","", .)	
	}
	do "./src/A. product_mistakes.do"						// E codes are sometimes misread in excel as scientific notation
	ren (pc8 lpc8) (tmp pc8)
	do "./src/A. product_mistakes.do"						
	ren (tmp pc8) (pc8 lpc8)
	foreach x in pc8 lpc8 {
		replace `x' ="" if `x'== "---" | `x'== "----" | `x'== "-----"
		replace `x' = subinstr(`x', ".","",.)		
		drop if strlen(`x') > 15							// texts
		replace `x' = "0" + `x' if strlen(`x') == 7			// add leading zeroes	
	}
	drop if missing(pc8) & missing(lpc8)
	
// drop non-changing codes if not part of m:n mapping 
// extensive, since pc8 = lpc8 is not enough to identfy non-changing codes
// they can be part of m:n mappings, which we first completely characterize 
	gen entry = (missing(lpc8))
	gen exit = (missing(pc8))
	bys year pc8: egen lcount = count(lpc8) if entry == 0 & exit == 0 // count obs per pc8 in t-1 for pc8 in t	
	bys lyear lpc8: egen count = count(pc8)	if entry == 0 & exit == 0 // count obs per pc8 in t for pc8 in t-1	
	// keep lcount and count missing for entry/exit (instead of 0)
	
	gen oto = (lcount == 1 & count == 1)		
	gen otm = (lcount == 1 & count > 1 & !missing(count))					
	gen mto = (lcount > 1 & count == 1 & !missing(lcount))
	gen mtm = (lcount > 1 & count > 1 & !missing(lcount) & !missing(count))	
	assert entry + exit + oto + otm + mto + mtm == 1		// disjoint and complete
	
	bys lpc8 lyear: egen LOTO = max(oto)					// filter out mappings part of m:m mappings	in t-1
	bys lpc8 lyear: egen LMTO = max(mto)						
	bys lpc8 lyear: egen LOTM = max(otm)	
	bys lpc8 lyear: egen LMTM = max(mtm)
	
	bys pc8 year: egen OTO = max(oto)						// filter out mappings part of m:m mappings	in t
	bys pc8 year: egen MTO = max(mto)					
	bys pc8 year: egen OTM = max(otm)	
	bys pc8 year: egen MTM = max(mtm)
	
	foreach x in oto mto otm mtm { 							// allocate to m:m	
		replace `x' = 0 if MTM == 1
		replace `x' = 0 if LMTM == 1
	}	
	replace mtm = 1 if oto == 0 & otm == 0 & mto == 0 & entry==0 & exit == 0	
	drop if oto == 1 & lpc8 == pc8							// drop unchanged codes 
	drop entry exit lcount count oto otm mto mtm OTO MTO OTM MTM LOTO LMTO LOTM LMTM 
	
// drop some codes that are duplicate in the excel sheets, but are mappings, not entry 
// e.g. sheet 2008-2007 has code 18.11.10.00 both as mapping, and as "entry", but with text discussing it is a mapping...
	bys year pc8: gen nobs = _N
	keep if nobs == 1 | (nobs > 1 & !missing(lpc8))
	drop nobs 
save "./tmp/pc_conc_`t'_`t_1'", replace						// contains letter codes
}	

// collect years
use "./tmp/pc_conc_2002_2001", clear
	forvalues t = 2003/2014 {
		local t_1 = `t'-1
		append using "./tmp/pc_conc_`t'_`t_1'"
	}	

// export T list mappings separately
	preserve 
		keep if strpos(pc8, "T") | strpos(lpc8, "T") 
		drop if lpc8==pc8
		compress
		save "./output/T_lists_over_time", replace
		export delimited using "./output/T_lists_over_time.tsv", replace delim("tab")
	restore	
	drop if strpos(pc8, "T") | strpos(lpc8, "T")
	charlist pc8 
	charlist lpc8 
save "./tmp/pc_conc_panel", replace							// still contains letter codes

*--------------------------------------------------
**# 2. Replace letter aggregates with disaggregates			/ only changing codes 
*--------------------------------------------------
use "./tmp/pc_conc_panel", clear
// in year t
	joinby year pc8 using "./tmp/pc8_letter_aggregates", /// // all pairwise combinations, cannot do merge since m:n mappings exist
	unmatched(master) 										// keep the data from master if not matched in using dataset 
	tab _m													// 185 aggregates to replace 
	gen newpc = pc8 if _m==1								// numeric only  
	replace newpc = disagg if _m==3							// letter mappings
	drop if strpos(pc8, "E") | strpos(pc8, "Q") | ///		// drop letter aggregates 
	strpos(pc8, "V") | strpos(pc8, "Z")	
	destring newpc, replace																	
	br if missing(newpc)									// all exiting pc8, ok (no aggregates remaining in newpc)
	drop pc8 disagg _m
	ren newpc pc8
	
// in year t-1	
	replace year = year -1
	ren (lpc8 pc8) (pc8 fpc8)
	joinby year pc8 using "./tmp/pc8_letter_aggregates", ///
	unmatched(master) 
	tab _m													// 631 aggregates to map
	gen newpc = pc8 if _m==1								// numeric only
	replace newpc = disagg if _m==3							// mappings
	drop if strpos(pc8, "E") | strpos(pc8, "Q") | ///		// drop letter aggregates 
	strpos(pc8, "V") | strpos(pc8, "Z")	
	destring newpc, replace 								
	br if missing(newpc)									// 42 missing: all entry pc8, ok (no aggregates remaining in newpc)
	drop pc8 disagg _m
	ren (newpc fpc8) (lpc8 pc8)
	replace year = year +1
	
// drop duplicates from joinby
	duplicates drop pc8 lpc8 year lyear, force				// 263 obs
	
// keep only codes in official pc8 listing	
	merge m:1 pc8 year using "./output/pc8_byyear", keepusing(pc8)	
	keep if _m==3 | missing(pc8)							// only entry/exit of goods, no false codes 
	drop _m
	
	ren (pc8 year lpc8 lyear) (tmp_pc8 tmp_year pc8 year)
	merge m:1 pc8 year using "./output/pc8_byyear", keepusing(pc8)	
	keep if _m==3 | missing(pc8)		
	drop _m
	ren (tmp_pc8 tmp_year pc8 year) (pc8 year lpc8 lyear) 
save "./tmp/pc8_conc", replace								
	
*--------------
**# 3. mappings 
*--------------
// concordance dataset (only changes)
use "./tmp/pc8_conc", clear 	
	gen entry = (missing(lpc8))								// entry = 1 if missing in t-1 and present in t 						
	gen exit = (missing(pc8))								// exit = 1 if present in t-1 and missing in t
	
	bys year pc8: egen lcount = count(lpc8) if entry == 0 & exit == 0 // count obs per pc8 in t-1 for pc8 in t	
	bys lyear lpc8: egen count = count(pc8)	if entry == 0 & exit == 0 // count obs per pc8 in t for pc8 in t-1	
	// keep lcount and count missing for entry/exit (instead of 0)
	
	foreach x in count lcount {								// 1:1 mapping 
		replace `x' = 0 if missing(`x')
	}
	
	gen oto = (lcount == 1 & count == 1)					// identify 1:1, 1:m, m:1, m:m 
	gen otm = (lcount == 1 & count > 1)					
	gen mto = (lcount > 1 & count == 1)
	gen mtm = (lcount > 1 & count > 1)	
	assert entry + exit + oto + otm + mto + mtm == 1		// disjoint and complete
	
	bys lpc8 lyear: egen LOTO = max(oto)					// filter out mappings part of m:m mappings	in t-1
	bys lpc8 lyear: egen LMTO = max(mto)						
	bys lpc8 lyear: egen LOTM = max(otm)	
	bys lpc8 lyear: egen LMTM = max(mtm)
	
	bys pc8 year: egen OTO = max(oto)						// filter out mappings part of m:m mappings	in t
	bys pc8 year: egen MTO = max(mto)					
	bys pc8 year: egen OTM = max(otm)	
	bys pc8 year: egen MTM = max(mtm)
	
	foreach x in oto mto otm mtm { 							// allocate to m:m	
		replace `x' = 0 if MTM == 1
		replace `x' = 0 if LMTM == 1
	}	
	
	replace mtm = 1 if oto == 0 & otm == 0 & mto == 0 & entry == 0 & exit == 0	
	drop *OTO *MTO *OTM *MTM
	assert entry + exit + oto + otm + mto + mtm == 1	
	
// add unchanged codes	
// need to do after mappings, since same code in t-1 and t can still be part of non-singular mapping.
	merge m:1 pc8 year using "./output/pc8_byyear", ///
	keepusing(pc8)											// m=1: exiting, m=2: unchanged
	drop if year == 2001									// no mappings available
	foreach x in count lcount {								// 1:1 mapping 
		replace `x' = 1 if _m == 2
	}
	replace lpc8 = pc8 if _m == 2 							// same code as last year 
	replace lyear = year-1 if _m == 2
	foreach x in oto otm mto mtm entry exit {				// no changes
		replace `x' = 0 if _m == 2
	}
	
	drop _m
	gen sum = entry + exit + oto + otm + mto + mtm
	gen unchanged = (sum  == 0)
	drop sum
	assert oto + otm + mto + mtm + entry + exit + unchanged == 1
	
// wrap up	
	label var pc8 "pc8 code in t"
	label var lpc8 "pc8 code in t-1"
	label var year "year t"
	label var lyear "year t-1"
	label var count "obs per pc8 in t for pc8 in t-1"
	label var lcount "obs per pc8 in t-1 for pc8 in t"
	label var unchanged "unchanged"	
	label var oto "one-to-one"
	label var otm "one-to-many"
	label var mto "many-to-one"
	label var mtm "many-to-many"
	label var entry "new product in t"
	label var exit "exiting product in t-1"
	compress
	sort year pc8 lpc8
	bys pc8 lpc8 year: assert _N == 1
save "./output/pc8_concord", replace	
export delimited using "./output/pc8_concord.tsv", replace delim("tab")

clear
