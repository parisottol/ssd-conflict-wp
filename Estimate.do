clear all
set more off
set maxvar 10000
set seed 234534543 

*****************************************************
* Define filepaths
*****************************************************
global Code = "C:\Users\WB502620\OneDrive - WBG\South Sudan\Conflict_WP\Code"
global Raw = "C:\Users\WB502620\OneDrive - WBG\South Sudan\Conflict_WP\Code\Data"
global Output = "C:\Users\WB502620\OneDrive - WBG\South Sudan\Conflict_WP\Code/Output"

*****************************************************
* Analysis
*****************************************************
*Bootstrap?
use "${Code}/Conflict.dta", clear
replace livelihood=2 if livelihood==3
local controls = " hhsize sleeping_rooms head_age head_sex  i.toilet i.livelihood i.watersource i.lighting i.cooking i.dwelling i.head_education"
gen ag=livelihood==1
label define lag 0 "Non-agriculture" 1 "Agriculture"
label val ag lag

*gen w=pweight*_weights_rcs
*svyset ea [pw=w], strata(stratum) 

replace food_prod=food_prod+food_stock if wave==0
gen fp=food_prod/ae
gen share_prod=fp/ct
replace share_prod=. if share_prod>1
svy: mean share_prod, over(post conflict)
gen lfp=ln(1+food_prod)
gen prod=food_prod>0

*svy: reg lct i.post i.conflict i.prod `controls' state#urban#post

merge 1:1 wave state ea hh using "${Raw}/conflict_indicators_time.dta", nogen assert(match master using) keep(match master) 

*create time bins
gen last=0
forvalue i=0(3)42 {
	local j=1+`i'
	local k=3+`i'
	replace last=`k' if inrange(time,`j',`k')
}
* arrange based on number of interviews
replace last=1 if time==1
replace last=12 if last==9
replace last=18 if last==15
replace last=24 if inrange(time,19,42)
tab time last

svy : reg lct post conflict i.last `controls' state#post#urban



BREAK
preserve 
keep if wave==0
bsweights bw , reps(100) n(1)
tempfile d09
save `d09'
restore
keep if wave==3
bsweights bw , reps(100) n(1)
append using `d09'
svyset ea [pw=pweight], strata(stratum) vce(bootstrap) bsrweight(bw*)
save "${Code}/Conflict_bsr.dta", replace
*/
use "${Code}/Conflict_bsr.dta", clear
svyset ea [pw=pweight], strata(stratum) vce(bootstrap) bsrweight(bw*)
local controls = " hhsize sleeping_rooms head_age head_sex i.livelihood i.toilet i.watersource i.lighting i.cooking i.dwelling i.head_education"

/*average decline in consumption
svy: mean ct , over(post)
di ([ct]Pre-[ct]Post)/[ct]Pre
*2009 difference in consumption
svy: mean ct if post==0, over(conflict)
di ([ct]Conflict-[ct]Control)/[ct]Control
* Baseline DD Estimation
svy: mean ct, over(post conflict)
lincom [ct]_subpop_1-[ct]_subpop_2
lincom [ct]_subpop_3-[ct]_subpop_4
lincom [ct]_subpop_1-[ct]_subpop_3
lincom [ct]_subpop_2-[ct]_subpop_4
lincom ([ct]_subpop_1-[ct]_subpop_2) - ([ct]_subpop_3-[ct]_subpop_4)
di (([ct]_subpop_1-[ct]_subpop_2) - ([ct]_subpop_3-[ct]_subpop_4))/[ct]_subpop_2
*intracluster correlation of price indexz
loneway price_index stratum if wave==3
*/

*****************************************************
* REGRESSION DD
*****************************************************
* Dummy
local controls = " hhsize sleeping_rooms head_age head_sex i.livelihood i.toilet i.watersource i.lighting i.cooking i.dwelling i.head_education"
*baseline 
quietly svy: reg lct i.post##i.conflict 
outreg2 using "${Output}/reg_main.xls", replace ctitle(ln tot. cons) addtext(Controls, NO, State-urban time trends, NO) label nocons keep(i.post##i.conflict)
*controls 
quietly svy: reg lct i.post##i.conflict `controls'
outreg2 using "${Output}/reg_main.xls", append ctitle(ln tot. cons) addtext(Controls, YES, State-urban time trends, NO) label nocons keep(i.post##i.conflict)
*FE only
quietly svy: reg lct i.post##i.conflict stratum#post
outreg2 using "${Output}/reg_main.xls", append ctitle(ln tot. cons) addtext(Controls, NO, State-urban time trends, YES) label nocons keep(i.post##i.conflict)
*Full 
quietly svy: reg lct i.post##i.conflict `controls' stratum#post
outreg2 using "${Output}/reg_main.xls", append ctitle(ln tot. cons) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.conflict)
* Treatment intensity DD - dummies
*baseline 
quietly svy: reg lct i.post##i.c 
outreg2 using "${Output}/reg_main.xls", append ctitle(ln tot. cons) addtext(Controls, NO, State-urban time trends, NO) label nocons keep(i.post##i.c)
*controls 
quietly svy: reg lct i.post##i.c `controls'
outreg2 using "${Output}/reg_main.xls", append ctitle(ln tot. cons) addtext(Controls, YES, State-urban time trends, NO) label nocons keep(i.post##i.c)
*FE only
quietly svy: reg lct i.post##i.c stratum#post
outreg2 using "${Output}/reg_main.xls", append ctitle(ln tot. cons) addtext(Controls, NO, State-urban time trends, YES) label nocons keep(i.post##i.c)
*Full 
quietly svy: reg lct i.post##i.c `controls' stratum#post
outreg2 using "${Output}/reg_main.xls", append ctitle(ln tot. cons) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.c)
*/

*****************************************************
* Quantile DD Estimation
*****************************************************
*Only full mode 
local dep1 = "lct"
local controls = " hhsize sleeping_rooms head_age head_sex i.livelihood i.toilet i.watersource i.lighting i.cooking i.dwelling i.head_education "
local spec1 = " "
local spec2 = "`controls' "
local spec3 = "`controls' i.post#i.stratum "
foreach n in 1 {
	foreach l in 3 {
	qreg `dep`n'' i.post##i.conflict `spec`l'' [pw=pweight]  , q(.1) nolog vce(robust)
	outreg2 using "${Output}/qreg`n'`l'.xls", replace ctitle(.1) label keep(i.post##i.conflict) nocons 
		foreach q in .25 .5 .75 .9 {
			qreg `dep`n'' i.post##i.conflict `spec`l'' [pw=pweight]  , q(`q') nolog vce(robust)
			outreg2 using "${Output}/qreg`n'`l'.xls", append ctitle(`q') label keep(i.post##i.conflict) nocons 
		}
	}
}
foreach n in 1 {
	foreach l in 3 {
	qreg `dep`n'' i.post##i.c `spec`l'' [pw=pweight] , q(.1) nolog vce(robust)
	outreg2 using "${Output}/qreg`n'`l'_c.xls", replace ctitle(.1) label keep(i.post##i.c) nocons 
		foreach q in .25 .5 .75 .9 {
			qreg `dep`n'' i.post##i.c `spec`l'' [pw=pweight] , q(`q') nolog vce(robust)
			outreg2 using "${Output}/qreg`n'`l'_c.xls", append ctitle(`q') label keep(i.post##i.c) nocons 
		}
	}
}
*/
*****************************************************
/* Robustness
*****************************************************
local controls = " hhsize sleeping_rooms head_age head_sex i.livelihood i.toilet i.watersource i.lighting i.cooking i.dwelling i.head_education"
*IDPs 
tab wave idp 
quietly svy: reg lct i.post##i.conflict `controls' stratum#post if idp==0
outreg2 using "${Output}/reg_robustness.xls", replace ctitle(IDPs) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.conflict)
quietly svy: reg lct i.post##i.c `controls' stratum#post if idp==0
outreg2 using "${Output}/reg_robustness.xls", append ctitle(IDPs) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.c)
*Aid
svy: mean f_aid, over(wave conflict)
lincom [f_aid]_subpop_1-[f_aid]_subpop_2
lincom [f_aid]_subpop_3-[f_aid]_subpop_4
svy: mean nf_aid, over(wave conflict)
quietly svy: reg lct_noaid i.post##i.conflict `controls' stratum#post 
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Aid) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.conflict)
quietly svy: reg lct_noaid i.post##i.c `controls' stratum#post 
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Aid) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.c)
*Consumption items
svy: mean f_mod, over(wave conflict)
lincom [f_mod]_subpop_1-[f_mod]_subpop_2
lincom [f_mod]_subpop_3-[f_mod]_subpop_4
svy: mean nf_mod, over(wave conflict)
lincom [nf_mod]_subpop_1-[nf_mod]_subpop_2
lincom [nf_mod]_subpop_3-[nf_mod]_subpop_4
quietly svy: reg lct_mod i.post##i.conflict `controls' stratum#post 
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Modules) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.conflict)
quietly svy: reg lct_mod i.post##i.c `controls' stratum#post 
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Modules) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.c)
*just urban 
xtile cu=fatalities [pw=pweight] if events>0 & urban==1, nq(3)
replace cu=0 if events==0
quietly svy: reg lct i.post##i.conflict `controls' stratum#post if urban==1
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Urban) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.conflict)
quietly svy: reg lct i.post##i.cu `controls' stratum#post  if urban==1
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Urban) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.cu)
*just rural 
xtile cr=fatalities [pw=pweight] if events>0 & urban==0, nq(3)
replace cr=0 if events==0
quietly svy: reg lct i.post##i.conflict `controls' stratum#post if urban==0
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Rural) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.conflict)
quietly svy: reg lct i.post##i.cr `controls' stratum#post  if urban==0
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Rural) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.cr)
local controls = " hhsize sleeping_rooms head_age head_sex i.livelihood i.toilet i.watersource i.lighting i.cooking i.dwelling i.head_education"
*Price index
quietly svy: reg lct i.post##i.conflict price_index `controls' stratum#post 
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Price index) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.conflict)
quietly svy: reg lct i.post##i.c  price_index `controls' stratum#post 
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Price index) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.c)
*Matching
gen w=pweight*_weights_rcs
*create weights for estimation
*foreach w in bsr* {
*	replace bsr=`w'*_weights_rcs
*}
svyset ea [pw=w], strata(stratum) vce(bootstrap) bsrweight(bw*)
quietly svy: reg lct i.post##i.conflict `controls' stratum#post if _support==1
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Match) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.conflict)
quietly svy: reg lct i.post##i.c `controls' stratum#post if _support==1
outreg2 using "${Output}/reg_robustness.xls", append ctitle(Match) addtext(Controls, YES, State-urban time trends, YES) label nocons keep(i.post##i.c)
*/

