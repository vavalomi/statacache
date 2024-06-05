/*
    In order for a (user-written) program to be cachable it needs to setisfy the following:
    1. define program properties and include 'cachable' in the list: properties(cachable)
    2. be an r-class, e-class, or s-class program which implements syntax-based parameter parsing.
    3. accept 'signature' option that returns signature text, which would uniquely identify the resulting data
    4.1. if results are left in memory, specify properties(cachable MEMory)
    4.2. if results are left in a frame, specify properties(cachable frame option_name)
    4.3. if results are saved to a file on disk, specify properties(cachable disk option_name)
    if none of the above are provided, memory option would be assumed by default
    option_name means that destination frame name or file path should be read from the option_name() parameter of the call
*/

program define datacache

    version 17.0

    load_settings
    local storage "`r(storage)'"

	gettoken cacheoptions subcmd : 0, parse(":")
    if "`cacheoptions'" == ":" {
        local cacheoptions
    }
    else {
    	gettoken trash subcmd : subcmd, parse(": ")
    }

    local 0 : copy local cacheoptions
    syntax , [nocache update Disk Frame MEMory option_name(string) signature(string)]


    if "`cache'" == "nocache" {
        if "$DATACACHE_VERBOSE" != "" {
            display as text "nocache option received, execute and exit"
        }
        noisily capture `subcmd'
        exit `=_rc'
    }

    if "$DATACACHE_VERBOSE" != "" {
	    display `"`subcmd'"'
    }

    if strpos(`"`subcmd'"', ",") == 0 local subcmd1 "`subcmd',"
    else local subcmd1 "`subcmd'"
    gettoken cmdname cmdline : subcmd1, parse(", ")

    if "`disk'`frame'`memory'`option_name'`signature'" == "" {
        // no direct parameters were provided, let's see if the command itself
        // defines them

        local props : properties `cmdname'
        local 0  ", `props'"
        syntax, [cachable Disk Frame MEMory *]
        local option_name : word 1 of "`options'"
    }
    else {
        local cachable "cachable"
    }

    if "`cachable'" == "" {
        if "$DATACACHE_VERBOSE" != "" {
            display as text "NON-CACHABLE command, execute and exit"
        }
        noisily capture `subcmd'
        exit `=_rc'
    }

    local results : results `cmdname'

    if "`signature'" == "" {
        // get the command signature

        if "`results'" == "nclass" {
            if "$DATACACHE_VERBOSE" != "" {
                display as text "command doesn't implement signature, execute and exit"
            }
            noisily capture `subcmd'
            exit `=_rc'
        }
        else {
            local signature_macro = subinstr("`results'", "class", "", .) + "(signature)" // r(signature), e(signature), or s(signature)
        }

        `subcmd1' signature
    }
    else {
        local signature_macro "signature"
    }

    local unique_signature "`cmdname'|``signature_macro''"
	mata st_local("fname", urlencode(base64encode(st_local("unique_signature"))))
	mata st_local("cached_dataset", pathjoin("`storage'", "`fname'.dta"))
    local returns_file : subinstr local cached_dataset ".dta" ".ret"

    if "`frame'" != "" {
        local prog_type "FRAME"
    }
    else if "`disk'" != "" {
        local prog_type "DISK"
    }

    local 0 : copy local cmdline
    if "`prog_type'" != "" {
        // we need to parse cmdline content to get the parameter value
        // option_name is required so this command would correctly catch that
        // =exp and weights cannot be present at the same time, so need to check twice
        capture syntax [anything] [if] [in] [using/] [fweight  aweight  pweight  iweight], `option_name'(string asis) [clear replace *]
        if _rc {
            syntax [anything] [if] [in] [using/] [=exp], `option_name'(string asis) [clear replace *]
        }
        if "`prog_type'" == "FRAME" {
            local frame_name "``option_name''"
        }
        else {
            local result_dataset "``option_name''"
        }
    }
    else {
        capture syntax [anything] [if] [in] [using/] [fweight  aweight  pweight  iweight], [clear replace *]
        if _rc {
            syntax [anything] [if] [in] [using/] [=exp], [clear replace *]
        }
        // current memory option is equivalent of using the default frame
        local prog_type "FRAME"
        local frame_name "default"
    }

	if !fileexists("`cached_dataset'") | "`update'" == "update" {
	    noisily capture `subcmd'
        if _rc {
            exit `=_rc'
        }
        if "`prog_type'" == "FRAME" {
            frame `frame_name' {
                char _dta[version] $S_DATE
                quietly save "`cached_dataset'", replace
                global S_FN
                global S_FNDATE
            }
        }
        else if "`prog_type'" == "DISK" {
            quietly {
                use "`result_dataset'"
                char _dta[version] $S_DATE
                copy "`result_dataset'" "`cached_dataset'", replace
            }
        }
        quietly save_returned "`results'" "`returns_file'"
    
	    if "$DATACACHE_VERBOSE" != "" {
            display as text "STORED TO CACHE: " as result `"[`fname']"'
        }
    }
	else {
        if "`prog_type'" == "FRAME" {
            capture frame create `frame_name'
            frame `frame_name': use "`cached_dataset'", `clear'
        }
        else if "`prog_type'" == "DISK" {
            quietly copy "`cached_dataset'" "`result_dataset'", `replace'
        }
        load_returned "`results'" "`returns_file'"
        if "$DATACACHE_VERBOSE" != "" {
		    display as text "RETRIEVED FROM CACHE: " as result `"[`fname']"'
        }
	}
end

program define load_settings
    local personal_dir : sysdir PERSONAL
    local settings_file "`personal_dir'datacache_settings.do"

    if fileexists("`settings_file'") == 0 {
        save_settings
    }

    quietly include "`settings_file'"
end

program define save_settings
    tempname fh

    local personal_dir : sysdir PERSONAL
    local settings_file "`personal_dir'datacache_settings.do"
    local storage_folder "`personal_dir'.datacache_storage"
    file open `fh' using "`settings_file'", text write
    file write `fh' "/* " _n
    file write `fh' "Location where the cached datasets will be saved." _n
    file write `fh' "The cache content will be managed by -datacache- command and may be cleared or modified" _n
    file write `fh' "at any time. Thus, please do not use directly or rely on the data to always be here." _n
    file write `fh' _n
    file write `fh' "There is no value in storing the folder in cloud-managed (OneDrive, Google Drive, etc) location" _n
    file write `fh' "and those systems may prevent access by -datacache- so it is better to use, local folder." _n
    file write `fh' "*/"
    file write `fh' _n
    file write `fh' `"datacache_settings, storage("`storage_folder'")"' _n
    // any other parameters we may later add
    file close `fh'
end

program define datacache_settings, rclass
    syntax, storage(string)

    capture mkdir "`storage'"
    return local storage "`storage'"
end

program define save_returned
    args results tofile

    if "`results'" == "nclass" {
        // nothing to store
        exit
    }
    if "`results'" == "eclass" {
        estimates store `tofile', replace
        exit
    }

    tempname fh
    file open `fh' using `tofile', write text replace
    foreach sc in `: r(scalars)' {
        file write `fh' "return scalar `sc' = `=r(`sc')'" _n
    }
    foreach loc in `: r(macros)' {
        file write `fh' `"return local `loc' = "`=r(`loc')'""' _n
    }
    file close `fh'

end

program define load_returned
    args results fromfile

    if !fileexists("`fromfile'") {
        exit
    }

    if "`results'" == "eclass" {
        estimates use `fromfile'
    }
    else {
        tempname fh
        file open `fh' using `fromfile', read text    
        file read `fh' line
        if `"`line'"' == "" {
            exit
        }
        local lines `"`"`line'"'"'
        while r(eof)==0 {
            file read `fh' line
            local lines `"`lines' `"`line'"'"'
        }
        file close `fh'
        if "`results'" == "rclass" {
            post_return `lines'
        }
        else {
            post_sreturn `lines'
        }
    }
end

program define post_sreturn, sclass
    foreach line of local 0 {
        `line'
    }
end

program define post_return, rclass
    foreach line of local 0 {
        `line'
    }
end
