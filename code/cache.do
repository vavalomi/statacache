clear all

program define cache

    version 17.0
	local storage="C:\TEMP\CACHE"
	
	gettoken cacheoptions subcmd : 0, parse(":")
	gettoken trash subcmd : subcmd, parse(":")

	display `"`subcmd'"'
	
	`subcmd' // relies on comma to be mentioned somewhere before the options
	local sg=`"`r(signature)'"'
	
	mata st_local("fname",urlencode(base64encode(st_local("sg"))))
	mata st_local("target", pathjoin("`storage'", "`fname'"))
	
	if (!fileexists(`"`target'.dta"')) {
	    `subcmd' target(`"`target'"')
	    display as text "STORED TO CACHE: " as result `"[`fname']"'
    }
	else {
		display as text "RETRIEVED FROM CACHE: " as result `"[`fname']"'
	}
	
	use `"`target'"'
end

program define getdataheavy, rclass
    version 17.0

    syntax , [target(string)]        ///
	/* native syntax follows: */     ///
	[country(string) indicator(string)]
	
	if (`"`target'"'=="") {
		// form signature as canonical options list
		local signature=`"country(`country')|indicator(`indicator')"'
		return local signature=`"`signature'"'
		return local restype="file" // as opposed to "memory"
		exit
	}
	display `"`target'"' "from" `"`0'"'
	
	// acquire file via API to get data from options and to save to -target()-
	//copy "https://myserver.com/getdata?year=`year'&country=`country'"

	local cf `"`c(frame)'"'
	tempname tf
	frame create `tf'
	frame change `tf'
	  wbopendata, country(`country') indicator(`indicator') clear
	  save `"`target'"'
	frame change `cf'
	frame drop `tf'
end

clear
cache , : getdataheavy , country() indicator(SP.POP.TOTL)
clear
cache , : getdataheavy , country() indicator(SP.POP.TOTL)
clear
cache , : getdataheavy , country() indicator(SP.POP.TOTL)

// END OF FILE