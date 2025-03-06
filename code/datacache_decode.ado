program define datacache_decode
    args filepath

    mata: st_local("signature", base64decode(urldecode(pathrmsuffix(pathbasename(st_local("filepath"))))))

    display "`signature'"
end
