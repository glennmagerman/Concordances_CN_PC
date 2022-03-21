* Project: Price updating with production networks
* Author: Glenn Magerman
* First version: April, 2018.
* This version: February, 2020.
* Stata Version 17

*--------------------------------------
**# 1. Import cn8 codes and description
*--------------------------------------
// import suppl unit for 2003 and 2013 separately
foreach t in 2003 2013 {
import excel using "./input/cn/CN_`t'_su.xls", firstrow clear
	ren su suppl_unit
	replace cn8 = subinstr(cn8, ".","",.)
	replace cn8 = subinstr(cn8, " ","",.)
	destring cn8, replace force						// non-numerics: headers or spaces
	drop if missing(cn8) | cn8 < 1000000			// drop headers/aggr. codes
save "./tmp/cn_`t'_su", replace						// cn8, suppl_unit
} 

// import cn8 codes, desc and suppl units for all years	
forvalues t = 2001/2014 {		
	if `t' <= 2006 | `t' == 2014 {
		import delimited using "./input/cn/CN_`t'.csv", delim(",") clear
		ren (v5 description supplement) (cn8 desc suppl_unit)
		keep cn8 desc suppl_unit
	}
	else {
		import excel using "./input/cn/CN_`t'.xls", firstrow clear	
		cap ren DESC_EN EN
		cap ren DM_EN EN
		cap ren DM EN
		ren (CN EN SU) (cn8 desc suppl_unit)
		keep cn8 desc suppl_unit
	}
	cap replace cn8 = subinstr(cn8, ".","",.)
	cap replace cn8 = subinstr(cn8, " ","",.)
	destring cn8, replace force						// non-numerics: headers or spaces
	drop if missing(cn8) | cn8 < 1000000			// drop aggregated codes
	if `t'== 2003 | `t'== 2013 {					// merge other years with 2003 and 2013
		cap drop suppl_unit
		merge 1:1 cn8 using "./tmp/cn_`t'_su", nogen keep(match master)
	}
	charlist desc
	cap replace desc = subinstr(desc, "- ", "",.)	// drop hierarchical dashes from descriptions
	cap replace desc = subinstr(desc, "-", "",.)	
	cap replace desc = subinstr(desc, "--", "",.)
	cap replace desc = subinstr(desc, " - - ", "",.)
	cap replace desc = subinstr(desc, " - - - ", "",.)
	gen year = `t'
	order year cn8
save "./tmp/cn_`t'", replace						// year, cn8, desc, suppl_unit
}

*-----------------------
**# 2. cn8 codes by year 
*-----------------------
// create stacked dataset
use "./tmp/cn_2001", clear
	forvalues t == 2002/2014 {
		append using "./tmp/cn_`t'"
	}
	
// clean units
	replace suppl = "-" if missing(suppl)	
	ren suppl x
	do "./src/A. unit_labels.do"					// clean labels of units
	ren x suppl_unit

// wrap up	
	label var year "year t"
	label var cn8 "CN 8-digit product"
	label var desc "description of code"
	label var suppl "supplementary unit"
	compress
	
	bys cn8 year: assert _N == 1
save "./output/cn8_byyear", replace					
export delimited using "./output/cn8_byyear.tsv", replace delim("tab")
// year, cn8, desc, suppl_unit

su 
/*
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
        year |    137,053    2007.345    4.038375       2001       2014
         cn8 |    137,053    5.06e+07    2.95e+07    1011010   9.71e+07
        desc |          0
  suppl_unit |          0
*/

clear
