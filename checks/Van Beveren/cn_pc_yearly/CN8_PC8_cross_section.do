clear
set more off
capture log close

* This file generates a concordance file from CN8 to PC8 in a chosen year between 1993 and 2010.
* File can be run in stata 10 or higher

* choose a year:
	* for now, only ready for 2003 and 2005, other years will be added later

* SET LOCAL  (YEAR) HERE	
	local yr = 2005

****************************** Directory path *******************************************
cd "SET DIRECTORY HERE"
*****************************************************************************************

log using "`yr'\output\CN8_PC8_cross_section_`yr'", replace

* Base files for concordance: Eurostat Ramon server:
	* List of CN8 codes in the chosen year
	* List of PC8 codes in the chosen year (only mandatory codes)
	* Concordance file CN8-PC8 in the chosen year
	* Structure file Prodcom for the chosen year (format can differ in different years)
	* The first three files have been translated into usable stata format prior to running this do-file
		
	
* Basic procedure:
	* Concordance file CN8 - PC8 only contains CN8 and PC8 codes 
		* covered by both classifications
	* By merging the CN8 and PC8 list with the concordance, it is 
		* possible to identify CN8 codes not covered by PC8 and vice versa
	* Loop to identify feedback effects: based on Pierce & Schott (2012, forthcoming)
	
***************************************
*** 1/ Concordance from CN8 to PC8+ ***
***************************************

* A/ Reading in concordance:

	use "`yr'\cn_pc_`yr'.dta", clear
		
		drop if cn`yr'=="" | pc`yr'==""
			
		sort cn`yr' pc`yr'
		keep cn`yr' pc`yr'
		
		count
		duplicates drop
		count
	
		* count # of unique PC8 codes
			* Note: some of these codes are more aggregated than 
			* on the original PC8 list (Z-codes, T-codes)
			* before concording, some codes in production data need to be recoded
			* in these aggregate codes
			* cfr. readme file  
			sort pc`yr'
			count if pc`yr'!=pc`yr'[_n-1]
			
		* count # of unique CN8 codes
			* Note: the number of codes is less than in original CN8 classification, 
				* not all CN8 codes are covered by PC8
							
			sort cn`yr'
			count if cn`yr'!=cn`yr'[_n-1]
			
			
* B/ Identify types of codes CN8-PC8 (one-many, many-one, many-many)
		* one-many and many-many mappings will result in groups of PC8 codes (PC8+ codes)
		
	* Identify many-to-one codes CN8-PC8:
	* Note: for now, these include many-to-many codes, correction below
		sort pc`yr' cn`yr'
		gen temp=1 if pc`yr'==pc`yr'[_n-1 ]& cn`yr'!=cn`yr'[_n-1]
		by pc`yr': egen many_one=max(temp)
		replace many_one=0 if many_one==.
		drop temp
		
	* Identify one-to-many codes CN8-PC8:
	* Note: for now, these include many-to-many codes, correction below
		
		sort cn`yr' pc`yr'
		gen temp=1 if cn`yr'==cn`yr'[_n-1 ]& pc`yr'!=pc`yr'[_n-1]
		by cn`yr': egen one_many=max(temp)
		replace one_many=0 if one_many==.
		drop temp

	* identify many-to-many codes CN8-PC8:
		gen temp=1 if many_one==1 & one_many==1
		sort pc`yr'
		by pc`yr': egen temp2=max(temp)
		sort cn`yr'
		by cn`yr': egen many_many=max(temp2)
		replace many_many=0 if many_many==.

	* Identify simple codes CN8-PC8:
		gen simple=0
		replace simple=1 if many_one==0 & one_many==0

	* Correction one-to-many and many-to-one coding:
	* many-to-many codes need to be taken out.
		replace one_many=0 if many_many==1
		replace many_one=0 if many_many==1
		drop temp temp2
		
	save "`yr'\temp", replace

	* Count types:
		
		use "`yr'\temp", clear
			sort pc`yr'
			keep if pc`yr'!=pc`yr'[_n-1]
			count
			tab one_many
			tab many_one
			tab many_many
			tab simple
	
		use "`yr'\temp", clear
			sort cn`yr'
			keep if cn`yr'!=cn`yr'[_n-1]
			count
			tab one_many
			tab many_one
			tab many_many
			tab simple
		
		
* C/ Create groupings (assign setyr to different mappings)
	* these setyr's will only be final after identification loop below
		
	use "`yr'\temp", clear

		 sort one_many many_one
                         * create groupings for one_many:
                         egen tmp=group(cn`yr') if one_many==1
         
                 * create groupings for many_one:
                        * Numbering needs to start after numbering for one_many
                         egen tmpno=max(tmp)
                         if tmpno==. {
                                 * if there are no 1-M groups
                                 drop tmpno
                                 gen tmpno=0
                         		}
                                 
                         egen tmp2=group(pc`yr') if many_one==1 
                         gen tmp3=tmpno + tmp2 
                         drop tmpno
 
                 * create groupings for many_many:
                         * Numbering needs to start after numbering for many_one
                        egen tmpno=max(tmp3)
                        if tmpno==. {
                                * if there are no M-1 groups
                                drop tmpno
                                egen tmpno=max(tmp)
                                }
                        if tmpno==. {
                                * if there are no 1-M groups
                                drop tmpno
                                gen tmpno=0
 		                        }
                        egen tmp4=group(pc`yr') if many_many==1
                                 * we could group on cn`yr' here as well, needs to be checked for feedback effects anyway
                        gen tmp5=tmpno + tmp4 
                        drop tmpno
        
                 * for simple codes, we assign a setyr to the simple change:
                        egen tmpno=max(tmp5)
                        if tmpno==. {
                              * if there are no M-M groups
                              drop tmpno
                              egen tmpno=max(tmp3)
                               }
                        if tmpno==. {
                              * if there are no M-1 groups
                              drop tmpno
                              egen tmpno=max(tmp)
                               }
                        if tmpno==. {
                              * if there are no 1-M groups
                         drop tmpno
                               gen tmpno=0
                         }
                        egen tmp6=group(pc`yr') if simple==1
                        gen tmp7=tmpno + tmp6
                        drop tmpno
  
                        egen code=rowtotal(tmp tmp3 tmp5 tmp7)
                        drop tmp tmp2-tmp7
               
         
* D/ loop to identify feedback effects M-M groupings within each year 
		* Based on Pierce and Schott (2009, NBER 14837)
        * Explanation of loop:
                * function mod(`zzz', 2) is used to switch even and odd turns in the loop
                * modulus(x,y) = x - y * int(x/y)
                * equal to 0 if zzz=2, 4, 6, 8, ... 
                * different from 0 for zzz=3, 5, 7, ...
                * each time the setyr's are grouped by new or obsolete
                * equivalent to sorting in excel by new and obsolete
                * to identify feedback effects

        	 bysort cn`yr': egen c1 = min(code)
                * assign min setyr by cn`yr' (we grouped by pc`yr' above for M-M)
                 local zzz = 2
                 local stop = 0
                 while `stop'==0 {
                 noisily display [`zzz']
                 local zlag = `zzz'-1
                 if mod(`zzz',2)==0 {
                        bysort pc`yr': egen c`zzz'= min(c`zlag')
                  }
                 if mod(`zzz',2)~=0 {
                        bysort cn`yr': egen c`zzz'= min(c`zlag')
                  }
         
                 compare c`zzz' c`zlag'
                 gen idx = c`zzz'==c`zlag'
                 tab idx
                 local stop = r(r)==1
                 local zzz = `zzz'+1
                 display r(r) " " [`stop']
                 drop idx
                 }
  
        local yyy = `zzz' - 1
        gen setyr = c`yyy'
        drop c1-c`yyy'
 
	* Verify coding:
		* counts should equal zero in both cases
		
	       sort pc`yr' 
	       count if pc`yr'==pc`yr'[_n-1] & setyr!=setyr[_n-1]
	 
	       sort cn`yr'
	       count if cn`yr'==cn`yr'[_n-1] & setyr!=setyr[_n-1]
	  
	* recode, so setyr are numbered consecutively 
	       sort setyr
	       egen setyr2=group(setyr)
	       drop setyr 
	       rename setyr2 setyr
	       
	       sort setyr
	       count if setyr!=setyr[_n-1]
	
	* we need variable setyr equal to PC8 if only one PC8 code in that setyr
		* how many pc8+ codes and how many codes per group?
			gen tmp=setyr
			tostring setyr, replace
			replace setyr=pc`yr' if simple==1 | many_one==1
			gen synthetic = (simple==0 & many_one==0)
			rename setyr pc8plus
			drop tmp code
			
			sort pc8plus
			count if pc8plus!=pc8plus[_n-1]
	save "`yr'\output\concordance_cn8_pc8plus_`yr'", replace
	


******************************************
*** 2/ Differences in coverage CN8-PC8 ***
******************************************
 
* A/ List of PC8 codes not covered in concordance (auxiliary file)
	* we need to generate a list of PC8 codes that features in concordance, but not in PC8 list
		* This file can be used to find the aggregated (Z) codes and all PC8 codes not covered by CN8
		* To identify the aggregates, the Prodcom structure file can be used
		* End of PDF file: list of Z-aggregates (NACE 99.z)
		* List of PC8 codes not covered by CN8 + PC8 codes that need to be recoded in aggregates
			* Based on the auxiliary file generated here and Prodcom List for `yr' to identify codes and aggregates:
			* PC8_`yr'_special_codes
		
		use "`yr'\pc_`yr'", clear
			rename pc pc`yr'
			sort pc`yr'
		save "`yr'\temp", replace
	
		use "`yr'\output\concordance_cn8_pc8plus_`yr'", clear
			sort pc`yr'
			merge pc`yr' using "`yr'\temp"
				* _m==1 are codes that feature in concordance, not on PC8 list
				* these are the aggregated codes (Z-codes)
				* _m==2 are industrial services + breakdowns of Z-aggregates
			keep if _m==1 | _m==2
			tab _m
		saveold "`yr'\output\PC8_`yr'_not_in_concordance", replace
		outsheet using "`yr'\output\PC8_`yr'_not_in_concordance.csv", replace

* B/ List of CN8 codes not covered in concordance

	* Read in file with ALL CN8 codes for `yr'
	* including CN8 codes not covered by PC8 classification
	
		use "`yr'\CN_`yr'", replace
			duplicates drop
			sort cn`yr'
			count
			save "`yr'\temp", replace
				* Number of unique CN8 codes in year `yr'
			
	* Merge concordance file CN8-PC8 with file with ALL CN8 codes  
		* identification of CN8 codes not on the Prodcom List
		
		use "`yr'\output\concordance_cn8_pc8plus_`yr'", clear
			sort cn`yr'
			merge cn`yr' using "`yr'\temp"
			tab _m
				* _m==2 implies CN8 codes not on PC8 list
			gen notpc = 0
			replace notpc = 1 if _m==2
			label var notpc "CN8 not covered by PC8"
		drop _m
		tab notpc
			* notpc=1 means that these CN8 products are not covered by the Prodcom List in `yr'.
			* These CN8 products do not feature in concordance file CN8-PC8 for `yr'
			* They have to be dropped from the trade data before concording 
			
	saveold "`yr'\output\concordance_cn8_pc8plus_`yr'", replace
	outsheet using "`yr'\output\concordance_cn8_pc8plus_`yr'.csv", replace
		* This concordance takes into account which CN8 codes need to be dropped before aggregating to PC8
		* and it identifies the PC8+ groups
		* this is the concordance that can be used to merge with trade and production data data
		* necessary steps:
			* merge trade data with concordance file
			* drop all codes where notpc==1 (CN8 codes not covered by PC8)
			* Cases where _m==1 (unmatched CN8 codes in data)
				* these could be "residual" categories, ending or starting with 99
				* or mistakes in reporting
				* need to be dropped from data (no corresponding production data)
			* Concord CN8 to PC8+ and aggregate product-level data to PC8+ level
			* For production data: drop PC8 products not covered by concordance
				* + recode special codes + aggregate to PC8+ level
			

*************************************
*** 3/ Concording production data ***
*************************************			
/* Procedure:
		A/ Read in domestic production data
		B/ Recode all optional codes in the data (if applicable)
		C/ Merge the production data with the file "PC8_`yr'_special_codes" on variable "pc`yr'"
		D/ Drop all products where the "type" is "industrial services" or "no cn correspondence"
		E/ Recode all products where the type is "aggregate" (replace pc`yr' = new_code if type=="aggregate")
		F/ Merge the (recoded) production data with concordance file "concordance_pc8_pc8plus_`yr'"
			* In principle, all PC8 codes that appear in the data should feature in the concordance
			* If some PC8 codes do not feature in concordance, this could be due to reporting errors or "residual" categories
			* Unmatched PC8 codes in the data need to be dropped (no corresponding PC8+ code)
		F/ Aggregate the data from (firm-)PC8 product level to (firm-)PC8+ level
*/		

/* Example using Belgian data at PC8 product level


	* Optional codes: Blist and Nlist: prepare files
		
		if `yr' < 2005 {
			use Nlist_codes_1993_2005, clear
				sort pc8
				count if pc8==pc8[_n-1]
			save temp_nlist, replace
			
			use "`yr'\PC_`yr'_Blist", clear
				tostring pc, g(pc8)
				sort pc8
				drop pc
				merge pc8 using optional_codes_1993_2005
				tab _m
				drop if _m==2
					* _m==1 should not occur
				drop _m
				duplicates drop
				sort pc8
				count if pc8==pc8[_n-1]
			save temp_blist, replace
			}
		
	* temp concordance files:
		use "`yr'\output\concordance_cn8_pc8plus_`yr'", replace
			keep pc`yr' pc8plus synthetic
			drop if pc`yr'==""
			duplicates drop
			sort pc`yr'
			count if pc`yr'==pc`yr'[_n-1]
		save temp_domprod, replace
		
		use "`yr'\output\concordance_cn8_pc8plus_`yr'", replace
			keep cn`yr' pc8plus notpc
			duplicates drop
			sort cn`yr'
			count if cn`yr'==cn`yr'[_n-1]
		save temp_trade, replace

	
	* Read in production data + recode where necessary:
		
		use ${hdd}production_pt_1995_2008, clear
				
		label var lev3v_prod "Production value sold"
		label var prodcom "PC8 product, string"
		label var mioQ "Production value sold, mio"
			
		keep if year==`yr'
		sort prodcom
		count if prodcom==prodcom[_n-1]
		rename prodcom pc8
		
		* optional codes
	
			if `yr' < 2005 {	
				* merge with list of N-codes to recode if applicable
					merge pc8 using temp_nlist
					tab _m
					capture table pc8 if _m==3, c(count lev3v_prod sum lev3v_prod sum mioQ) format(%20.2fc) row
					replace pc8 = pc_mand if _m==3
					drop if _m==2
					drop _m pc_mand
				
				* merge with list of B-codes to recode if applicable
					sort pc8
					merge pc8 using temp_blist
					tab _m
					drop if _m==2
					capture table pc8 if _m==3, c(count lev3v_prod sum lev3v_prod sum mioQ) format(%20.2fc) row
					replace pc8 = pc_mand if _m==3
					drop pc_mand
					drop _m
			
				}
				
				sort pc8
				
				count if pc8==pc8[_n-1]
					* due to recoding, there might be doubles, need to be collapsed
					* e.g. two optional codes that map into one mandatory code
		
			if `yr' < 2005 {	
				collapse (sum) lev3v_prod mioQ, by(pc8)
					* only mandatory PC8 codes left in the data
					}
			
			sort pc8
			save production_`yr'_concorded, replace
				
		* Special codes (industrial services, aggregates)
			insheet using "`yr'\PC8_`yr'_special_codes.csv", clear delimiter(";")
				tostring pc`yr', g(pc8)
				keep pc8 new_code type
				tab type
				sort pc8
				count if pc8==pc8[_n-1]
			save temp, replace
			
			use production_`yr'_concorded, clear
				merge pc8 using temp
				tab _m
				tab type if _m==3
				drop if type=="industrial services" | type=="no cn correspondence"
				tab type
				replace pc8 = new_code if _m==3
				
				* there can again be doubles after recoding into aggregates
					sort pc8
					count if pc8==pc8[_n-1]
					collapse (sum) lev3v_prod mioQ, by(pc8)
						* only mandatory and Z-aggregates, all codes should feature in concordance after this step
					sort pc8
					count if pc8==pc8[_n-1]
					drop if lev3v_prod==0 | lev3v_prod==.
		
		* concording PC8 products into PC8+ classification
				
			rename pc8 pc`yr'
			sort pc`yr'
			merge pc`yr' using temp_domprod
			
			tab _m
			
			table pc`yr' if _m==1, c(sum mioQ count mioQ)
					
			* drop PC8 products not recognized in concordance (coding errors, residual categories)
				keep if _m==3
					
			* collapse to PC8+ level if applicable
				sort pc8plus 
				count if pc8plus==pc8plus[_n-1]
				
				collapse (sum) lev3v_prod mioQ, by(pc8plus)
				
				sort pc8plus 
				count if pc8plus==pc8plus[_n-1]
					* should be unique
				count
				
			save production_`yr'_concorded, replace	
			
				
**********************************************
*** 4/ Concording international trade data ***
**********************************************			
/* Procedure:
		A/ Read in international trade data
		B/ Merge the trade data with the file "concordance_cn8_hs6plus_`yr'" on variable "cn`yr'"
		C/ Drop all products where the dummy "notpc" equals one (these are CN8 products not covered by PC8)
			* In principle, all CN8 codes that appear in the data should feature in the concordance
			* If some CN8 codes do not feature in concordance, this could be due to reporting errors or "residual" categories
			* Unmatched CN8 codes in the data need to be dropped (no corresponding PC8 code)
		F/ Aggregate the data from firm-CN8 product level to firm-HS6+ level
*/			

/* Example using Belgian trade data at CN8 product level
*/
	
	use goods_pt_1993_2010, clear
				* read in data and label vars
				
		label var valueII "Instrastat import value"
		label var valueIE "Extrastat import value"
		label var valueXI "Intrastat export value"
		label var valueXE "Extrastat import value"
				
		describe
		keep if year==`yr'
			
		* merge annual CN8 codes with their corresponding PC8+ code
			* and drop CN8 products not covered by PC8 list
		
			sort cn8 
			rename cn8 cn`yr'
			
			merge cn`yr' using temp_trade
			tab _m
			table cn`yr' if _m==1, c(sum valueII sum valueIE sum valueXE sum valueXI) format(%20.2fc) row
			keep if _m==3
			
			table notpc, c(sum valueII sum valueIE sum valueXE sum valueXI) format(%20.2fc) row
			drop if notpc==1
			
			tab year
			sort year pc8plus
			collapse (sum) valueII valueIE valueXI valueXE, by(pc8plus)
			sort pc8plus
			count if pc8plus==pc8plus[_n-1]
				* should be unique
			count
			
		save goods_pt_concorded_`yr', replace
		
			
*****************************************************
*** 5/ Merging domestic production and trade data ***
*****************************************************			
/* Procedure:
		A/ Sort international trade and production data at firm-PC8+ level
		B/ Merge the two data sets on (the firm identifier and) "pc8plus" (common product identifier)
*/			

/* Example using Belgian data at product-level (PC8+) */
	use goods_pt_concorded_`yr', clear
		merge pc8plus using ${hdd}production_`yr'_concorded
		
		tab _m
		foreach var of varlist valueII valueIE valueXI valueXE mioQ lev3v_prod {	
			replace `var' = 0 if `var'==.
			}
		
	save trade_prod_pc8plus_`yr', replace
*/
	
log close

erase "`yr'\temp.dta"
!erase temp.dta
!erase temp_blist.dta
!erase temp_nlist.dta
!erase temp_domprod.dta
!erase temp_trade.dta


