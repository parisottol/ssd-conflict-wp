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
* Conflict exposure
*****************************************************
*prepare list of households in survey by admin level
use "${Raw}\Boma_NBHS.dta", clear
rename (cluster hhid) (ea hh)
*replace april 1st as NBHS 2009 data
gen today=td(01042009)
gen wave=0
*append with HFS data
append using "${Raw}\Boma_HFS.dta"
drop dataset
save "${Raw}\Boma_HFS_NBHS.dta", replace
*merge with ACLED data
import excel using "${Raw}/ACLED_Boma_2008-2017.xls", clear first
keep STATE COUNTY PAYAM BOMA latitude longitude geo_precis fatalities event_date time_preci event_type 
rename (STATE COUNTY PAYAM BOMA) (State County Payam Boma)
foreach v of varlist State County Payam Boma {
	replace `v' = strtrim(strupper(`v'))
}
order fatalities, last
*filter events by date
gen date=date(event_date,"DMY")
drop event_date geo_preci time_preci
rename date event_date
format event_date %td
order event_date, after(longitude)
*keep relevant time period - after 2013 conflict
keep if inrange(event_date,td(01122013),td(01122017))
*merge with household data and dates
rename (latitude longitude) (latitude_event longitude_event)
**************************
*aggregate at the Payam level
joinby State County Payam using "${Raw}/Boma_HFS_NBHS.dta", unmatched(using) 
**************************
drop _merge lat* long*
order wave state ea hh , first
*use months instead of day date to account for potentially inaccurate reporting of dates
gen m_int=mofd(today)
gen m_ev=mofd(event_date)
save "${Raw}/conflict_events_hh.dta", replace
*/
*****************************************************
* Conflict exposure stats
*****************************************************
use "${Raw}/conflict_events_hh.dta", clear
drop if !inrange(m_ev,tm(2013m12),m_int) & inlist(wave,3)
drop if !inrange(m_ev,tm(2013m12),tm(2017m2)) & wave==0
keep if inlist(wave,3)
assert m_int>=m_ev
*months
gen months_since=m_int-m_ev+1
hist months_since, discr freq xtitle("Months since conflict event") graphregion(style(none) color(white))
mean months_since
collapse (min) months_since, by(state ea hh)
mean months_since
cumul months , gen(c)
sort c
line c months , ytitle("Cumulative density") xtitle("Months since LAST conflict event") graphregion(style(none) color(white))

*****************************************************
* Stats per Payam
*****************************************************
import excel using "${Raw}/ACLED_Boma_2008-2017.xls", clear first
keep STATE COUNTY PAYAM BOMA latitude longitude geo_precis fatalities event_date time_preci event_type 
rename (STATE COUNTY PAYAM BOMA) (State County Payam Boma)
foreach v of varlist State County Payam Boma {
	replace `v' = strtrim(strupper(`v'))
}
order fatalities, last
*filter events by date
gen date=date(event_date,"DMY")
drop event_date geo_preci time_preci
rename date event_date
format event_date %td
order event_date, after(longitude)
*keep relevant time period - after 2013 conflict
keep if inrange(event_date,td(01122013),td(01122017))
*events per Payam
collapse (count) events=fatalities , by(State County Payam)
hist events ,  bin(40)  freq xtitle("Number of conflict events per Payam")  graphregion(style(none) color(white))
*/


*****************************************************
* Conflict exposure sums
*****************************************************
use "${Raw}/conflict_events_hh.dta", clear
keep if inlist(wave,0,3)
drop if !inrange(m_ev,tm(2013m12),m_int) & inlist(wave,3)
drop if !inrange(m_ev,tm(2013m12),tm(2017m2)) & wave==0
*baseline conflict definition
encode event_type,gen(type)
mean fatalities, over(type)
numlabel type, add
keep if inlist(type,1,2,3,6,9)
gen violence_civilians=inlist(type,9)
gen battle=inlist(type,1,2,3,6)
gen events=1
gen deadly=fatalities>0
gen intense=fatalities>15
collapse (sum) events deadly intense fatalities battle violence_civilians, by(wave state ea hh)
*merge again with full set of households
merge 1:1 wave state ea hh using "${Raw}/Boma_HFS_NBHS.dta", nogen assert(match using) keepusing(County Payam Boma) 
encode County, gen(county)
encode Payam, gen(payam)
encode Boma, gen(boma)
drop County Payam Boma
ds wave state ea hh, not
*replace zeros for non-conflict affected households
foreach v in `r(varlist)' {
	replace `v' = 0 if missing(`v')
}
drop if inlist(wave,1,2,4)
save "${Raw}/conflict_indicators_sum.dta", replace 
*/

*****************************************************
* Conflict exposure time
*****************************************************
use "${Raw}/conflict_events_hh.dta", clear
keep if inlist(wave,0,3)
drop if !inrange(m_ev,tm(2013m12),m_int) & inlist(wave,3)
drop if !inrange(m_ev,tm(2013m12),tm(2017m2)) & wave==0
assert m_ev>m_int if wave==0
assert m_ev<=m_int if wave==3
*time between interview and last event
gen time=m_int-m_ev+1
replace time=0 if wave==0
gen events=1
collapse (sum) events (min) time, by(wave state ea hh)
*merge again with full set of households
merge 1:1 wave state ea hh using "${Raw}/Boma_HFS_NBHS.dta", nogen assert(match master using) keep(match using) keepusing(County Payam Boma) 
drop County Payam Boma
ds wave state ea hh, not
*replace zeros for non-conflict affected households
foreach v in `r(varlist)' {
	replace `v' = 0 if missing(`v')
}
drop if inlist(wave,1,2,4)
save "${Raw}/conflict_indicators_time.dta", replace 

