* Project: Price updating with production networks
* Author: Glenn Magerman
* First version: April, 2018.
* This version: February, 2020.
* Stata Version 17

/*______________________________________________________________________________

Notes
- Users with B- or N-list optional PC codes first have to aggregate these to 
  mandatory codes before applying concordances.
- Not all CN codes map to PC codes and vice versa 
  (e.g. antiques in CN are not in Prodcom production, and industrial services
  or fuels are not in CN).
  
______________________________________________________________________________*/


*-------------------------------------
**# 1. import CN to PC correspondences
*-------------------------------------
// import corrections from Eurostat (2002-2003 codes)
import excel "./input/cn_pc/corrected_codes_Eurostat.xlsx", ///
sheet("missing cn8 codes") firstrow clear
	keep year pc8 cn8 corrected_CN
	ren corrected_CN cn8_corr
	cap replace cn8_corr = subinstr(cn8_corr, ".","",.)
	cap replace cn8_corr = subinstr(cn8_corr, " ","",.)
	destring cn8_corr, replace
save "./tmp/corrections_cn_pc", replace	
	
// import CN to PC correspondences (downloads RAMON website)
forvalues t = 2001/2014 {
import excel using "./input/cn_pc/cn_pc_1993_2014.xls", ///
	sheet("`t'") firstrow clear
	cap replace cn8 = subinstr(cn8, ".","",.)
	cap replace cn8 = subinstr(cn8, " ","",.)
	cap replace pc8 = subinstr(pc8, ".","",.)	
	cap destring year cn8, replace						
	drop if missing(cn8) | missing(pc8)
	keep year pc8 cn8
	do "./src/A. product_mistakes.do"					// E codes are sometimes misread in excel
save "./tmp/cn_pc_`t'", replace
}

// collect years 
use "./tmp/cn_pc_2001", clear
	forvalues t = 2002/2014 {
		append using "./tmp/cn_pc_`t'"
	}
	bys cn8 pc8 year: keep if _n == 1 					// still 3 duplicate reportings in excel sheets (all in 2003)
save "./tmp/cn_pc_panel", replace						// still includes letters, but no B or N list codes	

*-------------------------------------	
**# 2. Correspondence CN to PC by year (only numerics)	
*-------------------------------------
use "./tmp/cn_pc_panel", clear
	drop if strpos(pc8, "T")
	
// merge with PC letter aggregates to get 8d numeric mappings
	joinby year pc8 using "./tmp/pc8_letter_aggregates", ///
	unmatched(master)
	gen newpc = pc8 if _m==1 							// numeric codes
	replace newpc = disagg if _m==3						// split letter aggregates
	destring newpc, replace
	drop pc8 disagg _m
	ren newpc pc8
	drop if missing(pc8)
	bys year cn8 pc8: keep if _n==1						// drop overlaps from joinby
	
// corrections Eurostat, almost all 2002, 2 codes in 2003.
	merge 1:m pc8 cn8 year using "./tmp/corrections_cn_pc"
	replace cn8 = cn8_corr if _m==3						
	drop _m cn8_corr
	replace cn8 = 29333300 if cn8==29333399				// CONFIRM WITH EUROSTAT
	bys year cn8 pc8: keep if _n==1						// drop overlaps from corrections
	
// keep only codes in official cn8 and pc8 listing	
	merge m:1 cn8 year using "./output/cn8_byyear", ///
	nogen keep(match) keepusing(cn8)	
	merge m:1 pc8 year using "./output/pc8_byyear", ///
	nogen keep(match) keepusing(pc8)	
	
// merge with pc8 units	
	merge m:1 pc8 year using "./output/pc8_byyear", keepusing(unit_label*)
	br if _m==1
	drop if _m==2
	drop _m
	
// merge with cn8 units	
	merge m:1 cn8 year using "./output/cn8_byyear", keepusing(suppl_unit)
	br if _m==1
	drop if _m==2
	drop _m
	
// flag if same volume units in PC and CN
	gen same_unit = (unit_label==suppl_unit) 
	replace same_unit = 1 if unit_label == "kg" & suppl_unit=="-"
	replace same_unit = 1 if unit_label == "kg act. subst." & suppl_unit=="-"
	gen same_2nd_unit = (unit_label2==suppl_unit)
	br if same_unit==0 & same_2nd_unit==0

	table unit_label suppl_unit if same_unit==0 & same_2nd_unit==0
	// most are missing suppl_unit in cn but existing unit in pc
	// ASK RAMON
	
	sort year cn8 pc8
	compress
save "./tmp/cn_pc_byyear", replace

*-----------------------
**# 3. Mappings CN to PC 
*-----------------------
use "./tmp/cn_pc_byyear", clear							
	bys year pc8: egen cn_count = count(cn8)
	bys year cn8: egen pc_count= count(pc8)

	gen oto = (cn_count == 1 & pc_count == 1)				// identify 1:1, 1:m, m:1, m:m 
	gen otm = (cn_count == 1 & pc_count > 1)					
	gen mto = (cn_count > 1 & pc_count == 1)
	gen mtm = (cn_count > 1 & pc_count > 1)	
	assert oto + otm + mto + mtm == 1						// disjoint and complete

	bys cn8 year: egen LOTO = max(oto)						// filter out mappings part of m:m mappings	in CN
	bys cn8 year: egen LMTO = max(mto)					
	bys cn8 year: egen LOTM = max(otm)	
	bys cn8 year: egen LMTM = max(mtm)
	
	bys pc8 year: egen OTO = max(oto)						// filter out mappings part of m:m mappings	in PC
	bys pc8 year: egen MTO = max(mto)					
	bys pc8 year: egen OTM = max(otm)	
	bys pc8 year: egen MTM = max(mtm)
	
	foreach x in oto mto otm mtm { 							// allocate to m:m	
		replace `x' = 0 if MTM == 1
		replace `x' = 0 if LMTM == 1
	}	
	replace mtm = 1 if oto == 0 & otm == 0 & mto == 0	
	drop *OTO *MTO *OTM *MTM
	assert oto + otm + mto + mtm == 1
	
	label var pc8 "PC 8-digit product"
	label var cn8 "CN 8-digit product"
	label var cn_count "cn8 obs per pc8"
	label var pc_count "pc8 obs per cn8"
	label var same_unit "(0/1) if pc in same volume unit as cn"
	label var same_2nd_unit "(0/1) if pc 2nd unit in same volume unit as cn"
	label var oto "one-to-one"
	label var otm "one-to-many"
	label var mto "many-to-one"
	label var mtm "many-to-many"	
	compress
	bys cn8 pc8 year: assert _N == 1

save "./output/cn8_pc8_concord", replace	
export delimited using "./output/cn8_pc8_concord.tsv", replace delim("tab")
	
clear
