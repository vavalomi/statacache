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
		return local signature = `"`signature'"'
		return local restype="file" // as opposed to "memory"
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
		return local restype="file" // as opposed to "memory"
		exit
	}
	sleep 5000

	tempfile aa
	getdataheavy, country(`country') indicator(`indicator') target(`aa')
	use `aa', `clear'
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

clear
datacache: getdataheavy , target(c:\temp\getheavy.dta) country() indicator(SP.POP.TOTL) replace

clear
datacache : example_memory , country() indicator(SP.POP.TOTL)

clear
datacache , : example_any, country() indicator(SP.POP.TOTL)

// END OF FILE