"======================================================================
"
" path.vim - 
"
" Created by skywind on 2018/04/25
" Last Modified: 2018/04/25 15:46:44
"
"======================================================================

let s:scriptname = expand('<sfile>:p')
let s:scripthome = fnamemodify(s:scriptname, ':h:h')
let s:windows = has('win32') || has('win64') || has('win16') || has('win95')

let asclib#path#windows = s:windows


"----------------------------------------------------------------------
" absolute path
"----------------------------------------------------------------------
function! asclib#path#abspath(path)
	let f = a:path
	if f =~ "'."
		try
			redir => m
			silent exe ':marks' f[1]
			redir END
			let f = split(split(m, '\n')[-1])[-1]
			let f = filereadable(f)? f : ''
		catch
			let f = '%'
		endtry
	endif
	let f = (f != '%')? f : expand('%')
	let f = fnamemodify(f, ':p')
	if s:windows != 0
		let f = substitute(f, "\\", '/', 'g')
	endif
	if len(f) > 1
		let size = len(f)
		if f[size - 1] == '/'
			let f = strpart(f, 0, size - 1)
		endif
	endif
	return f
endfunc


"----------------------------------------------------------------------
" check absolute path name
"----------------------------------------------------------------------
function! asclib#path#isabs(path)
	let path = a:path
	if strpart(path, 0, 1) == '~'
		return 1
	endif
	if s:windows != 0
		let head = strpart(path, 1, 2)
		if head == ':/' || head == ":\\"
			return 1
		endif
		let head = strpart(path, 0, 1)
		if head == "\\"
			return 1
		endif
	endif
	let head = strpart(path, 0, 1)
	if head == '/'
		return 1
	endif
	return 0
endfunc


"----------------------------------------------------------------------
" join two path
"----------------------------------------------------------------------
function! asclib#path#join(home, name)
    let l:size = strlen(a:home)
    if l:size == 0 | return a:name | endif
	if asclib#path#isabs(a:name)
		return a:name
	endif
    let l:last = strpart(a:home, l:size - 1, 1)
    if has("win32") || has("win64") || has("win16") || has('win95')
        if l:last == "/" || l:last == "\\"
            return a:home . a:name
        else
            return a:home . '/' . a:name
        endif
    else
        if l:last == "/"
            return a:home . a:name
        else
            return a:home . '/' . a:name
        endif
    endif
endfunc


"----------------------------------------------------------------------
" dirname
"----------------------------------------------------------------------
function! asclib#path#dirname(path)
	return fnamemodify(a:path, ':h')
endfunc


"----------------------------------------------------------------------
" normalize
"----------------------------------------------------------------------
function! asclib#path#normalize(path, ...)
	let lower = (a:0 > 0)? a:1 : 0
	let path = a:path
	if s:windows
		let data = split(path, "\\", 1)
		let path = join(data, '/')
	endif
	if lower && (s:windows || has('win32unix'))
		let path = tolower(path)
	endif
	let size = len(path)
	if path[size - 1] == '/'
		let path = strpart(path, 0, size - 1)
	endif
	return path
endfunc


"----------------------------------------------------------------------
" returns 1 for equal, 0 for not equal
"----------------------------------------------------------------------
function! asclib#path#equal(path1, path2)
	let p1 = asclib#path#abspath(a:path1)
	let p2 = asclib#path#abspath(a:path2)
	if s:windows || has('win32unix')
		let p1 = tolower(p1)
		let p2 = tolower(p2)
	endif
	if p1 == p2
		return 1
	endif
	return 0
endfunc


"----------------------------------------------------------------------
" path asc home
"----------------------------------------------------------------------
function! asclib#path#runtime(path)
	let pathname = fnamemodify(s:scripthome, ':h')
	let pathname = asclib#path#join(pathname, a:path)
	let pathname = fnamemodify(pathname, ':p')
	return substitute(pathname, '\\', '/', 'g')
endfunc


"----------------------------------------------------------------------
" find files in path
"----------------------------------------------------------------------
function! asclib#path#which(name)
	if has('win32') || has('win64') || has('win16') || has('win95')
		let sep = ';'
	else
		let sep = ':'
	endif
	for path in split($PATH, sep)
		let filename = asclib#path#join(path, a:name)
		if filereadable(filename)
			return asclib#path#abspath(filename)
		endif
	endfor
	return ''
endfunc


"----------------------------------------------------------------------
" find executable
"----------------------------------------------------------------------
function! asclib#path#executable(name)
	if s:windows != 0
		for n in ['', '.exe', '.cmd', '.bat', '.vbs']
			let nname = a:name . n
			let npath = asclib#path#which(nname)
			if npath != ''
				return npath
			endif
		endfor
	else
		return asclib#path#which(a:name)
	endif
	return ''
endfunc


"----------------------------------------------------------------------
" find project root
"----------------------------------------------------------------------
function! s:find_root(path, markers)
    function! s:guess_root(filename, markers)
        let fullname = vimmake#fullname(a:filename)
        if exists('b:asclib_path_root')
            return b:asclib_path_root
        endif
        if fullname =~ '^fugitive:/'
            if exists('b:git_dir')
                return fnamemodify(b:git_dir, ':h')
            endif
            return '' " skip any fugitive buffers early
        endif
		let pivot = fullname
		if !isdirectory(pivot)
			let pivot = fnamemodify(pivot, ':h')
		endif
		while 1
			let prev = pivot
			for marker in a:markers
				let newname = asclib#path#join(pivot, marker)
				if filereadable(newname)
					return pivot
				elseif isdirectory(newname)
					return pivot
				endif
			endfor
			let pivot = fnamemodify(pivot, ':h')
			if pivot == prev
				break
			endif
		endwhile
        return ''
    endfunc
	let root = s:guess_root(a:path, a:markers)
	if len(root)
		return asclib#path#abspath(root)
	endif
	" Not found: return parent directory of current file / file itself.
	let fullname = asclib#path#abspath(a:path)
	if isdirectory(fullname)
		return fullname
	endif
	return asclib#path#abspath(fnamemodify(fullname, ':h'))
endfunc


"----------------------------------------------------------------------
" get project root
"----------------------------------------------------------------------
function! asclib#path#get_root(path, ...)
	let markers = ['.root', '.git', '.hg', '.svn', '.project']
	if exists('g:asclib_path_rootmarks')
		let markers = g:asclib_path_rootmarks
	endif
	if a:0 > 0
		let markers = a:1
	endif
	let l:hr = s:find_root(a:path, markers)
	if s:windows != 0
		let l:hr = join(split(l:hr, '/', 1), "\\")
	endif
	return l:hr
endfunc


"----------------------------------------------------------------------
" exists
"----------------------------------------------------------------------
function! asclib#path#exists(path)
	if isdirectory(a:path)
		return 1
	elseif filereadable(a:path)
		return 1
	endif
	return 0
endfunc


