clear
set more off
capture log close

* Files can be run in stata 10 or higher

****************************** Directory path *******************************************
cd "C:\Users\n06017\Documents\Magic Briefcase\pc8_over_time\"
*****************************************************************************************


* Concordance file can be used to generate PC8 concordance for all years between 1993 and 2010
	* if b is the first year, then b1 is the first "effyr" (year in which first relevant changes become effective)
	* when generating a concordance between two consecutive years, only step 1 and 2 need to be executed.
	* since there are no changes in some years (e.g. 1997), numlist is defined that groups all years in which there are changes
	
* Source files to generate concordances: Eurostat ramon server
	* Necessary files: changes in PC8 classification over time + list of PC8 codes in every year
	* Original files: folder "Originals Ramon"
	* Eurostat files with changes over time contain optional codes and aggregate codes
	* Similarly: list of PC8 codes in each year also includes optional and aggregate codes
		* we have adapted these original files, the concordance procedure is developed only for "mandatory" codes
		* we will take the existence of optional and aggregate codes into account 
			* by providing files that allow researchers to recode these codes into their mandatory counterparts 
			* the use of optional/aggregate codes can be country-specific
			* recoding only takes place if the codes actually feature in the data
	
* SET LOCAL YEAR HERE (START-END)	
	local b = 2003
	local b1 = `b'+1
	local e = 2010

log using "output\pc8_over_time_`b'_`e'", replace


****************************************************	
*** Step 0: preparation of files: optional codes ***
****************************************************
* file with all optional codes between 1993 and 2005: optional_codes_1993_2005
* file with all N-list codes between 1993-2005: Nlist_codes_1993_2005
* Starting 2005, all optional (B-list) and N-list codes have been abolished.

		
* 0/ Generate a file with all optional codes that feature during the chosen sample period (between `b' and `e')
	* and their corresponding mandatory codes
	* this file needs to be merged with prodcom data (before concording the data) 
		* and with CN8-PC8 concordance in final year of the data period
		* merge with CN8-PC8 concordance is only necessary when concording production and trade data
		* and will only affect PC8 codes that were optional at some point during sample period and mandatory later on
		* for these codes, we need to keep the more aggregated PC code throughout
		* if concordance period starts after 2004, not necessary to run this step (if condition at start ensures this)
	
	if `b' < 2005 {
		
		if `e' < 2005 {
			local f = `e' 
			}
		
		if `e' >= 2005 {
			local f = 2004 
			}
		
		use PC_`b'_Blist, clear
			forval x = `b1' / `f' {
				append using PC_`x'_Blist
				}
		
		duplicates drop
		tostring pc, replace
		rename pc pc8
		sort pc8
		merge pc8 using optional_codes_1993_2005
		tab _m
		drop if _m==2
			* _m==1 should not occur
		drop _m
		sort pc8
	save optional_codes_`b'_`e'_sample, replace
	}
			

* 1/ create concordance of PC8 over time with mandatory codes only
	* need to recode all codes that have been optional at some point in time
	* in some cases, optional code later becomes mandatory
	* in these cases, we keep the more aggregated code during the whole sample period
	* Remark: when merging with CN8 using CN8-PC8 concordance file, 
		* these optional codes that become mandatory at some point will also have to be recoded in the CN8-PC8 concordance file!
	
		insheet using input_file_PC_over_time_edited.csv, clear delimit(";")
			* this file is an edited version of Eurostat's original files with changes over time
			* For instance, when concording data between 1998 and 2006, many optional codes would drop out in 2005
				* i.e. the optional code would be listed as "obsolete" and no "new" code would be given
				* if we would simply replace the optional code by its mandatory code in all of these cases
				* we would drop these mandatory codes from the data because they are not covered in all years
				* However, in the majority of cases, the mandatory code does not drop out, only the optional breakdown disappears
				* In these cases, we have manually entered the mandatory code as the "new" code in the input file
				* IF the mandatory code continues to exist in the next year (verified in Prodcom structure files)
			* Similar corrections have been applied for aggregate codes (Z, T, Q) and for the N-list codes
			* Original Eurostat file can be found in the folder "Originals Ramon"
			 
			drop pcfrom_recode pcto_recode
		
	if `b' < 2005 {
		
		* merge obsolete codes with file with optional codes to recode them
			rename pcfrom pc8
			sort pc8
			count
			merge pc8 using optional_codes_`b'_`e'_sample
			tab _m
			replace pc8 = pc_mand if _m==3
			drop if _m==2
			count
			rename pc8 pcfrom
		
		* merge new codes with file with optional codes to recode them
			rename pcto pc8
			sort pc8
			count
			drop _m
			merge pc8 using optional_codes_`b'_`e'_sample
			tab _m
			replace pc8 = pc_mand if _m==3
			drop if _m==2
			rename pc8 pcto
			
		}
			
		* drop duplicate lines (resulting from changes in optional codes that imply no changes in mandatory codes)
			drop opt n v10 v12 source v14 _m pc_mand
			
			rename to effyr
			drop from
			rename pcfrom obsolete
			rename pcto new

			replace obsolete="" if obsolete=="-----"
			replace new="" if new=="-----"
			replace obsolete="" if obsolete=="--"
			
			duplicates drop
			drop if obsolete==new & ex=="" & v9==""
				* ex variables indicate partial mapping
			drop v15 ex v9
		save temp, replace

* 2/ drop all Q, T, Z and N codes from concordance over time file
			* N and B codes are recoded (see 1/ for B-codes)
			* Q, T, and Z codes are more aggregated versions of existing PC codes
			* these codes should not feature in the prodcom data, since countries are required to report PC data at the most detailed level
			* In the concordance files between CN8 and PC8, the PC8 codes feature in their more aggregate versions
				* T and Q codes feature both in aggregated and disaggregated  form, but Z-codes only feature in their more aggregate form 
				* hence, when concording CN8-PC8 (either to PC8 or HS6), disaggregated counterparts of Z-codes need to be recoded 
				* both in the prodcom list files for each year and in the data (cfr. section 3.4 in the paper)
			* All of these "special" codes (optional (N- or B-list), T, Q, Z) can be found in the prodcom structure files
				* PDF, access or excel files for each year
	
	* N-codes: do not feature in concordance file
	* Q, T and Z-codes: 
		use TZQlist_codes_1993_2010.dta, replace
			* compiled from prodcom structure files in different years
			drop year
			sort pc
			duplicates drop
			sort pc
		save tqz_temp, replace
	
		use temp, clear
			rename obsolete pc
			sort pc
			merge pc using tqz_temp
			tab _m
			drop if _m==3 | _m==2
				* can be dropped, if recoding was required this is done in the input file
			rename pc obsolete
			drop _m
			
			rename new pc
			sort pc
			merge pc using tqz_temp
			tab _m
			drop if _m==3 | _m==2
				* idem, can be dropped, if recoding was required this is done in the input file
			rename pc new
			drop _m
		save input_file_PC_over_time_edited, replace
		erase tqz_temp.dta
		
*******************************************************	
*** Step 1: preparation of files: identify mappings ***
*******************************************************

* Need to identify different type of mappings between PC8 in t and t+1 (effyr)
* i.e. growing or shrinking families respectively.

* base file: conversion_pc_overtime_input.xls
	* three Eurostat base files: "PRODCOM_YEARLY_UPDATE_OF_CODES_SINCE_1994.xls" (until 2009), "prodcom 1994 - prodcom 1993.pdf" (translated into excel) and "PRC 2010- PRC 2009.xls" 
	* concordance only contains "regular codes", no B-list, N-list, Q-, Z- or T-list codes.
	* B-list and N-list codes might feature in the data, need to be recoded into mandatory codes where necessary
	
	use input_file_PC_over_time_edited, clear 
			sort new
		
			
* rename vars + procedure to break up codes (spaces need to removed) and put them back together as strings
	/* Effyr is the "To" year in the original file, e.g. correspondence bw t-1 and t, effyr==t */
	
	* exit and entry dummy:
	gen exit=0
	replace exit=1 if new==""
	gen entry=0
	replace entry=1 if obsolete==""
	
	* Identify one-to-many codes:
		* Note: for now, these include many-to-many codes, correction below
	sort effyr obsolete new
	gen temp=1 if obsolete==obsolete[_n-1 ]& new!=new[_n-1] & exit!=1 & entry!=1
	sort effyr obsolete
	by effyr obsolete: egen one_many=max(temp)
	replace one_many=0 if one_many==.
	drop temp
	
	
	* Identify many-to-one codes:
		* Note: for now, these include many-to-many codes, correction below
	sort effyr new obsolete
	gen temp=1 if new==new[_n-1 ]& obsolete!=obsolete[_n-1] & exit!=1	& entry!=1
	sort effyr new
	by effyr new: egen many_one=max(temp)
	replace many_one=0 if many_one==.
	drop temp
	
	* identify many-to-many codes:
		* these have to be assigned unique setyr using loop below
	gen temp=1 if many_one==1 & one_many==1
	sort effyr obsolete
	by effyr obsolete: egen temp2=max(temp)
	sort effyr new
	by effyr new: egen many_many=max(temp2)
	replace many_many=0 if many_many==.
	replace many_many=0 if exit==1 | entry==1
	replace one_many=0 if exit==1 | entry==1
	replace many_one=0 if exit==1 | entry==1
	
	* Identify simple codes:
	gen simple=0
	replace simple=1 if many_many==0 & one_many==0 & many_one==0 & exit==0 & entry==0
	
	* Correction one-to-many and many-to-one coding:
		* many-to-many codes need to be taken out.
	replace one_many=0 if many_many==1
	replace many_one=0 if many_many==1

	* check: sum of simple, one-many, many-one, many-many, exit and entry should equal 1 (not more, not less):
	drop temp temp2
	egen temp=rowtotal(simple one_many many_one many_many exit entry)
	tab temp
	
save temp, replace
tab effyr


**************************************************************	
*** Step 2: Generate setyr's for changes between t and t-1 ***
**************************************************************
* Loop 1	
* Generate setyr's that will be used to verify feedback effects
* for many-many mappings between t and t-1
		
* define the relevant numlist
* why: there are no change in PC8 in some years, need to take this into account

if `b'!=1996 {
	keep if effyr >= `b1' & effyr <= `e'
	levelsof effyr, local(pcyr)	
	* we also need local with effyr's +1 (like b and b1)
		gen effyr1 = effyr 
		replace effyr1 = . if effyr == `b1'
		tab effyr1
		levelsof effyr1, local(pcyr1)
	}

if `b'==1996 {
	keep if effyr >= `b1' & effyr <= `e'
	levelsof effyr, local(pcyr)	
	* we also need local with effyr's +1 (like b and b1)
		gen effyr1 = effyr 
		replace effyr1 = . if effyr == `b1'
		replace effyr1 = . if effyr == 1998
		tab effyr1
		levelsof effyr1, local(pcyr1)
	}
	
	
	foreach yr of local pcyr {
		use temp, clear
		keep if effyr==`yr'
		
		sort effyr one_many many_one
			* create groupings for one_many:
			egen tmp=group(obsolete) if one_many==1
	
		* create groupings for many_one:
			* Numbering needs to start after numbering for one_many:
			bysort effyr: egen tmpno=max(tmp)
			if tmpno==. {
				* if there are no 1-M groups
				drop tmpno
				gen tmpno=0
				}
			egen tmp2=group(new) if many_one==1 
			gen tmp3=tmpno + tmp2
			drop tmpno 

		* create groupings for many-many:
			bysort effyr: egen tmpno=max(tmp3)
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

			egen tmp4=group(obsolete) if many_many==1
				* we could group on new here as well, needs to be checked for feedback effects anyway
			gen tmp5=tmpno + tmp4
			drop tmpno

		* create groupings for simple changes:
			bysort effyr: egen tmpno=max(tmp5)
			if tmpno==. {
				* if there are no M-M mappings
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
			egen tmp6=group(obsolete) if simple==1
			gen tmp7=tmpno + tmp6
			drop tmpno
	
		egen tmp8= rowtotal(tmp tmp3 tmp5 tmp7)
		gen tmp9=.`yr'
		egen code=concat(tmp8 tmp9)
		destring code, replace
		drop tmp tmp2-tmp9 temp	
		
		* obsolete and new codes need to numeric
			destring obsolete, g(obsoletenum)
			destring new, g(newnum)

		
		keep effyr obsolete new exit entry one_many many_one many_many simple obsoletenum newnum code
		
		save temp_`yr', replace
		}
	
	
		
* loop to identify feedback effects M-M groupings within a year 
	* For now, we ignore entry and exit codes (changes in coverage over time)
		* Based on Pierce and Schott (2012)
        * Explanation of loop:
                * function mod(`zzz', 2) is used to switch even and odd turns in the loop
                * modulus(x,y) = x - y * int(x/y)
                * equal to 0 if zzz=2, 4, 6, 8, ... 
                * different from 0 for zzz=3, 5, 7, ...
                * each time the setyr's are grouped by new or obsolete
                * equivalent to sorting in excel by new and obsolete
                * to identify feedback effects
         
foreach yr of local pcyr {
         
         use temp_`yr', clear

         bysort new: egen c1 = min(code)
                * assign min setyr by new (we grouped by obsolete above for M-M)
                 local zzz = 2
                 local stop = 0
                 while `stop'==0 {
                 noisily display [`zzz']
                 local zlag = `zzz'-1
                 if mod(`zzz',2)==0 {
                        bysort obsolete: egen c`zzz'= min(c`zlag')
                  }
                 if mod(`zzz',2)~=0 {
                        bysort new: egen c`zzz'= min(c`zlag')
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

       sort new 
       count if new==new[_n-1] & setyr!=setyr[_n-1]
 
       sort obsolete
       count if obsolete==obsolete[_n-1] & setyr!=setyr[_n-1]
  
* recode, so setyr are numbered consecutively 
       sort effyr setyr
       egen group=group(setyr)
       gen tmp=.
       egen tmp2=concat(group tmp effyr)
       destring tmp2, gen(setyr2)
       drop setyr tmp tmp2
       rename setyr2 setyr
 
* prepare file for subsequent analysis:
        drop code
        format setyr %9.4fc
        sort obsoletenum newnum effyr 
save temp2_`yr', replace
        rename newnum new`yr'
        rename obsoletenum obs`yr'
        rename setyr setyr`yr'
        rename effyr effyr`yr'
        order obs`yr' new`yr'
        sort obs`yr'
                        
save temp_xchain_`yr', replace
}


*** Create file for all years between `b' and `e' ***
         * we need this later on


if `b1'!=1997 {							  
	use temp2_`b1', clear
			
		foreach x of local pcyr1 {
				append using temp2_`x'
			save PC_setyr_`b'_`e', replace
			} 
	}
	
if `b1'==1997 {							  
	use temp2_1998, clear
		foreach x of local pcyr1 {
				append using temp2_`x'
			save PC_setyr_`b'_`e', replace
			} 
	}
	
use PC_setyr_`b'_`e', clear
	duplicates drop
	sort obsoletenum newnum effyr
save PC_setyr_`b'_`e', replace 

* Table 4 of the WP:
	sort effyr obsoletenum
	table effyr if obsoletenum!=obsoletenum[_n-1], c(count obsoletenum)
	sort effyr newnum
	table effyr if newnum!=newnum[_n-1], c(count newnum)
	sort effyr setyr
	table effyr if setyr!=setyr[_n-1], c(count setyr)
	table effyr, c(sum simple sum exit sum entry)
	

*********************************************************	
*** Step 3: Consistent panel over time (procedure PS) ***
*********************************************************	
* This procedure is almost identical to that of Schott and Pierce (2009)
* Loop 2 (news loop PS) 
                
	*** Chains over time: identify them ***
	* Use the yearly concordance files to chain the obs-new matches across years.
	* the goal is to find news from subsequent years that modifies news from earlier years
	* the files generated below only contain chains, not changes that only affect single years
	* we still ignore entry and exit here (dropped from the data and kept in a separate file for now)

	
	foreach y of local pcyr {
		use temp_xchain_`y', clear
			keep if exit==1 | entry==1
			save temp_exit_entry_`y', replace
		use temp_xchain_`y', clear
			drop if exit==1 | entry==1
			drop exit entry one_many many_one many_many simple obsolete new
			rename obs`y' obs
			foreach x of local pcyr {
				if `x'>`y' {
					noisily display [`y'] " " [`x']
					rename new`y' obs`x'
					sort obs`x'
					joinby obs`x' using temp_xchain_`x', unmatched(master)
					noisily tab _merge
					drop if _merge==2
					rename _merge _m`y'`x'
					rename obs`x' new`y'
					}
			}
			
			gen _mjunk=0
			egen idx = rowmax(_m*)
			noisily tab idx
			keep if idx==3
			sort obs
			drop _m*
		save temp2_xchain_`y', replace
	}
	
	*** Assign single setyear to all members of a family ***
	* Put all the chained changes in one file and assign single setyr to all members of a family revealed by the chain.
	* challenge here is to set a single setyr for all families revealed by the chain.
	* Two cases for a family: growing or shrinking
		
	* the iteration of min commands in the loop below takes care of both cases by searching for the setyr for
	* a family that covers all of its members.

if `b1'!=1997 {
	use temp2_xchain_`b1', clear
		foreach y of local pcyr1 {
			append using temp2_xchain_`y'
		}
	}

if `b1'==1997 {
	use temp2_xchain_1998, clear
		foreach y of local pcyr1 {
			append using temp2_xchain_`y'
		}
	}
	
	
	drop new
	keep obs new* setyr* effyr*
	
	capture duplicates drop
	egen double setyr = rowmin(setyr*)
	egen nchain = rownonmiss(new*)
	
	rename obs obsoletenum
	order obs setyr
	sort obs
	save temp2_xchain, replace
		/* This file groups all families that change over time */

	
	use temp2_xchain, clear
		drop setyr effyr*
		egen t1 = seq(), by(obs)
		reshape long new setyr, i(obs t1) j(effyr)
		drop if new==. & setyr==.
		drop t1 nchain
		duplicates drop obs effyr new setyr, force
		
		rename new newnum
	
	
	*** Add simple changes back in (no chains) ***
	* have to add these in before the min loop below in case a non-chain obs-pair is part of a family
		sort obsoletenum newnum effyr
		merge obsoletenum newnum effyr using PC_setyr_`b'_`e'
		
		drop if effyr < `b'| effyr > `e'
		tab _merge
		drop _merge

	*** Family identifcation loop over time ***
	* Example:
	* 1999: three codes become two codes in 2000 and these two codes each map into two different 
	* codes in 2001, some of which might already have existed in 1999.
	* all these codes will be grouped together starting 1999 in this loop (they are assigned the minimum setyear).
	
	egen double t1 = min(setyr), by(obsoletenum)
	rename setyr oldsetyr
	local zzz = 2
	local stop = 0
	while `stop'==0 {
		noisily display [`zzz']
		local zlag = `zzz'-1
		if mod(`zzz',2)==0 {
			egen double t`zzz'= min(t`zlag'), by(newnum)
		}
	
		if mod(`zzz',2)~=0 {
			egen double t`zzz'= min(t`zlag'), by(obsoletenum)
		}
	
		compare t`zzz' t`zlag'
		gen idx = t`zzz'==t`zlag'
		tab idx
		local stop = r(r)==1
		local zzz = `zzz'+1
		display r(r) " " [`stop']
		drop idx
		}
	
	
	
	local yyy = `zzz'-1
	gen double setyr = t`yyy'
	keep obsoletenum effyr newnum setyr
	duplicates drop
	sort obsoletenum newnum effyr
	
	

save  output_file_PC_`b'_`e'_setyr, replace



*********************************************************	
*** Step 4: Consistent panel over time (procedure PS) ***
*********************************************************	
*** Generate concordance file with ALL PC codes between `b' and `e' ***
	* including codes that have not changed
	* procedure draws again on Pierce and Schott (2012) but with some adaptations
	* While they develop a concordance specific to the codes featuring in the data, 
		* we take all potential (mandatory) PC8 codes into account
	* We develop a concordance for all existing PC8 codes (generic for all countries + necessary to match trade and production)


	* generate files with PC codes in each particular year
		* based on PC list, Eurostat Ramon
		* however: we only keep "mandatory disaggregated" codes, i.e. no B-list, N-list, Q-list, T-list and Z-list codes
		* B-list and N-list codes can feature in the prodcom data, they will be recoded into their mandatory counterparts 
			* prior to concording
		
	foreach x of numlist `b'/`e'{
	
		use PC_`x', clear
		
		* merge with file with optional codes (some optional codes become mandatory in later years)
				* but we need to keep the more aggregated (previous mandatory) code in all years
				
				rename pc pc8
				sort pc8
				count
				merge pc8 using optional_codes_`b'_`e'_sample
				tab _m
				replace pc8=pc_mand if _m==3
				drop if _m==2
				drop _m pc_mand
				rename pc8 pc
				duplicates drop
		
		* All codes should be numeric (T, Z, E and Q headings do not feature in the file with "regular" codes)
			count
			destring pc, gen(pcnum)
			count if pc!="" & pcnum==.
			keep pcnum pc
			duplicates drop
			count
			save PC2_`x', replace
		}
		
		
	foreach y of numlist `b' / `e' {

		local ylead = `y'+1
		noisily display " "
		noisily display " "
		noisily display "NEW LOOP " [`y']
		noisily display " "
		noisily display " "

	* Step 1
	* get obsolete-new files ready
	* temp_obsolete is used to assign setyrs to codes that are last used in year y
	* To insure against the code ever becomming obsolete, 
	* i.e., it being an obsolete code in any year after the year of the loop

	use output_file_PC_`b'_`e'_setyr, clear
		keep if effyr>=`ylead'
		keep obsoletenum setyr
		drop if obsoletenum==.
		capture duplicates drop
		sort obsoletenum
	save temp_obsolete_`y', replace emptyok

	* Step 2
	* temp_new is used to assign setyrs to codes that are new in year y
	* bascially want to insure against this code ever having been a new code prior to this
	* year; if so, need to assign it a setyr
	
	use output_file_PC_`b'_`e'_setyr, clear
		keep if effyr<=`ylead'
		keep newnum setyr
		drop if newnum==.
		capture duplicates drop
		sort newnum
	save temp_new_`y', replace emptyok

	* Step 3
	* read in data and collapse to appropriate level
	
	use PC2_`y', clear
	
	format pcnum %15.0f

	* merge in obsolete-code family identifiers
		rename pcnum obsoletenum
		sort obsoletenum
		merge obsoletenum using temp_obsolete_`y', keep(setyr)
		noisily tab _merge
		drop if _merge==2
		drop _merge
		rename obsoletenum pcnum

	* merge in new-code family identifiers
		rename pcnum newnum
		sort newnum
		merge newnum using temp_new_`y', keep(setyr) update
		noisily tab _merge
		drop if _merge==2
		drop _merge
		rename newnum pcnum

	save prodcom_PC_`y'_concorded, replace

	}

	* Step 4: Create panel file
	foreach y of numlist `b' / `e' {
		use prodcom_PC_`y'_concorded, replace
		rename pcnum group`y'
		drop if setyr==.
		sort setyr group`y'
		save junk_x_`y', replace
		}

	use junk_x_`b', replace
	foreach y of numlist `b' / `e' {
		display [`y']
		merge setyr using junk_x_`y'
		tab _merge
		drop _merge
		order setyr
		sort setyr group`y'
		}


	foreach y of numlist `b' / `e' {
		egen i`y'= tag(setyr group`y')
		replace group`y'=. if i`y'==0
		drop i`y'
		}

	save setyr_PC_`b'_`e', replace
	
	

******************************************************	
*** Step 5: Adjustments for changes in coverage PC ***
******************************************************
* Coverage of PC list has changed over time
* Codes that enter or exit from the list: temp_exit_entry_`y'

* generate one file with all exiting and entering codes 
* since they are not covered in all years
* taking into account that some entry/exit codes may be part of group of PC8 codes

	foreach y of local pcyr {
		use temp_exit_entry_`y'
			drop group
			rename new`y' group
			replace group=. if entry!=1
			replace group = obs`y' if exit==1
			keep group
			gen exit=1
			format group %15.0f
			format exit %15.0f
			rename group group`y'
			sort group`y'
		save temp_exit_`y', replace
		}

	use setyr_PC_`b'_`e', clear
		save temp, replace
		
		foreach y of local pcyr {
			sort group`y'
			merge group`y' using temp_exit_`y', update
			tab _m
			drop if _m==2
			drop _m
			}
		
		tab exit
		bysort setyr: egen temp = max(exit)
		tab temp
			* all codes with the same setyr as the codes that exit also need to be dropped for consistency over time
			keep if temp==1
			drop exit
			rename temp exit
		save temp, replace
			* file with all exit codes that feature in concordance file, we need to append file with original codes
			* some codes that exit may not feature in the setyr file (if they have not changed over time)
	
	* we want files with exit codes that need to be dropped from data for consistency over time
	
		forval y = `b'/`e' {	
			use temp, clear
				keep group`y' exit
				capture append using temp_exit_`y'
				duplicates drop
				count
					* number of PC8 codes that needs to be dropped for consistency over time
					* specific to chosen time period (if sample period changes, files should be run again)
				rename group`y' pc8
				sort pc8
				save exit_`y', replace
				}
		
		
****************************************************************************	
*** Step 6: Generate overall concordance file for implementation in data ***
****************************************************************************			
		
* merge entry/exit codes with final concordance (to know which PC8 codes need to be dropped for consistent coverage over time)

	foreach y of numlist `b'/`e' {
			use setyr_PC_`b'_`e', clear
			keep group`y' setyr 
			rename group`y' group
			sort group
			drop if group==.
			
			save setyr_PC_`y', replace
			
		use PC_`y', clear
			destring pc, replace
			rename pc group
			sort group
			merge group using setyr_PC_`y'
			tab _m
				* _m==2 should not occur
			rename group pc8
			rename setyr pc8plus
			keep pc8 pc8plus
			duplicates drop
			sort pc8
			count if pc8==pc8[_n-1]
				* should not occur
			
			merge pc8 using exit_`y'
			drop if _m==2
			tab exit
			drop _m
			gen year=`y'
			sort pc8
			save temp_`y', replace
			}
	
	use temp_`b', clear
		forval y = `b1' / `e' {
			append using temp_`y'
			}
		sort pc8 year
		gen synthetic = (pc8plus!=.)
		replace pc8plus = pc8 if pc8plus==.
		count if pc8==pc8[_n-1] & year==year[_n-1]
	save "output\pc8_pc8plus_`b'_`e'", replace
	outsheet using "output\pc8_pc8plus_`b'_`e'.csv", replace

***************************************************
*** Step 4: Concording domestic production data ***
***************************************************	
/* Procedure:
		A/ Read in domestic production data for the period `b' - `e'
		B/ Rename the variable recording the original (unconcorded) PC8 products as "pc8"
		C/ Make sure the pc8 variable is string in the production data and sort on "pc8"
		D/ Recode optional (B-list) codes into mandatory codes (provided they feature in data)
			Perform a many-one merge on "pc8" with the file "optional_codes_`b'_`e'_sample"
			If _m==3, replace pc8 with the mandatory code (pc_mand). Drop pc_mand and merge variables.
			
		E/ Recode optional (N-list) codes into mandatory codes (provided they feature in the data)
			Perform a many-one merge on "pc8" with the file "Nlist_codes_1993_2005" 
			If _m==3, replace pc8 with the mandatory code (pc_mand). Drop pc_mand and merge variables.
		
		D/ Destring the PC8 variable (replace). If the destring procedure fails, there are still non-numeric characters in the PC8 codes.
			This should not occur (only N, T, Z, Q and E codes are non-numeric, they should not feature in the data at this point. 
			Verify which codes are causing the problem and address accordingly.
			
		E/ Perform a many-one merge on "pc8" and "year" (numeric format) with the file "cn8_cn8plus_`b'_`e'"
		E/ In principle, all PC8 codes that appear in the data should feature in the concordance
			* If some PC8 codes do not feature in concordance, this could be due to reporting errors or "residual" categories
			* Unmatched PC8 codes need to be dropped (no corresponding PC8+ code)
		F/ Aggregate the data from PC8 product level to PC8+ level (if data are at firm-product level, aggregate from firm-PC8 to firm-PC8+)
*/		

/* Example: Belgian product-level (PC8) panel production data 

	* Recode optional codes and N-list codes where necessary
		* Using list of optional codes generated above
		* Blist and Nlist: first prepare files
		
		if `b' < 2005 {
			use Nlist_codes_1993_2005, clear
				sort pc8
				count if pc8==pc8[_n-1]
			save temp_nlist, replace
			
			use optional_codes_`b'_`e'_sample, clear
				duplicates drop
				sort pc8
				count if pc8==pc8[_n-1]
			save temp_blist, replace
			}
			
	* merge with data
		* Select production data
					
			use production_pt_`b'_`e', clear
				
				label var lev3v_prod "Production value sold"
				label var prodcom "PC8 product, string"
				label var mioQ "Production value sold, mio"
			
				sort year prodcom
				count if year==year[_n-1] & prodcom==prodcom[_n-1]
				rename prodcom pc8
				
			if `b' < 2005 {	
				* merge with list of N-codes to recode if applicable
					merge pc8 using temp_nlist
					capture table pc8 if _m==3, c(count lev3v_prod sum lev3v_prod sum mioQ) format(%20.2fc) row
					replace pc8 = pc_mand if _m==3
					drop if _m==2
					drop _m pc_mand
				
				* merge with list of B-codes to recode if applicable
					merge pc8 using temp_blist
					drop if _m==2
					capture table pc8 if _m==3, c(count lev3v_prod sum lev3v_prod sum mioQ) format(%20.2fc) row
					replace pc8 = pc_mand if _m==3
					drop pc_mand
					drop _m
			
				}
				
				destring pc8, replace
				sort year pc8
				
				count if year==year[_n-1] & pc8==pc8[_n-1]
					* due to recoding, there might be doubles, need to be collapsed
					* e.g. two optional codes that map into one mandatory code
		
			if `b' < 2005 {	
				collapse (sum) lev3v_prod mioQ, by(year pc8)
					* only mandatory PC8 codes left in the data
					* these should all feature in the concordance (exception: coding errors, residual (country-specific) categories)
				}
				
				* concording PC8 products in each year (merge data with only mandatory products with concordance files
				
					sort pc8 year
					merge pc8 year using "output\pc8_pc8plus_`b'_`e'"
					tab _m
					replace exit=0 if exit==.
					table pc8 if _m==1, c(count year sum mioQ sum lev3v_prod) format(%20.2fc) row
					table exit, c(count pc8 sum mioQ sum lev3v_prod) format(%20.2fc) row
					table _m, c(count year sum mioQ sum lev3v_prod) format(%20.2fc) row
					
					* drop PC8 products not recognized in concordance (coding errors, residual categories)
						keep if _m==3
					
					* drop PC8 products that need to be dropped for consistency over time
						drop if exit==1
						
					* collapse to PC8+ level if applicable
						tab year
						sort year pc8plus
						count if year==year[_n-1] & pc8plus==pc8plus[_n-1]
						collapse (sum) lev3v_prod mioQ, by(year pc8plus)
						tab year 
					save production_pt_concorded_`b'_`e', replace
				
			*/
			


log close

erase PC_setyr_`b'_`e'.dta
erase output_file_PC_`b'_`e'_setyr.dta
erase temp.dta
erase temp2_xchain.dta
erase input_file_PC_over_time_edited.dta
!erase temp_blist.dta
!erase temp_nlist.dta
erase setyr_PC_`b'_`e'.dta

forval x=`b'/`e' {
	erase exit_`x'.dta
	erase prodcom_PC_`x'_concorded.dta
	erase junk_x_`x'.dta
	erase setyr_PC_`x'.dta
	erase PC2_`x'.dta
	erase temp_new_`x'.dta
	erase temp_obsolete_`x'.dta
	!erase temp_`x'.dta
	}

foreach x of local pcyr {
	erase temp_exit_`x'.dta
	!erase temp_`x'.dta
	erase temp_exit_entry_`x'.dta
	erase temp_xchain_`x'.dta
	erase temp2_`x'.dta
	erase temp2_xchain_`x'.dta
	}
	
