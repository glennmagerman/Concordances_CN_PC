* Project: Price updating with production networks
* Author: Glenn Magerman
* First version: April, 2018.
* This version: February, 2020.
* Stata Version 17

/*______________________________________________________________________________

Notes
- There is no entry/exit of products in the CN8 codes, so no dropped codes etc.
  Every code maps to another code in the next year.
______________________________________________________________________________*/

*----------------------------------
**# 1. cn8 correspondences t-1 to t							
*----------------------------------
forvalues t = 2002/2014 {
	local t_1 = `t'- 1 
	import excel "./input/cn/CN_`t'-CN_`t_1'.xlsx", clear		// only changes in codes
	drop B
	ren (A C) (cn8 lcn8)
	gen year = `t'
	gen lyear = `t_1'
	replace cn8 = subinstr(cn8, ".","",.)
	replace cn8 = subinstr(cn8, " ","",.)
	replace lcn8 = subinstr(lcn8, ".","",.)
	replace lcn8 = subinstr(lcn8, " ","",.)
	destring cn8 lcn8, replace force						
save "./tmp/cn_`t'_`t_1'", replace	
}

// collect years
use "./tmp/cn_2002_2001", clear
	forvalues t = 2003/2014 {
		local t_1 = `t'- 1 
		append using "./tmp/cn_`t'_`t_1'"
	}

// keep only codes in official cn8 listing	
	merge m:1 cn8 year using "./output/cn8_byyear", ///
	nogen keep(match) keepusing(cn8)						// all matched, ok
	ren (cn8 year lcn8 lyear) (tmp_cn8 tmp_year cn8 year)
	merge m:1 cn8 year using "./output/cn8_byyear", ///
	nogen keep(match) keepusing(cn8)						// all matched, ok
	ren (tmp_cn8 tmp_year cn8 year) (cn8 year lcn8 lyear) 
save "./tmp/cn8_conc", replace								// year cn8 lyear lcn8

*--------------
**# 2. mappings 
*--------------
// concordance dataset (only changes)
use "./tmp/cn8_conc", clear 								
	bys year cn8: egen lcount = count(lcn8)					// count obs per cn8 in t-1 for cn8 in t	
	bys lyear lcn8: egen count = count(cn8)					// count obs per cn8 in t for cn8 in t-1	

	gen oto = (lcount == 1 & count == 1)					// identify 1:1, 1:m, m:1, m:m 
	gen otm = (lcount == 1 & count > 1)					
	gen mto = (lcount > 1 & count == 1)
	gen mtm = (lcount > 1 & count > 1)	
	assert oto + otm + mto + mtm == 1						// disjoint and complete

	bys lcn8 lyear: egen LOTO = max(oto)					// filter out mappings part of m:m mappings	in t-1
	bys lcn8 lyear: egen LMTO = max(mto)					
	bys lcn8 lyear: egen LOTM = max(otm)	
	bys lcn8 lyear: egen LMTM = max(mtm)
	
	bys cn8 year: egen OTO = max(oto)						// filter out mappings part of m:m mappings	in t
	bys cn8 year: egen MTO = max(mto)					
	bys cn8 year: egen OTM = max(otm)	
	bys cn8 year: egen MTM = max(mtm)
	
	foreach x in oto mto otm mtm { 							// allocate to m:m	
		replace `x' = 0 if MTM == 1
		replace `x' = 0 if LMTM == 1
	}	
	replace mtm = 1 if oto == 0 & otm == 0 & mto == 0	
	drop *OTO *MTO *OTM *MTM
	assert oto + otm + mto + mtm == 1
	
// add unchanged codes	
// do after mappings, since same code in t-1 and t can still be part of non-singular mapping.
	merge m:1 cn8 year using "./output/cn8_byyear", nogen		
	drop if year == 2001									// no mappings available
	foreach x in count lcount {
		replace `x' = 1 if missing(`x')
	}
	
	replace lcn8 = cn8 if missing(lcn8) 					// same code as last year 	
	replace lyear = year-1 if missing(lyear) 	
	foreach x in oto otm mto mtm {
		replace `x' = 0 if missing(`x')
	}
	
	gen sum = oto + otm + mto + mtm
	gen unchanged = (sum  == 0)								
	drop sum
	assert oto + otm + mto + mtm + unchanged == 1
	
// wrap up	
	label var cn8 "cn8 code in t"
	label var lcn8 "cn8 code in t-1"
	label var year "year t"
	label var lyear "year t-1"
	label var count "obs per cn8 in t for cn8 in t-1"
	label var lcount "obs per cn8 in t-1 for cn8 in t"
	label var unchanged "same code in t-1 and t"
	label var oto "one-to-one"
	label var otm "one-to-many"
	label var mto "many-to-one"
	label var mtm "many-to-many"
	compress
	
	bys cn8 lcn8 year: assert _N == 1
	sort year cn8 lcn8
	order year cn8 lcn8 lyear lcount count unchanged oto otm mto mtm
save "./output/cn8_concord", replace
export delimited using "./output/cn8_concord.tsv", replace delim("tab")

// vars: year cn8 lcn8 lyear lcount count unchanged oto otm mto mtm desc suppl_unit

su

/*
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
        year |    130,111    2007.831    3.749549       2002       2014
         cn8 |    130,111    5.06e+07    2.94e+07    1011010   9.71e+07
        lcn8 |    130,111    5.06e+07    2.94e+07    1011010   9.71e+07
       lyear |    130,111    2006.831    3.749549       2001       2013
      lcount |    130,111    1.264482    3.175139          1         70
-------------+---------------------------------------------------------
       count |    130,111    1.092875    .8193799          1         19
   unchanged |    130,111    .9385755    .2401082          0          1
         oto |    130,111    .0083313    .0908955          0          1
         otm |    130,111    .0066789    .0814516          0          1
         mto |    130,111    .0189607    .1363868          0          1
-------------+---------------------------------------------------------
         mtm |    130,111    .0274535    .1634013          0          1
        desc |          0
  suppl_unit |          0
*/

clear
