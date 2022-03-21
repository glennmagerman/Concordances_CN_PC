* Version: Feb 2020.
* Author: Glenn Magerman.

/*______________________________________________________________________________
NOTES
- summary statistics of datasets as checks and balances.
______________________________________________________________________________*/

*-----------------
**# 1. CN8 by year
*-----------------
// variables: year cn8 desc suppl_unit
// this file is the benchmark for codes in other CN datasets.
use "./output/cn8_byyear", clear
	tab year										// 137,053 obs
	desc	
	summarize										
	tab year if missing(desc)						// no missing obs
	tab year if missing(suppl_unit)					// no missing obs
	
// comparison with Van Beveren (overlapping years)
use "./checks/Van Beveren/cn8_over_time/CN_2001", clear
	gen year = 2001
	forvalues t=2002/2010 {
		append using "./checks/Van Beveren/cn8_over_time/CN_`t'"
		replace year = `t' if missing(year)
	}
	ren group cn8
	merge 1:1 cn8 year using "./output/cn8_byyear" 
	drop if year > 2010
	br if _m!=3										// 1 code more in our list, keep.

*-------------------	
**# 2. CN8 over time	
*-------------------
// variables: year cn8 lcn8 lyear lcount count unchanged oto otm mto mtm desc suppl_unit
use "./output/cn8_concord", clear
	tab year										// 130,111
	desc
	summarize										
	tab year if missing(desc)						// no missing obs
	tab year if missing(suppl_unit)					// no missing obs
	
// comparison with list of CN8 codes - perfect
use "./output/cn8_concord", clear
	merge m:1 cn8 year using "./output/cn8_byyear"
	drop if year==2001								// only shows up as lyear
	br if _m!=3										// 0 obs. ok

use "./output/cn8_concord", clear
	drop cn8 year
	ren (lcn8 lyear) (cn8 year)
	merge m:1 cn8 year using "./output/cn8_byyear"
	drop if year == 2014							// only shows up as year
	br if _m!=3										// 0 obs. ok
		
*-----------------	
**# 3. PC8 by year	
*-----------------
* 3.1 pc8_byyear
// variables: year pc8 unit_code unit_label desc unit_code2 unit_label2 prodtype
// this file is the benchmark for codes in other CN datasets.
use "./output/pc8_byyear", clear
	tab year										// 59,012 obs
	desc
	summarize	
	
// comparison with Van Beveren (overlapping years) - perfect
use "./checks/Van Beveren/pc8_over_time/PC_2001", clear
	gen year = 2001
	forvalues t=2002/2010 {
		append using  "./checks/Van Beveren/pc8_over_time/PC_`t'"
		replace year = `t' if missing(year)
	}
	ren pc pc8
	destring pc8, replace
	merge 1:1 pc8 year using "./output/pc8_byyear" 
	drop if year > 2010
	br if _m!=3										// 0 obs. ok


* 3.2 pc8_byyear_incl_letters
// variables: year pc8 desc unit_code unit_label unit_code2 unit_label2 prodtype blist prcaggr
use "./output/pc8_byyear_incl_letters", clear
	tab year										// 63,341 obs
	desc
	summarize	
	charlist pc8									// ENQTVZ codes exist
	
// optional codes									// total 3,476 obs
	su if strpos(pc8, "N") 							// 912 obs
	su if strpos(pc8, "T") 							// 300 obs
	su if blist == "B"								// 2,264 obs
	
// letter aggregates								// total 856 obs
	br if strpos(pc8, "E")							// 8 obs
	br if strpos(pc8, "Q")							// 268 obs
	br if strpos(pc8, "V")							// 38 obs
	br if strpos(pc8, "Z")							// 542 obs
	
// mandatory numeric codes							// total 59,009 obs
	drop if blist== "B"
	foreach x in N T E Q V Z {
		drop if strpos(pc8, "`x'")
	}
	
*-------------------	
**# 4. PC8 over time	
*-------------------
use "./output/pc8_concord", clear
	tab year										// 55,843 obs
	desc	
	summarize										
	
// comparison with list of PC8 codes
use "./output/pc8_concord", clear
	merge m:1 pc8 year using "./output/pc8_byyear"
	drop if year==2001
	br if _m!=3	& !missing(pc8)						// 0 obs. ok
	
*--------------
**# 5. CN to PC
*--------------
// variables: year cn8 pc8 unit_label unit_label2 suppl_unit same_unit same_2nd_unit cn_count pc_count oto otm mto mtm
use "./output/cn8_pc8_concord", clear					// 157,504 obs	
	tab year
	desc
	summarize 
	
// check cn to list cn	
	bys cn8 year: keep if _n==1
	merge 1:m cn8 year using "./output/cn8_byyear", keepusing(cn8)
	br if _m==1										// 0 obs. ok
													// _m==2: cn not mapped to pc
	
// check pc to list pc
use "./output/cn8_pc8_concord", clear			
	bys pc8 year: keep if _n==1
	merge m:1 pc8 year using "./output/pc8_byyear", keepusing(pc8)
	br if _m==1										// 0 obs. ok
				
clear
