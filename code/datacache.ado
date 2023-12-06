/*
    In order for a (user-written) program to be cachable it needs to setisfy the following:
    1. define program properties and include 'cachable' in the list: properties(cachable)
    2. be an r-class program which implements syntax-based parameter parsing.
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

	gettoken cacheoptions subcmd : 0, parse(": ")
    if "`cacheoptions'" == ":" {
        local cacheoptions
    }
    else {
    	gettoken trash subcmd : subcmd, parse(": ")
    }

	display `"`subcmd'"'
    if strpos("`subcmd'", ",") == 0 local subcmd1 "`subcmd',"
    else local subcmd1 "`subcmd'"

    gettoken cmdname cmdline : subcmd1, parse(", ")
    local props : properties `cmdname'
    local 0  ", `props'"
    syntax, [cachable Disk Frame MEMory *]

    if "`cachable'" == "" {
        display as text "NON-CACHABLE command, execute and exit"
        `subcmd'
        exit
    }
    // get the command signature
	`subcmd1' signature

    local unique_signature "`cmdname'|`r(signature)'"
	mata st_local("fname", urlencode(base64encode(st_local("unique_signature"))))
	mata st_local("cached_dataset", pathjoin("`storage'", "`fname'.dta"))

    local option_name : word 1 of "`options'"
    if "`frame'" != "" {
        local prog_type "FRAME"
    }
    else if "`disk'" != "" {
        local prog_type "DISK"
    }

    if "`prog_type'" != "" {
        // we need to parse cmdline content to get the parameter value
        local 0 : copy local cmdline
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
        // current memory option is equivalent of using the default frame
        local prog_type "FRAME"
        local frame_name "default"
    }

	if !fileexists("`cached_dataset'") {
	    `subcmd'
        if "`prog_type'" == "FRAME" {
            frame `frame_name' {
                save "`cached_dataset'", replace
                global S_FN
                global S_FNDATE
            }
        }
        else if "`prog_type'" == "DISK" {
            copy "`result_dataset'" "`cached_dataset'", replace
        }
    
	    display as text "STORED TO CACHE: " as result `"[`fname']"'
    }
	else {
        if "`prog_type'" == "FRAME" {
            capture frame create `frame_name'
            frame `frame_name': use "`cached_dataset'", `clear'
        }
        else if "`prog_type'" == "DISK" {
            copy "`cached_dataset'" "`result_dataset'", `replace'
        }

		display as text "RETRIEVED FROM CACHE: " as result `"[`fname']"'
	}
end

program define load_settings
    local personal_dir : sysdir PERSONAL
    local settings_file "`personal_dir'datacache_settings.do"

    if fileexists("`settings_file'") == 0 {
        save_settings
    }

    include "`settings_file'"
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
