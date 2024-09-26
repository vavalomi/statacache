clear all

// cachable command that saves results to a file
program define getdataheavy, rclass properties(cachable disk target)
    version 17.0

    syntax , [signature]        ///
	/* native syntax follows: */     ///
	[target(string) country(string) indicator(string) replace]
	
	if "`signature'" != "" {
		// form signature as canonical options list
		local signature=`"country(`country')|indicator(`indicator')"'
		return local signature `"`signature'"'
		exit
	}
	display `"`target'"' "from" `"`0'"'
	
	// acquire file via API to get data from options and to save to -target()-
	//copy "https://myserver.com/getdata?year=`year'&country=`country'"

	tempname tf
	frame create `tf'
	frame `tf' {
	  wbopendata, country(`country') indicator(`indicator') clear
	  save `"`target'"', `replace'
	}
end

// cachable command that leaves data memory
program define example_memory, rclass properties(cachable)
    syntax , [signature]        ///
	/* native syntax follows: */     ///
	[country(string) indicator(string) clear]

	if "`signature'" != "" {
		// form signature as canonical options list
		local signature=`"country(`country')|indicator(`indicator')"'
		return local signature = `"`signature'"'
		exit
	}
	sleep 5000

	tempfile aa
	getdataheavy, country(`country') indicator(`indicator') target(`aa')
	use `aa', `clear'
	return local aaa "there is a text"
	return scalar d = 3
end

// non-achable comand
program define example_any, rclass
	// this command doesn't define properties so even if it saves datafiles
	// or leaves data in memory, -datacache- will ignore that and run at every call

	// imitate slow process
	sleep 5000

	sysuse auto, clear
end

capture program drop datacache
timer clear
clear

timer on 1
datacache: getdataheavy , target(c:\temp\getheavy.dta) country(ALB) indicator(SP.POP.TOTL) replace
confirm file c:\temp\getheavy.dta
timer off 1

clear
timer on 2
datacache : example_memory , country(ALB) indicator(SP.POP.TOTL)
describe, short
timer off 2

clear
timer on 3
datacache : example_any
describe, short
timer off 3

clear
timer on 4
datacache, memory signature("aa") : example_any
describe, short
timer off 4

timer list

// END OF FILE