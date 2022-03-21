* Project: Price updating with production networks
* Author: Glenn Magerman
* First version: April, 2018.
* This version: February, 2020.
* Stata Version 17

/*______________________________________________________________________________
Notes
- some 1:m and m:1 mappings are part of m:m mappings. see example at end.
______________________________________________________________________________*/

*------------------
**# 1. mappings CN8 (Table 2)
*------------------
// nprod first year	(separate since no correspondences)
use "./output/cn8_byyear", clear
	tab year if year == 2001
	
// total nprod, unchanged, singular and non-singular
use "./output/cn8_concord", clear
	bys cn8 year: keep if _n == 1
	gen nonsing = (oto == 0 & unchanged == 0)	
	bys year: egen total = count(cn8)
	gcollapse (first) total (sum) unchanged oto nonsing, by(year)
save "./tmp/cn8_part1", replace	
	
// type of non-singular mappings in t-1
use "./output/cn8_concord", clear
	drop if unchanged == 1 | oto == 1
	bys lcn8 lyear: keep if _n==1
	su lcount if otm == 1, d
	su lcount if mto == 1, d
	su lcount if mtm == 1, d
	gcollapse (sum) otm mto mtm, by(lyear)
	ren * *_t_1
	ren lyear_t_1 year 
	replace year = year + 1
	drop if year == 2001
save "./tmp/cn8_part2", replace		
	
// type of non-singular mappings in t
use "./output/cn8_concord", clear
	drop if unchanged == 1 | oto == 1
	bys cn8 year: keep if _n == 1	
	su count if otm == 1, d
	su count if mtm == 1, d
	gcollapse (sum) otm mto mtm, by(year)

// combine to table 
	merge 1:1 year using "./tmp/cn8_part1", nogen
	merge 1:1 year using "./tmp/cn8_part2", nogen
	order year total unchanged oto nonsing otm_t_1 otm mto_t_1 mto mtm_t_1 mtm  

*-----------------------------	
**# 2. CN8 supplementary units (Table 3)
*-----------------------------	
// tab units
use "./output/cn8_concord", clear
	bys cn8 year: keep if _n == 1
	distinct suppl
	tab suppl_unit

// unchanged codes, change un units?
use "./output/cn8_concord", clear
	bys cn8 year: keep if _n == 1
	xtset cn8 year
	sort cn8 year
	encode suppl_unit, gen(su)
	tsspell cn8
	bys cn8: gen flag = (su != l.su & _seq!=1)
	bys cn8: egen F = max(flag)
	keep if F >= 1 
	bys cn8 suppl: keep if _n==1
	distinct cn8									// 95 products
	gen su1 = (suppl=="-")
	bys cn8: egen SU1 = max(su1) 
	distinct cn8 if SU1==1							// 79 products from - to smt. or vice versa
	br if SU1!=1									// 16 products smt to smt: m2 to m3, GT to p/st

*------------------
**# 3. mappings PC8 (Table 5)
*------------------
// nprod first year	separately (no mappings)
use "./output/pc8_byyear", clear
	tab year if year == 2001
	
// total nprod, entry, unchanged, singular and non-singular
use "./output/pc8_concord", clear
	bys pc8 year: keep if _n == 1
	gen nonsing = (oto == 0 & unchanged == 0 & entry==0 & exit == 0)	
	bys year: egen total = count(pc8)
	gcollapse (first) total (sum) unchanged entry exit oto nonsing, by(year)
save "./tmp/pc8_part1", replace		

// exit 
use "./output/pc8_concord", clear
	keep if exit == 1
	gcollapse (sum) exit, by(year)
save "./tmp/pc8_part2", replace			

// type of non-singular mappings in t-1
use "./output/pc8_concord", clear
	drop if unchanged == 1 | oto == 1
	bys lpc8 lyear: keep if _n==1
	su lcount if otm == 1, d
	su lcount if mto == 1, d
	su lcount if mtm == 1, d
	gcollapse (sum) otm mto mtm, by(lyear)
	ren * *_t_1
	ren lyear_t_1 year 
	replace year = year + 1
	drop if year == 2001
save "./tmp/pc8_part3", replace		
	
// type of non-singular mappings in t
use "./output/pc8_concord", clear
	drop if unchanged == 1 | oto == 1 
	bys pc8 year: keep if _n == 1	
	su count if otm == 1, d
	su count if mtm == 1, d
	gcollapse (sum) otm mto mtm, by(year)

// combine to table 
	merge 1:1 year using "./tmp/pc8_part1", nogen
	merge 1:1 year using "./tmp/pc8_part2", nogen
	merge 1:1 year using "./tmp/pc8_part3", nogen
	order year total unchanged entry exit oto nonsing otm_t_1 otm mto_t_1 mto mtm_t_1 mtm  

*-------------------------	
**# 4. PC8 units (Table 6)	
*-------------------------
// tab units
use "./output/pc8_byyear", clear
	tab unit_label
	distinct unit_label	
	
*-----------------------
**# 5. mappings CN to PC
*-----------------------
// number of CN8 products with mappings 
use "./output/cn8_pc8_concord", clear
	bys cn8 year: keep if _n == 1
	tab year

//mappings, singular and non-singular mappings
use "./output/cn8_pc8_concord", clear
	bys cn8 year: keep if _n == 1
	gen nonsing = (oto == 0)								// exhaustive 
	bys year: egen total = count(pc8)
	gcollapse (first) total (sum) oto nonsing, by(year)
save "./tmp/cn_pc_part1", replace	

// types of non-singular mappings in cn
use "./output/cn8_pc8_concord", clear	
	drop if oto == 1 
	bys cn8 year: keep if _n == 1
	gcollapse (sum) otm mto mtm, by(year)
	
	merge 1:1 year using "./tmp/cn_pc_part1", nogen
	order year total oto nonsing otm mto mtm 
	
	
/*______________________________________________________________________________
  Discussion
	
  - Example – 1:m that are actually part of m:m
	use "./output/cn8_mappings", clear
	gen otm = 1 if lcount == 1 & count > 1	
	keep if lcn8 == 1021010
	2011-2012: code 1021010 is 1:3 mapping (1022110, 1029020, 1023100)
	but it also shows up as a 3:3 mapping
	use $tmp/cn8_mappings, clear
	gen otm = 1 if lcount == 1 & count > 1	
	keep if cn8 == 1029020
	2011-2012: codes 1021010, 1021030, 1021090 all map to 1029020
	hence, we count 1021010 as m:m

  -	Example 2 - m:m
	use "./output/cn8_mappings", clear
	keep if mtm == 1
	sort lcount count lcn8 cn8
	br if lcn8 == 2050090 | cn8 == 2050020
	lcn8	cn8	lyear	year	lcount	count
	2050011	2050020	2003	2004	2	1
	2050090	2050020	2003	2004	2	2
	2050090	2050080	2003	2004	2	2
	
  - Some old codes (40 cn8 codes) are entering again after dropping. 
	After checking descriptions, it seems these are identical products when re-entering.
	use "./output/cn8_panel", clear
	bys cn8 year: keep if _n == 1
	xtset cn8 year
	tsspell cn8
	bys cn8: egen flag = max(_spell)
	br if flag > 1 & (_seq == 1 | _end == 1)
	distinct cn8 if flag > 1 & (_seq == 1 | _end == 1)
______________________________________________________________________________*/	

clear	
